import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  { path: '/', name: 'Dashboard', component: () => import('../views/Dashboard.vue') },
  { path: '/leaderboard', name: 'Leaderboard', component: () => import('../views/Leaderboard.vue') },
  { path: '/players', name: 'Players', component: () => import('../views/Players.vue') },
  { path: '/matches', name: 'Matches', component: () => import('../views/Matches.vue') },
  { path: '/shop', name: 'Shop', component: () => import('../views/Shop.vue') },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
