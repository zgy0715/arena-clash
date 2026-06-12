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
  { path: '/:pathMatch(.*)*', name: 'NotFound', component: () => import('../views/NotFound.vue') },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// 路由守卫：管理后台/审计日志需登录且为管理员
router.beforeEach((to) => {
  if (to.meta.requiresAdmin) {
    const token = localStorage.getItem('arena_token')
    const isAdmin = localStorage.getItem('arena_is_admin') === '1'
    if (!token || !isAdmin) return { path: '/' }
  }
})

export default router
