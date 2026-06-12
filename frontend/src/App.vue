<template>
  <div>
    <!-- 顶部导航 -->
    <header class="app-header">
      <span class="logo">⚔️ Arena Clash 竞技场对决</span>
      <nav class="nav-links">
        <router-link to="/">📊 数据大屏</router-link>
        <router-link to="/leaderboard">🏆 排行榜</router-link>
        <router-link to="/players">👤 玩家</router-link>
        <router-link to="/matches">⚔️ 对战</router-link>
        <router-link to="/shop">🛒 商城</router-link>
        <router-link to="/matches-center">🎮 对战中心</router-link>
        <router-link to="/social">🤝 社交</router-link>
        <router-link to="/seasons">📅 赛季中心</router-link>
        <router-link v-if="isAdmin" to="/admin">🛠️ 管理后台</router-link>
        <router-link v-if="isAdmin" to="/audit">📋 审计日志</router-link>
      </nav>
      <div class="user-info">
        <template v-if="token">
          <span>👤 {{ nickname }}</span>
          <span>🏆 ELO: {{ elo }}</span>
          <span class="gold">💰 {{ gold }}</span>
          <el-button size="small" @click="doLogout">退出</el-button>
        </template>
        <template v-else>
          <el-button size="small" type="primary" @click="showLogin = true">🔑 登录</el-button>
        </template>
      </div>
    </header>

    <!-- 登录弹窗 -->
    <el-dialog v-model="showLogin" title="用户登录" width="380px" :close-on-click-modal="false">
      <el-input v-model="loginForm.username" placeholder="用户名" style="margin-bottom:12px" />
      <el-input v-model="loginForm.password" placeholder="密码" type="password" show-password @keyup.enter="doLogin" />
      <template #footer>
        <el-button type="primary" @click="doLogin" :loading="logging">登录</el-button>
      </template>
    </el-dialog>

    <!-- 主内容 -->
    <main class="main-content">
      <router-view :key="$route.fullPath" />
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, provide } from 'vue'
import { login, getPlayer } from './api'

const token = ref('')
const nickname = ref('')
const elo = ref(0)
const gold = ref(0)
const isAdmin = ref(false)
const playerId = ref(null)
const showLogin = ref(false)
const logging = ref(false)
const loginForm = ref({ username: 'player1', password: 'test1234' })

provide('token', token)
provide('isAdmin', isAdmin)
provide('playerId', playerId)
provide('updateGold', (v) => { gold.value = v })

const doLogin = async () => {
  logging.value = true
  try {
    const res = await login(loginForm.value.username, loginForm.value.password)
    token.value = res.access_token
    nickname.value = res.player.nickname
    elo.value = res.player.elo_rating
    isAdmin.value = !!res.player.is_admin
    playerId.value = res.player.id
    localStorage.setItem('arena_token', token.value)
    localStorage.setItem('arena_nickname', nickname.value)
    localStorage.setItem('arena_elo', elo.value)
    localStorage.setItem('arena_player_id', res.player.id)
    localStorage.setItem('arena_is_admin', res.player.is_admin ? '1' : '')
    try {
      const p = await getPlayer(res.player.id)
      gold.value = p.gold
    } catch {}
    showLogin.value = false
  } catch (e) {
    ElMessage.error(e.message || '登录失败')
  }
  logging.value = false
}

const doLogout = () => {
  token.value = ''; nickname.value = ''; elo.value = 0; gold.value = 0
  isAdmin.value = false; playerId.value = null
  ;['arena_token','arena_nickname','arena_elo','arena_player_id','arena_is_admin']
    .forEach(k => localStorage.removeItem(k))
}

import { ElMessage } from 'element-plus'

onMounted(() => {
  token.value = localStorage.getItem('arena_token') || ''
  nickname.value = localStorage.getItem('arena_nickname') || ''
  elo.value = parseInt(localStorage.getItem('arena_elo') || '0')
  isAdmin.value = localStorage.getItem('arena_is_admin') === '1'
  playerId.value = parseInt(localStorage.getItem('arena_player_id') || '0') || null
})
</script>
