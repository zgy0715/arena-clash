<template>
  <div>
    <!-- 建对战 -->
    <div class="card">
      <div class="card-title">
        🎮 对战中心 — 创建对战
        <el-tag size="small" type="warning" style="margin-left:12px">存储过程 fn_create_match_with_players</el-tag>
        <el-tag size="small" type="danger" style="margin-left:4px">触发器自动编号</el-tag>
      </div>

      <div class="flex-row mb-16">
        <el-select v-model="seasonId" placeholder="赛季" style="width:180px">
          <el-option v-for="s in seasons" :key="s.id" :label="`${s.name}（${s.status}）`" :value="s.id" />
        </el-select>
        <el-input v-model="mapName" placeholder="地图" style="width:160px" />
        <el-select v-model="mode" style="width:120px">
          <el-option v-for="m in modes" :key="m" :label="m" :value="m" />
        </el-select>
        <el-button size="small" @click="quickFill">⚡ 快速填充10人</el-button>
        <el-button size="small" @click="addRow">➕ 添加一行</el-button>
        <el-button type="primary" size="small" :loading="creating" @click="createMatch">创建对战</el-button>
      </div>

      <el-table :data="roster" stripe size="small" max-height="320">
        <el-table-column label="玩家ID" width="120">
          <template #default="{ row }"><el-input-number v-model="row.player_id" :min="1" size="small" /></template>
        </el-table-column>
        <el-table-column label="英雄" width="180">
          <template #default="{ row }">
            <el-select v-model="row.hero_id" size="small" style="width:150px">
              <el-option v-for="h in heroes" :key="h.id" :label="h.name" :value="h.id" />
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="阵营" width="140">
          <template #default="{ row }">
            <el-select v-model="row.team_side" size="small" style="width:110px">
              <el-option label="蓝方(1)" :value="1" />
              <el-option label="红方(2)" :value="2" />
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="80">
          <template #default="{ $index }"><el-button size="small" type="danger" @click="roster.splice($index, 1)">移除</el-button></template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 对战详情 -->
    <div class="card" v-if="match">
      <div class="card-title">
        ⚔️ {{ match.match_code }}
        <el-tag size="small" :type="statusType(match.status)" style="margin-left:12px">{{ statusText(match.status) }}</el-tag>
        <span v-if="match.winner_side" style="margin-left:12px" :class="match.winner_side === 1 ? 'win-text' : 'lose-text'">
          胜方：{{ match.winner_side === 1 ? '蓝方' : '红方' }}
        </span>
        <el-button v-if="match.status === 'pending'" type="primary" size="small" style="margin-left:auto" :loading="acting" @click="doStart">▶ 开始对战</el-button>
        <template v-if="match.status === 'in_progress'">
          <el-select v-model="winnerSide" size="small" style="width:130px;margin-left:auto;margin-right:8px">
            <el-option label="蓝方胜" :value="1" />
            <el-option label="红方胜" :value="2" />
          </el-select>
          <el-button type="primary" size="small" :loading="acting" @click="doSettle">🏁 结算</el-button>
        </template>
      </div>

      <p style="color:#8899b4;font-size:12px;margin-bottom:10px">
        开始对战后，参战玩家"在线状态"会被<b>触发器</b>自动改为 in_match；结算调用<b>存储过程</b>计算 KDA/金币/ELO 并评选 MVP。
      </p>

      <el-table :data="match.players" stripe size="small">
        <el-table-column label="阵营" width="80">
          <template #default="{ row }">
            <span :class="row.team_side === 1 ? 'win-text' : 'lose-text'">{{ row.team_side === 1 ? '蓝方' : '红方' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="nickname" label="玩家" width="120" />
        <el-table-column prop="hero_name" label="英雄" width="110" />
        <el-table-column label="KDA" width="110">
          <template #default="{ row }">{{ row.kills }}/{{ row.deaths }}/{{ row.assists }}</template>
        </el-table-column>
        <el-table-column prop="kda" label="KDA值" width="80" />
        <el-table-column label="ELO变化" width="90">
          <template #default="{ row }">
            <span :class="row.elo_change > 0 ? 'positive' : (row.elo_change < 0 ? 'negative' : '')">
              {{ row.elo_change > 0 ? '+' : '' }}{{ row.elo_change }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="MVP" width="70">
          <template #default="{ row }"><span v-if="row.is_mvp" class="mvp-badge">⭐</span></template>
        </el-table-column>
        <el-table-column label="在线状态" width="100">
          <template #default="{ row }">
            <el-tag size="small" :type="row.player_status === 'in_match' ? 'danger' : 'info'">{{ row.player_status }}</el-tag>
          </template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, inject, onMounted } from 'vue'
import {
  ElSelect, ElOption, ElInput, ElInputNumber, ElButton, ElTable, ElTableColumn, ElTag, ElMessage,
} from 'element-plus'
import { getSeasons, lookupHeroes, createFullMatch, getMatchDetail, startMatch, settleMatch } from '../api'

const token = inject('token')
const seasons = ref([])
const heroes = ref([])
const seasonId = ref(null)
const mapName = ref('召唤师峡谷')
const mode = ref('ranked')
const modes = ['ranked', 'casual', 'custom']
const roster = ref([])
const creating = ref(false)

const match = ref(null)
const winnerSide = ref(1)
const acting = ref(false)

const statusText = (s) => ({ pending: '等待中', in_progress: '进行中', completed: '已结束', cancelled: '已取消' }[s] || s)
const statusType = (s) => ({ pending: 'info', in_progress: 'warning', completed: 'success', cancelled: 'info' }[s] || 'info')

const addRow = () => roster.value.push({ player_id: 1, hero_id: heroes.value[0]?.id || 1, team_side: roster.value.length < 5 ? 1 : 2 })

const quickFill = () => {
  roster.value = []
  for (let i = 0; i < 10; i++) {
    roster.value.push({
      player_id: i + 1,
      hero_id: heroes.value[i % heroes.value.length]?.id || 1,
      team_side: i < 5 ? 1 : 2,
    })
  }
}

const createMatch = async () => {
  if (!token.value) { ElMessage.warning('请先登录'); return }
  if (!seasonId.value) { ElMessage.warning('请选择赛季'); return }
  if (!roster.value.length) { ElMessage.warning('请至少添加一名参战玩家'); return }
  creating.value = true
  try {
    const res = await createFullMatch({
      season_id: seasonId.value, map_name: mapName.value, match_mode: mode.value, players: roster.value,
    })
    ElMessage.success(`${res.message}：${res.match_code}`)
    roster.value = []  // 清空阵容，防止重复建相同对战
    await loadMatch(res.match_id)
  } catch (e) { ElMessage.error(e.message) }
  creating.value = false
}

const loadMatch = async (id) => {
  try {
    const res = await getMatchDetail(id)   // 后端返回 {match, players}，这里拍平
    match.value = { ...res.match, players: res.players }
  } catch (e) { ElMessage.error(e.message) }
}

const doStart = async () => {
  acting.value = true
  try {
    await startMatch(match.value.id)
    ElMessage.success('对战已开始（触发器已同步参战玩家状态为 in_match）')
    await loadMatch(match.value.id)
  } catch (e) { ElMessage.error(e.message) }
  acting.value = false
}

const doSettle = async () => {
  acting.value = true
  try {
    const res = await settleMatch(match.value.id, winnerSide.value)
    if (res.success) ElMessage.success(res.message)
    else ElMessage.error(res.message)
    await loadMatch(match.value.id)
  } catch (e) { ElMessage.error(e.message) }
  acting.value = false
}

onMounted(async () => {
  try { seasons.value = (await getSeasons()).seasons } catch {}
  try { heroes.value = (await lookupHeroes()).heroes } catch {}
  if (seasons.value.length) seasonId.value = seasons.value.find(s => s.status === 'active')?.id || seasons.value[0].id
})
</script>
