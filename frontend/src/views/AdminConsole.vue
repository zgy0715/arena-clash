<template>
  <div>
    <div class="card">
      <div class="card-title">
        🛠️ 管理后台
        <el-tag size="small" type="danger" style="margin-left:12px">仅管理员</el-tag>
        <el-tag size="small" type="warning" style="margin-left:4px">全 CRUD + 级联删除</el-tag>
        <el-button size="small" style="margin-left:auto" @click="refreshStats" :loading="refreshing">🔄 刷新统计视图</el-button>
      </div>

      <el-tabs v-model="activeTab">
        <!-- ============ 英雄管理 ============ -->
        <el-tab-pane label="英雄管理" name="heroes">
          <div class="flex-row mb-16">
            <el-button type="primary" size="small" @click="openCreate('hero')">➕ 新增英雄</el-button>
            <span style="color:#8899b4;font-size:12px">删除被对战引用的英雄会被拦截，可改为"下架"（软删，is_active=false）</span>
          </div>
          <el-table :data="heroes" stripe size="small" max-height="560">
            <el-table-column prop="id" label="ID" width="55" />
            <el-table-column prop="name" label="名称" width="110" />
            <el-table-column prop="title" label="称号" width="110" />
            <el-table-column prop="role" label="定位" width="90">
              <template #default="{ row }"><el-tag size="small">{{ roleText(row.role) }}</el-tag></template>
            </el-table-column>
            <el-table-column label="金币价" width="90">
              <template #default="{ row }"><span class="gold-text">{{ row.price_gold }}</span></template>
            </el-table-column>
            <el-table-column prop="difficulty" label="难度" width="70" />
            <el-table-column label="状态" width="80">
              <template #default="{ row }">
                <el-tag size="small" :type="row.is_active ? 'success' : 'info'">{{ row.is_active ? '在役' : '已下架' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="160">
              <template #default="{ row }">
                <el-button size="small" @click="openEdit('hero', row)">编辑</el-button>
                <el-button size="small" type="danger" @click="delHero(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <!-- ============ 商品管理 ============ -->
        <el-tab-pane label="商品管理" name="items">
          <div class="flex-row mb-16">
            <el-button type="primary" size="small" @click="openCreate('item')">➕ 新增商品</el-button>
            <span style="color:#8899b4;font-size:12px">删除商品会级联删除其购买记录（ON DELETE CASCADE）</span>
          </div>
          <el-table :data="items" stripe size="small" max-height="560">
            <el-table-column prop="id" label="ID" width="55" />
            <el-table-column prop="name" label="商品名" width="140" />
            <el-table-column prop="item_type" label="类型" width="90">
              <template #default="{ row }"><el-tag size="small">{{ row.item_type }}</el-tag></template>
            </el-table-column>
            <el-table-column label="金币价" width="90">
              <template #default="{ row }"><span class="gold-text">{{ row.price_gold }}</span></template>
            </el-table-column>
            <el-table-column prop="stock" label="库存" width="80" />
            <el-table-column label="限量" width="70">
              <template #default="{ row }"><el-tag size="small" :type="row.is_limited ? 'danger' : 'info'">{{ row.is_limited ? '限量' : '无限' }}</el-tag></template>
            </el-table-column>
            <el-table-column label="在售" width="70">
              <template #default="{ row }"><el-tag size="small" :type="row.is_on_sale ? 'success' : 'info'">{{ row.is_on_sale ? '在售' : '下架' }}</el-tag></template>
            </el-table-column>
            <el-table-column prop="description" label="描述" />
            <el-table-column label="操作" width="160">
              <template #default="{ row }">
                <el-button size="small" @click="openEdit('item', row)">编辑</el-button>
                <el-button size="small" type="danger" @click="delItem(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <!-- ============ 玩家管理 ============ -->
        <el-tab-pane label="玩家管理" name="players">
          <div class="flex-row mb-16">
            <el-input v-model="playerQuery" placeholder="搜索用户名/昵称" style="width:220px" clearable @keyup.enter="loadPlayers(1)" />
            <el-button type="primary" size="small" @click="loadPlayers(1)">🔍 搜索</el-button>
            <span style="color:#8899b4;font-size:12px">删除玩家会级联清理 对战详情/赛季段位/购买记录/好友（存储过程 + AFTER DELETE 触发器）</span>
          </div>
          <el-table :data="players" stripe size="small" max-height="520">
            <el-table-column prop="id" label="ID" width="55" />
            <el-table-column prop="username" label="用户名" width="110" />
            <el-table-column prop="nickname" label="昵称" width="120" />
            <el-table-column prop="elo_rating" label="ELO" width="80" />
            <el-table-column label="金币" width="90">
              <template #default="{ row }"><span class="gold-text">{{ row.gold }}</span></template>
            </el-table-column>
            <el-table-column prop="status" label="状态" width="90" />
            <el-table-column label="好友" width="60">
              <template #default="{ row }">{{ row.friend_count }}</template>
            </el-table-column>
            <el-table-column label="管理员" width="80">
              <template #default="{ row }"><el-tag v-if="row.is_admin" size="small" type="warning">管理员</el-tag></template>
            </el-table-column>
            <el-table-column label="操作" width="160">
              <template #default="{ row }">
                <el-button size="small" @click="openEdit('player', row)">编辑</el-button>
                <el-button size="small" type="danger" :disabled="row.is_admin" @click="delPlayer(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
          <div class="flex-row mt-16" style="justify-content:flex-end">
            <el-pagination
              layout="prev, pager, next, total"
              :total="playerTotal" :page-size="20" :current-page="playerPage"
              @current-change="loadPlayers"
            />
          </div>
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- ============ 通用 新增/编辑 弹窗 ============ -->
    <el-dialog v-model="dialogVisible" :title="dialogTitle" width="520px" :close-on-click-modal="false">
      <el-form :model="form" label-width="92px">
        <!-- 英雄 -->
        <template v-if="dialogType === 'hero'">
          <el-form-item label="名称"><el-input v-model="form.name" /></el-form-item>
          <el-form-item label="称号"><el-input v-model="form.title" /></el-form-item>
          <el-form-item label="定位">
            <el-select v-model="form.role" style="width:100%">
              <el-option v-for="r in roles" :key="r.value" :label="r.label" :value="r.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="金币价"><el-input-number v-model="form.price_gold" :min="0" /></el-form-item>
          <el-form-item label="点券价"><el-input-number v-model="form.price_rp" :min="0" /></el-form-item>
          <el-form-item label="难度"><el-input-number v-model="form.difficulty" :min="1" :max="10" /></el-form-item>
          <el-form-item label="描述"><el-input v-model="form.description" type="textarea" :rows="2" /></el-form-item>
          <el-form-item label="免费英雄"><el-switch v-model="form.is_free" /></el-form-item>
          <el-form-item label="在役"><el-switch v-model="form.is_active" /></el-form-item>
        </template>
        <!-- 商品 -->
        <template v-else-if="dialogType === 'item'">
          <el-form-item label="商品名"><el-input v-model="form.name" /></el-form-item>
          <el-form-item label="类型">
            <el-select v-model="form.item_type" style="width:100%">
              <el-option v-for="t in itemTypes" :key="t" :label="t" :value="t" />
            </el-select>
          </el-form-item>
          <el-form-item label="关联英雄ID"><el-input-number v-model="form.hero_id" :min="0" /> <span style="color:#8899b4;font-size:12px;margin-left:8px">0/留空=不关联</span></el-form-item>
          <el-form-item label="金币价"><el-input-number v-model="form.price_gold" :min="0" /></el-form-item>
          <el-form-item label="点券价"><el-input-number v-model="form.price_rp" :min="0" /></el-form-item>
          <el-form-item label="库存"><el-input-number v-model="form.stock" :min="-1" /> <span style="color:#8899b4;font-size:12px;margin-left:8px">-1=无限</span></el-form-item>
          <el-form-item label="限量"><el-switch v-model="form.is_limited" /></el-form-item>
          <el-form-item label="在售"><el-switch v-model="form.is_on_sale" /></el-form-item>
          <el-form-item label="描述"><el-input v-model="form.description" type="textarea" :rows="2" /></el-form-item>
        </template>
        <!-- 玩家（仅编辑）-->
        <template v-else-if="dialogType === 'player'">
          <el-form-item label="昵称"><el-input v-model="form.nickname" /></el-form-item>
          <el-form-item label="金币"><el-input-number v-model="form.gold" :min="0" /></el-form-item>
          <el-form-item label="ELO"><el-input-number v-model="form.elo_rating" :min="0" /></el-form-item>
          <el-form-item label="状态">
            <el-select v-model="form.status" style="width:100%">
              <el-option v-for="s in statuses" :key="s" :label="s" :value="s" />
            </el-select>
          </el-form-item>
          <el-form-item label="管理员"><el-switch v-model="form.is_admin" /></el-form-item>
        </template>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  ElTabs, ElTabPane, ElTable, ElTableColumn, ElButton, ElTag, ElDialog,
  ElForm, ElFormItem, ElInput, ElInputNumber, ElSelect, ElOption, ElSwitch,
  ElPagination, ElMessage, ElMessageBox,
} from 'element-plus'
import {
  adminListHeroes, adminCreateHero, adminUpdateHero, adminDeleteHero,
  adminListItems, adminCreateItem, adminUpdateItem, adminDeleteItem,
  adminListPlayers, adminUpdatePlayer, adminDeletePlayer, adminRefreshStats,
} from '../api'

const roles = [
  { value: 'fighter', label: '战士' }, { value: 'mage', label: '法师' },
  { value: 'assassin', label: '刺客' }, { value: 'marksman', label: '射手' },
  { value: 'support', label: '辅助' }, { value: 'tank', label: '坦克' },
]
const roleMap = Object.fromEntries(roles.map(r => [r.value, r.label]))
const roleText = (r) => roleMap[r] || r
const itemTypes = ['hero', 'skin', 'emote', 'frame']
const statuses = ['online', 'offline', 'in_match', 'banned']

const activeTab = ref('heroes')
const heroes = ref([])
const items = ref([])
const players = ref([])
const playerQuery = ref('')
const playerTotal = ref(0)
const playerPage = ref(1)
const refreshing = ref(false)

const dialogVisible = ref(false)
const dialogType = ref('hero')
const dialogMode = ref('create')
const editId = ref(null)
const saving = ref(false)
const form = ref({})

const dialogTitle = computed(() => {
  const t = { hero: '英雄', item: '商品', player: '玩家' }[dialogType.value]
  return (dialogMode.value === 'create' ? '新增' : '编辑') + t
})

const loadHeroes = async () => { try { heroes.value = (await adminListHeroes()).heroes } catch (e) { ElMessage.error(e.message) } }
const loadItems = async () => { try { items.value = (await adminListItems()).items } catch (e) { ElMessage.error(e.message) } }
const loadPlayers = async (page = 1) => {
  playerPage.value = page
  try {
    const res = await adminListPlayers({ q: playerQuery.value || undefined, page, page_size: 20 })
    players.value = res.players
    playerTotal.value = res.total
  } catch (e) { ElMessage.error(e.message) }
}

const openCreate = (type) => {
  dialogType.value = type
  dialogMode.value = 'create'
  editId.value = null
  if (type === 'hero') form.value = { name: '', title: '', role: 'fighter', price_gold: 4500, price_rp: 0, difficulty: 1, description: '', is_free: false, is_active: true }
  else if (type === 'item') form.value = { name: '', item_type: 'skin', hero_id: 0, price_gold: 100, price_rp: 0, stock: -1, is_limited: false, is_on_sale: true, description: '' }
  dialogVisible.value = true
}

const openEdit = (type, row) => {
  dialogType.value = type
  dialogMode.value = 'edit'
  editId.value = row.id
  form.value = { ...row, hero_id: row.hero_id || 0 }
  dialogVisible.value = true
}

const save = async () => {
  saving.value = true
  try {
    const data = { ...form.value }
    if (dialogType.value === 'hero') {
      if (dialogMode.value === 'create') await adminCreateHero(data)
      else await adminUpdateHero(editId.value, data)
      await loadHeroes()
    } else if (dialogType.value === 'item') {
      if (!data.hero_id) data.hero_id = null
      if (dialogMode.value === 'create') await adminCreateItem(data)
      else await adminUpdateItem(editId.value, data)
      await loadItems()
    } else if (dialogType.value === 'player') {
      await adminUpdatePlayer(editId.value, {
        nickname: data.nickname, gold: data.gold, elo_rating: data.elo_rating,
        status: data.status, is_admin: data.is_admin,
      })
      await loadPlayers(playerPage.value)
    }
    ElMessage.success('保存成功')
    dialogVisible.value = false
  } catch (e) { ElMessage.error(e.message || '保存失败') }
  saving.value = false
}

const delHero = async (row) => {
  try {
    await ElMessageBox.confirm(`确认删除英雄「${row.name}」？将尝试硬删除。`, '删除确认', { type: 'warning' })
  } catch { return }
  try {
    const res = await adminDeleteHero(row.id, true)   // 先尝试硬删
    ElMessage.success(res.message)
    await loadHeroes()
  } catch (e) {
    // 被对战引用 → 409 → 提供软删（下架）兜底
    try {
      await ElMessageBox.confirm(`${e.message}\n是否改为"下架"（软删除）？`, '无法硬删除', { type: 'warning', confirmButtonText: '改为下架' })
    } catch { return }
    try {
      const res = await adminDeleteHero(row.id, false)
      ElMessage.success(res.message)
      await loadHeroes()
    } catch (e2) { ElMessage.error(e2.message) }
  }
}

const delItem = async (row) => {
  try {
    await ElMessageBox.confirm(`确认删除商品「${row.name}」？关联购买记录将级联删除。`, '删除确认', { type: 'warning' })
  } catch { return }
  try {
    const res = await adminDeleteItem(row.id)
    ElMessage.success(res.message)
    await loadItems()
  } catch (e) { ElMessage.error(e.message) }
}

const delPlayer = async (row) => {
  try {
    await ElMessageBox.confirm(
      `确认删除玩家「${row.nickname}」(ID ${row.id})？\n将级联删除其全部对战详情、赛季段位、购买记录、好友关系，且不可恢复。`,
      '级联删除确认', { type: 'warning', confirmButtonText: '确认删除' },
    )
  } catch { return }
  try {
    const res = await adminDeletePlayer(row.id)
    ElMessageBox.alert(res.message, '删除完成', { type: 'success' })
    await loadPlayers(playerPage.value)
  } catch (e) { ElMessage.error(e.message) }
}

const refreshStats = async () => {
  refreshing.value = true
  try { ElMessage.success((await adminRefreshStats()).message) }
  catch (e) { ElMessage.error(e.message) }
  refreshing.value = false
}

onMounted(() => {
  loadHeroes()
  loadItems()
  loadPlayers(1)
})
</script>
