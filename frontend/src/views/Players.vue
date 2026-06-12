<template>
  <div>
    <!-- 查询区 -->
    <div class="card">
      <div class="flex-row mb-16">
        <el-input-number v-model="searchId" :min="1" placeholder="输入玩家ID" />
        <el-button type="primary" @click="searchPlayer">🔍 查询</el-button>
      </div>

      <!-- 玩家信息 -->
      <template v-if="player">
        <el-descriptions :column="4" border size="small">
          <el-descriptions-item label="昵称">{{ player.nickname }}</el-descriptions-item>
          <el-descriptions-item label="段位">{{ player.rank_name || '-' }}</el-descriptions-item>
          <el-descriptions-item label="ELO积分">{{ player.elo_rating }}</el-descriptions-item>
          <el-descriptions-item label="等级">Lv.{{ player.level }}</el-descriptions-item>
          <el-descriptions-item label="金币"><span class="gold-text">{{ player.gold }}</span></el-descriptions-item>
          <el-descriptions-item label="胜率">{{ player.win_rate }}%</el-descriptions-item>
          <el-descriptions-item label="总场次">{{ player.total_matches }}</el-descriptions-item>
          <el-descriptions-item label="胜负">{{ player.wins }}胜 / {{ player.losses }}负</el-descriptions-item>
          <el-descriptions-item label="在线状态">{{ player.status }}</el-descriptions-item>
          <el-descriptions-item label="最后登录">{{ player.last_login }}</el-descriptions-item>
          <el-descriptions-item label="经验值">{{ player.experience }}</el-descriptions-item>
          <el-descriptions-item label="注册时间">{{ player.created_at }}</el-descriptions-item>
        </el-descriptions>
      </template>
    </div>

    <!-- KDA 走势图 + ELSO 变化图 -->
    <div class="chart-half" v-if="stats">
      <div class="card">
        <div class="card-title">📈 近20场 KDA 走势 (滑动窗口)</div>
        <div id="kdaChart" class="chart-container"></div>
      </div>
      <div class="card">
        <div class="card-title">📉 累计 ELO 变化趋势</div>
        <div id="eloChart" class="chart-container"></div>
      </div>
    </div>

    <!-- 近期对战列表 -->
    <div class="card mt-16" v-if="stats">
      <div class="card-title">⚔️ 近期对战记录</div>
      <el-table :data="recentMatches" stripe size="small">
        <el-table-column prop="match_code" label="对战编号" width="180" />
        <el-table-column prop="hero" label="使用英雄" width="100" />
        <el-table-column label="KDA" width="120">
          <template #default="{ row }">{{ row.kda }}</template>
        </el-table-column>
        <el-table-column label="KDA值" width="80">
          <template #default="{ row }">{{ row.kda_value }}</template>
        </el-table-column>
        <el-table-column label="结果" width="60">
          <template #default="{ row }">
            <span :class="row.result === '胜' ? 'win-text' : 'lose-text'">{{ row.result }}</span>
          </template>
        </el-table-column>
        <el-table-column label="ELO变化">
          <template #default="{ row }">
            <span :class="row.elo_change > 0 ? 'positive' : 'negative'">
              {{ row.elo_change > 0 ? '+' : '' }}{{ row.elo_change }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="滑动5场KDA" width="100">
          <template #default="{ row }">{{ row.rolling_5_kda }}</template>
        </el-table-column>
        <el-table-column prop="cumulative_elo" label="累计ELO" width="80" />
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, nextTick } from 'vue'
import * as echarts from 'echarts'
import { getPlayer, getPlayerStats } from '../api'
import { ElInputNumber, ElButton, ElDescriptions, ElDescriptionsItem, ElTable, ElTableColumn } from 'element-plus'

const searchId = ref(1)
const player = ref(null)
const stats = ref(null)
const recentMatches = ref([])

const charts = {}
const initChart = (id) => { const d=document.getElementById(id); if(!d)return null; if(charts[id]) charts[id].dispose(); charts[id]=echarts.init(d); return charts[id]; }

const searchPlayer = async () => {
  try {
    const [pRes, sRes] = await Promise.all([
      getPlayer(searchId.value),
      getPlayerStats(searchId.value)
    ])
    player.value = pRes
    stats.value = sRes
    recentMatches.value = sRes.recent_matches || []
    await nextTick()
    drawCharts()
  } catch {
    player.value = null
    stats.value = null
    recentMatches.value = []
  }
}

const drawCharts = () => {
  const matches = (recentMatches.value || []).slice().reverse()

  // KDA 趋势折线图
  const kdaChart = initChart('kdaChart')
  if (kdaChart) {
    kdaChart.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 55, right: 30, top: 20, bottom: 30 },
      xAxis: { type: 'category', data: matches.map((_, i) => `#${i+1}`), axisLabel: { color: '#8899b4' } },
      yAxis: { type: 'value', name: 'KDA', axisLabel: { color: '#8899b4' },
               splitLine: { lineStyle: { color: '#1e3050', type: 'dashed' } } },
      series: [
        {
          name: '单场KDA', type: 'line', data: matches.map(m => m.kda_value),
          smooth: true, symbol: 'circle', symbolSize: 5,
          itemStyle: { color: '#06b6d4' }, lineStyle: { width: 2 }
        },
        {
          name: '5场滑动KDA', type: 'line', data: matches.map(m => m.rolling_5_kda),
          smooth: true, symbol: 'diamond', symbolSize: 6,
          itemStyle: { color: '#8b5cf6' }, lineStyle: { type: 'dashed', width: 2.5, shadowBlur: 8, shadowColor: 'rgba(139,92,246,0.4)' }
        }
      ]
    })
  }

  // 累计ELO 面积图
  const eloChart = initChart('eloChart')
  if (eloChart) {
    eloChart.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 60, right: 25, top: 20, bottom: 30 },
      xAxis: { type: 'category', data: matches.map((_, i) => `#${i+1}`), axisLabel: { color: '#8899b4' } },
      yAxis: { type: 'value', name: 'ELO', axisLabel: { color: '#8899b4' },
               splitLine: { lineStyle: { color: '#1e3050', type: 'dashed' } } },
      series: [{
        type: 'line', data: matches.map(m => m.cumulative_elo),
        smooth: true, symbol: 'circle', symbolSize: 6,
        itemStyle: { color: '#10b981' }, lineStyle: { width: 3, shadowBlur: 10, shadowColor: 'rgba(16,185,129,0.3)' },
        areaStyle: { color: new echarts.graphic.LinearGradient(0,0,0,1,[
          {offset:0,color:'rgba(16,185,129,0.35)'},{offset:1,color:'rgba(16,185,129,0.02)'}
        ])}
      }]
    })
  }
}

// 默认查询 player1
import { onMounted, onUnmounted } from 'vue'

const handleResize = () => { Object.values(charts).forEach(c => c?.resize()) }
onMounted(() => { searchPlayer(); window.addEventListener('resize', handleResize) })
onUnmounted(() => { window.removeEventListener('resize', handleResize); Object.values(charts).forEach(c => c?.dispose()) })
</script>
