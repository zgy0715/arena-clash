<template>
  <div>
    <div class="card">
      <div class="card-title">
        🤝 社交系统
        <el-tag size="small" type="warning" style="margin-left:12px">新增表 friendship / friend_request</el-tag>
        <el-tag size="small" type="danger" style="margin-left:4px">自连接 + 存储过程 + 计数触发器</el-tag>
      </div>

      <template v-if="!token">
        <el-empty description="请先登录后使用社交功能" />
      </template>

      <el-tabs v-else v-model="tab" @tab-change="onTab">
        <!-- 好友列表 -->
        <el-tab-pane label="好友列表" name="friends">
          <el-table :data="friends" stripe size="small">
            <el-table-column prop="friend_id" label="ID" width="60" />
            <el-table-column prop="nickname" label="昵称" width="140" />
            <el-table-column prop="elo_rating" label="ELO" width="90" />
            <el-table-column prop="level" label="等级" width="80" />
            <el-table-column prop="status" label="状态" width="100" />
            <el-table-column prop="friend_count" label="好友数" width="90" />
            <el-table-column label="操作" width="180">
              <template #default="{ row }">
                <el-button size="small" @click="goCompare(row.friend_id)">战绩对比</el-button>
                <el-button size="small" type="danger" @click="removeFriend(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
          <el-empty v-if="!friends.length" description="还没有好友" />
        </el-tab-pane>

        <!-- 好友请求 -->
        <el-tab-pane name="requests">
          <template #label>好友请求 <el-badge v-if="requests.length" :value="requests.length" /></template>
          <el-table :data="requests" stripe size="small">
            <el-table-column prop="requester_id" label="ID" width="60" />
            <el-table-column prop="requester_nickname" label="申请人" width="160" />
            <el-table-column prop="requester_elo" label="ELO" width="90" />
            <el-table-column prop="created_at" label="申请时间" />
            <el-table-column label="操作" width="180">
              <template #default="{ row }">
                <el-button size="small" type="primary" @click="accept(row)">接受</el-button>
                <el-button size="small" @click="reject(row)">拒绝</el-button>
              </template>
            </el-table-column>
          </el-table>
          <el-empty v-if="!requests.length" description="没有待处理的好友请求" />
        </el-tab-pane>

        <!-- 添加好友 -->
        <el-tab-pane label="添加好友" name="add">
          <div class="flex-row">
            <el-input-number v-model="addId" :min="1" placeholder="对方玩家ID" />
            <el-button type="primary" @click="sendReq">发送好友请求</el-button>
          </div>
          <p style="color:#8899b4;font-size:12px;margin-top:10px">提示：演示数据中 player4、player5 已向 player1 发送了好友请求。</p>
        </el-tab-pane>

        <!-- 战绩对比 -->
        <el-tab-pane label="战绩对比" name="compare">
          <div class="flex-row mb-16">
            <el-select v-model="compareId" placeholder="选择好友" style="width:200px">
              <el-option v-for="f in friends" :key="f.friend_id" :label="f.nickname" :value="f.friend_id" />
            </el-select>
            <el-button type="primary" @click="doCompare">对比</el-button>
          </div>
          <template v-if="cmp">
            <div class="flex-row" style="gap:24px;align-items:stretch">
              <el-descriptions :title="cmp.me.nickname + '（我）'" :column="1" border size="small" style="flex:1">
                <el-descriptions-item label="ELO">{{ cmp.me.elo }}</el-descriptions-item>
                <el-descriptions-item label="等级">Lv.{{ cmp.me.level }}</el-descriptions-item>
                <el-descriptions-item label="总场次">{{ cmp.me.total }}</el-descriptions-item>
                <el-descriptions-item label="胜/负">{{ cmp.me.wins }} / {{ cmp.me.losses }}</el-descriptions-item>
                <el-descriptions-item label="胜率">{{ cmp.me.win_rate }}%</el-descriptions-item>
              </el-descriptions>
              <el-descriptions :title="cmp.friend.nickname + '（好友）'" :column="1" border size="small" style="flex:1">
                <el-descriptions-item label="ELO">{{ cmp.friend.elo }}</el-descriptions-item>
                <el-descriptions-item label="等级">Lv.{{ cmp.friend.level }}</el-descriptions-item>
                <el-descriptions-item label="总场次">{{ cmp.friend.total }}</el-descriptions-item>
                <el-descriptions-item label="胜/负">{{ cmp.friend.wins }} / {{ cmp.friend.losses }}</el-descriptions-item>
                <el-descriptions-item label="胜率">{{ cmp.friend.win_rate }}%</el-descriptions-item>
              </el-descriptions>
            </div>
            <div id="cmpChart" class="chart-container" style="height:320px;margin-top:16px"></div>
          </template>
        </el-tab-pane>
      </el-tabs>
    </div>
  </div>
