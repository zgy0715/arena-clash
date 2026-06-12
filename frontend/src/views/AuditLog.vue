<template>
  <div>
    <!-- 统计概览 -->
    <div class="card">
      <div class="card-title">
        📋 审计日志统计
        <el-tag size="small" type="warning" style="margin-left:12px">视图 v_audit_action_stats</el-tag>
      </div>
      <div class="chart-half">
        <div>
          <el-table :data="stats" stripe size="small" max-height="300">
            <el-table-column prop="action" label="操作类型" />
            <el-table-column prop="cnt" label="总次数" width="100" />
            <el-table-column prop="last_7d" label="近7天" width="90" />
            <el-table-column prop="last_at" label="最近一次" />
          </el-table>
        </div>
        <div id="auditPie" class="chart-container" style="height:300px"></div>
      </div>
    </div>

    <!-- 日志查询 -->
    <div class="card">
      <div class="card-title">
        🔎 日志查询
        <el-tag size="small" type="info" style="margin-left:12px">JSONB detail + 动态过滤</el-tag>
      </div>
      <div class="flex-row mb-16">
        <el-select v-model="filterAction" placeholder="操作类型" clearable style="width:200px">
          <el-option v-for="a in actions" :key="a" :label="a" :value="a" />
        </el-select>
        <el-input-number v-model="filterPlayer" :min="1" placeholder="玩家ID" controls-position="right" />
        <el-button type="primary" @click="loadLogs">🔍 查询</el-button>
        <el-button @click="resetFilter">重置</el-button>
      </div>

      <el-table :data="logs" stripe size="small" max-height="560">
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="created_at" label="时间" width="200" />
        <el-table-column prop="action" label="操作" width="180">
          <template #default="{ row }"><el-tag size="small">{{ row.action }}</el-tag></template>
        </el-table-column>
        <el-table-column prop="player_id" label="操作者ID" width="100" />
        <el-table-column label="详情 (JSONB)">
          <template #default="{ row }">
            <el-popover placement="top-start" width="360" trigger="hover">
              <template #reference><span style="color:#06b6d4;cursor:pointer">查看 detail</span></template>
              <pre style="margin:0;white-space:pre-wrap;font-size:12px">{{ pretty(row.detail) }}</pre>
            </el-popover>
          </template>
        </el-table-column>
      </el-table>
      <el-empty v-if="!logs.length" description="无日志记录" />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import {
  ElTable, ElTableColumn, ElTag, ElSelect, ElOption, ElInputNumber, ElButton, ElPopover, ElEmpty, ElMessage,
} from 'element-plus'
import { getAuditLogs, getAuditActions, getAuditStats } from '../api'

const logs = ref([])
const stats = ref([])
const actions = ref([])
const filterAction = ref('')
const filterPlayer = ref(null)
let pie = null

const pretty = (d) => { try { return JSON.stringify(d, null, 2) } catch { return String(d) } }

const loadLogs = async () => {
  try {
    const params = { limit: 100 }
    if (filterAction.value) params.action = filterAction.value
    if (filterPlayer.value) params.player_id = filterPlayer.value
    logs.value = (await getAuditLogs(params)).logs
  } catch (e) { ElMessage.error(e.message) }
}

const resetFilter = () => { filterAction.value = ''; filterPlayer.value = null; loadLogs() }

const loadStats = async () => {
  try {
    stats.value = (await getAuditStats()).stats
    await nextTick()
    drawPie()
  } catch (e) { ElMessage.error(e.message) }
}

const drawPie = () => {
  const el = document.getElementById('auditPie')
  if (!el) return
  if (pie) pie.dispose()
  pie = echarts.init(el)
  pie.setOption({
    tooltip: { trigger: 'item' },
    legend: { type: 'scroll', orient: 'vertical', right: 0, top: 10, textStyle: { color: '#8899b4' } },
    series: [{
      type: 'pie', radius: ['40%', '70%'], center: ['40%', '50%'],
      data: stats.value.map(s => ({ name: s.action, value: s.cnt })),
      label: { color: '#c8d6e5' },
      itemStyle: { borderColor: '#151d2e', borderWidth: 2 },
    }],
  })
}

onMounted(async () => {
  try { actions.value = (await getAuditActions()).actions } catch {}
  await loadStats()
  await loadLogs()
})

onUnmounted(() => {
  if (pie) pie.dispose()
})
</script>
