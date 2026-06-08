<template>
  <div>
    <div class="card">
      <div class="card-title">
        🛒 虚拟商城
        <el-tag size="small" type="warning" style="margin-left:12px">限流：10次/分钟</el-tag>
        <el-tag size="small" type="danger" style="margin-left:4px">行级锁 FOR UPDATE</el-tag>
      </div>

      <el-table :data="items" stripe size="small">
        <el-table-column prop="id" label="ID" width="55" />
        <el-table-column prop="name" label="商品名称" width="140" />
        <el-table-column label="类型" width="90">
          <template #default="{ row }">
            <el-tag size="small">{{ row.item_type }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="价格" width="100">
          <template #default="{ row }"><span class="gold-text">{{ row.price_gold }} 金币</span></template>
        </el-table-column>
        <el-table-column prop="stock" label="库存" width="80">
          <template #default="{ row }">
            <span :class="row.is_limited && row.stock <= 10 ? 'lose-text' : ''">{{ row.stock }}</span>
          </template>
        </el-table-column>
        <el-table-column label="限时/限量" width="90">
          <template #default="{ row }">
            <el-tag v-if="row.is_limited" size="small" type="danger">限量</el-tag>
            <span v-else style="color:#8c8c8c">无限</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="描述" />
        <el-table-column label="操作" width="100">
          <template #default="{ row }">
            <el-button
              size="small" type="primary"
              :disabled="!row.is_on_sale || (row.is_limited && row.stock <= 0)"
              @click="doBuy(row)"
              :loading="buyingId === row.id"
            >购买</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- 购买弹窗 -->
    <el-dialog v-model="buyResult" title="购买结果" width="400px">
      <el-result
        :icon="lastBuy?.success ? 'success' : 'error'"
        :title="lastBuy?.success ? '购买成功' : '购买失败'"
        :sub-title="lastBuy?.message"
      />
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted, inject } from 'vue'
import { getShopItems, purchaseItem } from '../api'
import { ElTable, ElTableColumn, ElTag, ElButton, ElDialog, ElResult, ElMessage } from 'element-plus'

const items = ref([])
const buyingId = ref(null)
const buyResult = ref(false)
const lastBuy = ref(null)
const token = inject('token')
const updateGold = inject('updateGold')

const loadItems = async () => {
  try {
    const res = await getShopItems()
    items.value = res.items
  } catch {}
}

const doBuy = async (item) => {
  if (!token.value) {
    ElMessage.warning('请先登录')
    return
  }
  buyingId.value = item.id
  try {
    const res = await purchaseItem(item.id)
    lastBuy.value = res
    buyResult.value = true
    if (res.success) {
      updateGold?.((g) => g - item.price_gold)
      // 减库存显示
      if (item.is_limited && item.stock > 0) item.stock--
    }
  } catch (e) {
    ElMessage.error(e.message || '购买失败')
  }
  buyingId.value = null
}

onMounted(() => loadItems())
</script>
