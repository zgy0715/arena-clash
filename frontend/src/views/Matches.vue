<template>
  <div>
    <!-- 筛选 + 对战列表 -->
    <div class="card">
      <div class="flex-row mb-16">
        <el-select v-model="filter.status" placeholder="状态筛选" clearable style="width:160px" @change="loadMatches">
          <el-option label="全部" value="" />
          <el-option label="已完成" value="completed" />
          <el-option label="进行中" value="in_progress" />
          <el-option label="待开始" value="pending" />
        </el-select>

      </div>

      <el-table :data="matches" stripe size="small">
        <el-table-column prop="id" label="ID" width="55" />
        <el-table-column prop="match_code" label="对战编号" width="180" />
        <el-table-column prop="map_name" label="地图" width="110" />
        <el-table-column prop="match_mode" label="模式" width="80" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusType(row.status)" size="small">{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="胜方" width="70">
          <template #default="{ row }">
            {{ row.winner_side ? (row.winner_side === 1 ? '蓝方' : '红方') : '-' }}
          </template>
        </el-table-column>
        <el-table-column prop="duration_sec" label="时长(秒)" width="90" sortable />
        <el-table-column label="开始时间">
          <template #default="{ row }">{{ row.started_at || '-' }}</template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getMatches } from '../api'
import { ElSelect, ElOption, ElButton, ElTable, ElTableColumn, ElTag } from 'element-plus'

const filter = ref({ status: '' })
const matches = ref([])

const statusType = (s) => {
  if (s === 'completed') return 'success'
  if (s === 'in_progress') return 'warning'
  if (s === 'cancelled') return 'danger'
  return 'info'
}

const loadMatches = async () => {
  try {
    const params = { limit: 50 }
    if (filter.value.status) params.status = filter.value.status
    const res = await getMatches(params)
    matches.value = res.matches
  } catch {}
}

onMounted(() => loadMatches())
</script>
