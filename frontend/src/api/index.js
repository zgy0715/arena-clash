import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 10000,
})

// 请求拦截器：自动附加 JWT Token
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('arena_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截器：统一错误处理
api.interceptors.response.use(
  (res) => res.data,
  (err) => {
    const msg = err.response?.data?.detail || err.message || '请求失败'
    return Promise.reject(new Error(msg))
  }
)

// ===== 认证 =====
export const login = (username, password) =>
  api.post('/auth/login', { username, password })

export const register = (username, password, nickname) =>
  api.post('/auth/register', { username, password, nickname })

// ===== 玩家 =====
export const getPlayer = (id) => api.get(`/players/${id}`)
export const getPlayerStats = (id) => api.get(`/players/${id}/stats`)

// ===== 排行榜 =====
export const getLeaderboard = (topN = 100) =>
  api.get('/leaderboard/global', { params: { top_n: topN } })

export const syncLeaderboard = () => api.post('/leaderboard/sync')

// ===== 对战 =====
export const getMatches = (params = {}) =>
  api.get('/matches', { params: { limit: 30, ...params } })

// ===== 商城 =====
export const getShopItems = (params = {}) =>
  api.get('/shop/items', { params })

export const purchaseItem = (itemId) =>
  api.post('/shop/purchase', { item_id: itemId })

// ===== 统计 =====
export const getOverview = () => api.get('/stats/overview')
export const getTierDistribution = () => api.get('/stats/tier-distribution')
export const getHeroStats = () => api.get('/stats/hero-stats')
export const getMatchTrend = (days = 30) =>
  api.get('/stats/match-trend', { params: { days } })
export const getMvSeasonStats = () => api.get('/stats/mv-season')
