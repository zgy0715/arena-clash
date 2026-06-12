<template>
  <div>
    <!-- 统计卡片 -->
    <div class="stat-grid">
      <div class="stat-item"><div class="value">{{ overview.total_players || 0 }}</div><div class="label">注册玩家</div></div>
      <div class="stat-item"><div class="value">{{ overview.total_matches || 0 }}</div><div class="label">对战总数</div></div>
      <div class="stat-item"><div class="value">{{ overview.total_heroes || 0 }}</div><div class="label">英雄数量</div></div>
      <div class="stat-item"><div class="value">{{ overview.total_revenue || 0 }}</div><div class="label">总消费金币</div></div>
    </div>

    <!-- 段位分布 + 英雄统计 -->
    <div class="chart-half">
      <div class="card">
        <div class="card-title">📊 段位分布 (NTILE 分桶)</div>
        <div id="tierChart" class="chart-container"></div>
      </div>
      <div class="card">
        <div class="card-title">⚔️ 英雄出场率 Top 10</div>
        <div id="heroPieChart" class="chart-container"></div>
      </div>
    </div>

    <!-- 英雄胜率 -->
    <div class="card mt-16">
      <div class="card-title">📈 英雄胜率排行 (柱状图)</div>
      <div id="heroBarChart" class="chart-container"></div>
    </div>

    <!-- 物化视图：赛季统计 -->
    <div class="card mt-16">
      <div class="card-title">🏆 物化视图：赛季英雄预计算统计</div>
      <el-table :data="mvStats" stripe size="small">
        <el-table-column prop="hero_name" label="英雄" width="120" />
        <el-table-column prop="role" label="角色" width="90" />
        <el-table-column prop="picks" label="出场" sortable />
        <el-table-column prop="wins" label="胜场" sortable />
        <el-table-column prop="win_rate" label="胜率%" sortable />
        <el-table-column prop="avg_kda" label="平均KDA" sortable />
        <el-table-column prop="mvp_count" label="MVP次数" sortable />
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue'
import * as echarts from 'echarts'
import { getOverview, getTierDistribution, getHeroStats, getMvSeasonStats } from '../api'
import { ElTable, ElTableColumn } from 'element-plus'

const overview = ref({})
const mvStats = ref([])

const charts = {}

const initChart = (id) => {
  const dom = document.getElementById(id)
  if (!dom) return null
  if (charts[id]) charts[id].dispose()
  const instance = echarts.init(dom)
  charts[id] = instance
  return instance
}

const buildCharts = async () => {
  const safeApi = (fn) => fn().catch(() => null)

  const [tierRes, heroRes, mvRes] = await Promise.all([
    safeApi(getTierDistribution),
    safeApi(getHeroStats),
    safeApi(getMvSeasonStats),
  ])

  mvStats.value = mvRes?.season_hero_stats || []

  await nextTick()

  // 段位分布 饼图
  const tier = initChart('tierChart')
  if (tier) {
    const data = tierRes?.distribution || []
    const colors = ['#06b6d4', '#8b5cf6', '#ec4899', '#f59e0b']
    tier.setOption({
      tooltip: { trigger: 'item', formatter: '{b}: {c}人 ({d}%)' },
      series: [{
        type: 'pie',
        radius: ['45%', '72%'],
        itemStyle: { borderRadius: 4, borderColor: '#0b0f1a', borderWidth: 4 },
        data: data.map((d, i) => ({
          name: d.tier,
          value: d.player_count,
          itemStyle: { color: colors[i % 4] }
        })),
        label: { color: '#8899b4', fontSize: 12, fontWeight: 500 }
      }]
    })
  }

  // 英雄出场率 饼图
  const hDom = initChart('heroPieChart')
  if (hDom) {
    const heroes = (heroRes?.heroes || []).slice(0, 10)
    const hColors = [
      '#06b6d4', '#8b5cf6', '#ec4899', '#f59e0b', '#10b981',
      '#6366f1', '#14b8a6', '#d946ef', '#f97316', '#3b82f6'
    ]
    hDom.setOption({
      tooltip: { trigger: 'item' },
      series: [{
        type: 'pie',
        radius: '68%',
        itemStyle: { borderRadius: 3, borderColor: '#0b0f1a', borderWidth: 3 },
        data: heroes.map((h, i) => ({
          name: h.name,
          value: h.total_picks,
          itemStyle: { color: hColors[i] }
        })),
        label: { color: '#8899b4', fontSize: 11, formatter: '{b}\n{d}%' }
      }]
    })
  }

  // 英雄胜率 柱状图
  const bar = initChart('heroBarChart')
  if (bar) {
    const heroes = (heroRes?.heroes || []).slice(0, 10).sort((a, b) => b.win_rate - a.win_rate)
    bar.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 55, right: 25, top: 30, bottom: 60 },
      xAxis: {
        type: 'category',
        data: heroes.map(h => h.name),
        axisLabel: { color: '#8899b4', rotate: 35, fontSize: 10 }
      },
      yAxis: {
        type: 'value',
        name: '胜率%',
        max: 100,
        axisLabel: { color: '#8899b4' },
        splitLine: { lineStyle: { color: '#1e3050', type: 'dashed' } }
      },
      series: [{
        type: 'bar',
        data: heroes.map(h => h.win_rate),
        barWidth: '55%',
        itemStyle: {
          borderRadius: [6, 6, 0, 0],
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#06b6d4' },
            { offset: 1, color: '#6366f1' }
          ])
        },
        label: { show: true, position: 'top', color: '#8899b4', fontSize: 10, fontWeight: 500 }
      }]
    })
  }
}

const onResize = () => Object.values(charts).forEach(c => c?.resize?.())
window.addEventListener('resize', onResize)

onBeforeUnmount(() => {
  window.removeEventListener('resize', onResize)
  Object.values(charts).forEach(c => c?.dispose?.())
})

onMounted(async () => {
  try { overview.value = await getOverview() } catch (e) { console.error(e) }
  await buildCharts()
})
</script>