</template>

<script setup>
import { ref, inject, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import {
  ElTabs, ElTabPane, ElTable, ElTableColumn, ElButton, ElTag, ElBadge, ElEmpty,
  ElInput, ElInputNumber, ElSelect, ElOption, ElDescriptions, ElDescriptionsItem, ElMessage,
} from 'element-plus'
import {
  getFriends, getIncomingRequests, acceptFriendRequest, rejectFriendRequest,
  deleteFriend, sendFriendRequest, compareWithFriend,
} from '../api'

const token = inject('token')
const tab = ref('friends')
const friends = ref([])
const requests = ref([])
const addId = ref(2)
const compareId = ref(null)
const cmp = ref(null)
let chart = null

const loadFriends = async () => { try { friends.value = (await getFriends()).friends } catch (e) { ElMessage.error(e.message) } }
const loadRequests = async () => { try { requests.value = (await getIncomingRequests()).requests } catch (e) { ElMessage.error(e.message) } }

const onTab = (name) => {
  if (name === 'friends') loadFriends()
  else if (name === 'requests') loadRequests()
}

const accept = async (row) => {
  try { ElMessage.success((await acceptFriendRequest(row.id)).message); await loadRequests(); await loadFriends() }
  catch (e) { ElMessage.error(e.message) }
}
const reject = async (row) => {
  try { ElMessage.success((await rejectFriendRequest(row.id)).message); await loadRequests() }
  catch (e) { ElMessage.error(e.message) }
}
const removeFriend = async (row) => {
  try { ElMessage.success((await deleteFriend(row.friend_id)).message); await loadFriends() }
  catch (e) { ElMessage.error(e.message) }
}
const sendReq = async () => {
  try { ElMessage.success((await sendFriendRequest(addId.value)).message) }
  catch (e) { ElMessage.error(e.message) }
}

const goCompare = (fid) => { tab.value = 'compare'; compareId.value = fid; doCompare() }

const doCompare = async () => {
  if (!compareId.value) { ElMessage.warning('请选择好友'); return }
  try {
    cmp.value = await compareWithFriend(compareId.value)
    await nextTick()
    drawChart()
  } catch (e) { ElMessage.error(e.message); cmp.value = null }
}

const drawChart = () => {
  const el = document.getElementById('cmpChart')
  if (!el) return
  if (chart) chart.dispose()
  chart = echarts.init(el)
  chart.setOption({
    tooltip: { trigger: 'axis' },
    legend: { textStyle: { color: '#8899b4' } },
    grid: { left: 50, right: 20, top: 40, bottom: 30 },
    xAxis: { type: 'category', data: ['ELO', '胜场', '负场', '总场', '胜率%'], axisLabel: { color: '#8899b4' } },
    yAxis: { type: 'value', axisLabel: { color: '#8899b4' }, splitLine: { lineStyle: { color: '#1e3050', type: 'dashed' } } },
    series: [
      { name: cmp.value.me.nickname, type: 'bar', itemStyle: { color: '#06b6d4' },
        data: [cmp.value.me.elo, cmp.value.me.wins, cmp.value.me.losses, cmp.value.me.total, cmp.value.me.win_rate] },
      { name: cmp.value.friend.nickname, type: 'bar', itemStyle: { color: '#8b5cf6' },
        data: [cmp.value.friend.elo, cmp.value.friend.wins, cmp.value.friend.losses, cmp.value.friend.total, cmp.value.friend.win_rate] },
    ],
  })
}

onMounted(() => {
  if (token.value) { loadFriends(); loadRequests() }
})

onUnmounted(() => {
  if (chart) chart.dispose()
})
</script>
