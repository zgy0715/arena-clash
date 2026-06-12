import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  { path: '/', name: 'Dashboard', component: () => import('../views/Dashboard.vue') },
  { path: '/leaderboard', name: 'Leaderboard', component: () => import('../views/Leaderboard.vue') },
  { path: '/players', name: 'Players', component: () => import('../views/Players.vue') },
  { path: '/matches', name: 'Matches', component: () => import('../views/Matches.vue') },
  { path: '/shop', name: 'Shop', component: () => import('../views/Shop.vue') },
  { path: '/matches-center', name: 'MatchCenter', component: () => import('../views/MatchCenter.vue') },
  { path: '/social', name: 'Social', component: () => import('../views/Social.vue') },
  { path: '/seasons', name: 'SeasonCenter', component: () => import('../views/SeasonCenter.vue') },
  { path: '/admin', name: 'AdminConsole', component: () => import('../views/AdminConsole.vue'), meta: { requiresAdmin: true } },
  { path: '/audit', name: 'AuditLog', component: () => import('../views/AuditLog.vue'), meta: { requiresAdmin: true } },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// 路由守卫：管理后台/审计日志仅管理员可进入
router.beforeEach((to) => {
  if (to.meta.requiresAdmin && localStorage.getItem('arena_is_admin') !== '1') {
    return { path: '/' }
  }
})

export default router
