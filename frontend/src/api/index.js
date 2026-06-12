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
    if (err.response?.status === 401) {
      const hadToken = !!localStorage.getItem('arena_token')
      // 仅当已登录用户的 Token 过期/无效时才清除登录状态
      // 登录接口本身返回 401（密码错误）不应触发清除
      if (hadToken) {
        ;['arena_token','arena_nickname','arena_elo','arena_player_id','arena_is_admin']
          .forEach(k => localStorage.removeItem(k))
        if (window.location.pathname !== '/') {
          window.location.href = '/'
        }
      }
    }
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

// ===== 管理后台（模块1，需管理员）=====
export const adminListHeroes = () => api.get('/admin/heroes')
export const adminCreateHero = (data) => api.post('/admin/heroes', data)
export const adminUpdateHero = (id, data) => api.put(`/admin/heroes/${id}`, data)
export const adminDeleteHero = (id, hard = false) => api.delete(`/admin/heroes/${id}`, { params: { hard } })

export const adminListItems = () => api.get('/admin/shop-items')
export const adminCreateItem = (data) => api.post('/admin/shop-items', data)
export const adminUpdateItem = (id, data) => api.put(`/admin/shop-items/${id}`, data)
export const adminDeleteItem = (id) => api.delete(`/admin/shop-items/${id}`)

export const adminListPlayers = (params = {}) => api.get('/admin/players', { params })
export const adminUpdatePlayer = (id, data) => api.put(`/admin/players/${id}`, data)
export const adminDeletePlayer = (id) => api.delete(`/admin/players/${id}`)
export const adminRefreshStats = () => api.post('/admin/refresh-stats')

// ===== 对战中心（模块2）=====
export const createFullMatch = (data) => api.post('/matches/create-full', data)
export const startMatch = (matchId) => api.post(`/matches/${matchId}/start`)
export const settleMatch = (matchId, winnerSide) =>
  api.post(`/matches/${matchId}/settle`, { winner_side: winnerSide })
export const getMatchDetail = (matchId) => api.get(`/matches/${matchId}`)
export const lookupHeroes = () => api.get('/matches/lookups/heroes')

// ===== 社交（模块3）=====
export const sendFriendRequest = (addresseeId) =>
  api.post('/social/friend-requests', { addressee_id: addresseeId })
export const getIncomingRequests = () => api.get('/social/friend-requests/incoming')
export const acceptFriendRequest = (id) => api.post(`/social/friend-requests/${id}/accept`)
export const rejectFriendRequest = (id) => api.post(`/social/friend-requests/${id}/reject`)
export const getFriends = () => api.get('/social/friends')
export const deleteFriend = (friendId) => api.delete(`/social/friends/${friendId}`)
export const compareWithFriend = (friendId) => api.get(`/social/compare/${friendId}`)

// ===== 赛季中心（模块4）=====
export const getSeasons = () => api.get('/seasons')
export const resetSeason = () => api.post('/seasons/reset')
export const getSeasonRankings = (seasonId, topN = 50) =>
  api.get(`/leaderboard/season/${seasonId}`, { params: { top_n: topN } })

// ===== 审计日志（模块5，需管理员）=====
export const getAuditLogs = (params = {}) => api.get('/audit/logs', { params })
export const getAuditActions = () => api.get('/audit/actions')
export const getAuditStats = () => api.get('/audit/stats')
