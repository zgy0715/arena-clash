<template>
  <div>
    <!-- 赛季列表 -->
    <div class="card">
      <div class="card-title">
        📅 赛季中心
        <el-tag size="small" type="warning" style="margin-left:12px">存储过程 fn_reset_season（CTE 段位衰减）</el-tag>
        <el-button v-if="isAdmin" type="danger" size="small" style="margin-left:auto" :loading="resetting" @click="doReset">
          🔁 重置赛季
        </el-button>
      </div>

      <el-table :data="seasons" stripe size="small" @row-click="selectSeason">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="name" label="赛季名称" width="180" />
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag size="small" :type="row.status === 'active' ? 'success' : 'info'">{{ statusText(row.status) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="players" label="参与人数" width="110" />
        <el-table-column prop="start_date" label="开始时间" />
        <el-table-column prop="end_date" label="结束时间" />

      </el-table>
    </div>

    <!-- 赛季历史排名 -->
    <div class="card" v-if="currentSeason">
      <div class="card-title">
        🏆 {{ currentSeason.name }} 排行榜
        <el-tag size="small" type="info" style="margin-left:12px">窗口函数 RANK / LAG / LEAD</el-tag>
      </div>
      <el-table :data="rankings" stripe size="small" max-height="520">
        <el-table-column prop="rank" label="排名" width="80" />
        <el-table-column prop="nickname" label="玩家" width="150" />
        <el-table-column prop="rank_name" label="段位" width="120" />
        <el-table-column prop="rank_points" label="积分" width="100" />
        <el-table-column label="胜率" width="100">
          <template #default="{ row }">{{ row.win_rate }}%</template>
        </el-table-column>
        <el-table-column label="与上一名分差" width="130">
          <template #default="{ row }">
            <span :class="row.gap_above != null && row.gap_above < 0 ? 'negative' : ''">{{ row.gap_above ?? '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="next_points" label="下一名积分" width="120">
          <template #default="{ row }">{{ row.next_points ?? '-' }}</template>
        </el-table-column>
      </el-table>
      <el-empty v-if="!rankings.length" description="该赛季暂无排名数据" />
    </div>
  </div>
</template>

<script setup>
import { ref, inject, onMounted } from 'vue'
import { ElTable, ElTableColumn, ElButton, ElTag, ElEmpty, ElMessage, ElMessageBox } from 'element-plus'
import { getSeasons, resetSeason, getSeasonRankings } from '../api'

const isAdmin = inject('isAdmin')
const seasons = ref([])
const currentSeason = ref(null)
const rankings = ref([])
const resetting = ref(false)

const statusText = (s) => ({ active: '进行中', completed: '已结束', archived: '已归档' }[s] || s)

const loadSeasons = async () => {
  try { seasons.value = (await getSeasons()).seasons } catch (e) { ElMessage.error(e.message) }
}

const selectSeason = async (row) => {
  currentSeason.value = row
  try { rankings.value = (await getSeasonRankings(row.id, 50)).rankings } catch (e) { ElMessage.error(e.message) }
}

const doReset = async () => {
  try {
    await ElMessageBox.confirm(
      '重置赛季将：归档当前活跃赛季 → 创建新赛季 → 全员段位衰减 200 分后迁移。确认继续？',
      '赛季重置确认', { type: 'warning', confirmButtonText: '确认重置' },
    )
  } catch { return }
  resetting.value = true
  try {
    const res = await resetSeason()
    ElMessageBox.alert(res.message, '重置完成', { type: 'success' })
    await loadSeasons()
  } catch (e) { ElMessage.error(e.message) }
  resetting.value = false
}

onMounted(async () => {
  await loadSeasons()
  const active = seasons.value.find(s => s.status === 'active') || seasons.value[0]
  if (active) selectSeason(active)
})
</script>
