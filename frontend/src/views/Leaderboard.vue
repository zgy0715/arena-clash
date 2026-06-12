<template>
  <div>
    <!-- 排行榜表格 + ELO柱状图 -->
    <div class="chart-2-1">
      <div class="card">
        <div class="card-title">
          🏆 全服实时排行榜 (Redis Sorted Set)
          <span style="font-weight:normal;font-size:12px;color:#8ab4d6;margin-left:8px">查询耗时 &lt; 5ms</span>
        </div>
        <el-table :data="lbData" stripe size="small" max-height="440">
          <el-table-column prop="rank" label="排名" width="65" sortable />
          <el-table-column prop="player_id" label="玩家ID" width="80" />
          <el-table-column prop="elo" label="ELO积分" sortable>
            <template #default="{ row }">
              <span :class="row.rank <= 3 ? 'gold-text' : ''">{{ row.elo }}</span>
            </template>
          </el-table-column>
        </el-table>
      </div>
      <div class="card">
        <div class="card-title">📈 ELO 排行榜 Top 20 柱状图</div>
        <div id="eloBarChart" class="chart-container"></div>
      </div>
    </div>

    <!-- PG同步 -->
    <div class="card mt-16">
      <div class="card-title">🔄 数据同步</div>
      <div style="text-align:center;padding:40px">
        <p style="color:#8ab4d6;margin-bottom:24px;font-size:14px;line-height:1.8">
          将 PostgreSQL 玩家 ELO 数据<br/>全量同步到 Redis 排行榜<br/>
          <span style="color:#f0c040">使用 Pipeline 批量写入</span>
        </p>
        <el-button type="primary" size="large" @click="doSync" :loading="syncing">
          🔄 PG → Redis 全量同步
        </el-button>
        <p v-if="syncMsg" style="margin-top:16px;color:#52c41a">{{ syncMsg }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts'
import { getLeaderboard, syncLeaderboard } from '../api'
import { ElTable, ElTableColumn, ElButton, ElMessage } from 'element-plus'

const lbData = ref([])
const syncing = ref(false)
const syncMsg = ref('')

const charts = {}
const initChart = (id) => { const d=document.getElementById(id); if(!d)return null; if(charts[id]) charts[id].dispose(); charts[id]=echarts.init(d); return charts[id]; }

const loadLB = async () => {
  try {
    const res = await getLeaderboard(50)
    lbData.value = res.leaderboard
    await nextTick()
    drawEloBar()
  } catch {}
}

const drawEloBar = () => {
  const eloBarChart = initChart('eloBarChart')
  if (!eloBarChart) return
  const top = lbData.value.slice(0, 20)
  eloBarChart.setOption({
    tooltip: { trigger: 'axis' },
    grid: { left: 55, right: 20, top: 10, bottom: 30 },
    xAxis: { type: 'category', data: top.map(x => `#${x.rank}`), axisLabel: { color: '#8899b4' } },
    yAxis: { type: 'value', name: 'ELO', axisLabel: { color: '#8899b4' },
             splitLine: { lineStyle: { color: '#1e3050', type: 'dashed' } } },
    series: [{
      type: 'bar', data: top.map(x => x.elo), barWidth: '60%',
      itemStyle: { borderRadius: [6,6,0,0],
        color: new echarts.graphic.LinearGradient(0,0,0,1,[
          {offset:0,color:'#8b5cf6'},{offset:1,color:'#ec4899'}
        ])
      },
      label: { show: true, position: 'top', color: '#8899b4', fontSize: 10, fontWeight: 500 }
    }]
  })
}

const doSync = async () => {
  syncing.value = true
  syncMsg.value = ''
  try {
    const res = await syncLeaderboard()
    syncMsg.value = res.message
    ElMessage.success(res.message)
    await loadLB()
  } catch (e) {
    ElMessage.error('同步失败')
  }
  syncing.value = false
}

const handleResize = () => { Object.values(charts).forEach(c => c?.resize()) }

onMounted(() => {
  loadLB()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  window.removeEventListener('resize', handleResize)
  Object.values(charts).forEach(c => c?.dispose())
})
</script>
