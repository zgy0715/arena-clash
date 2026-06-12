-- ============================================
-- Arena Clash 数据库优化迁移脚本
-- 添加缺失索引、优化查询性能
-- 幂等设计，可安全重复执行
-- ============================================

-- 1) friendship 表添加 friend_id 方向索引
-- 查询"谁的好友包含某用户"时避免全表扫描
CREATE INDEX IF NOT EXISTS idx_friendship_friend ON friendship(friend_id);

-- 2) audit_log 添加 player_id 索引
-- 查询某玩家的审计日志时避免全表扫描
CREATE INDEX IF NOT EXISTS idx_audit_player ON audit_log(player_id);

-- 3) purchase_record 添加 item_id 索引
-- 查询某商品被谁购买时避免全表扫描
CREATE INDEX IF NOT EXISTS idx_purchase_item ON purchase_record(item_id);

-- 4) match_record 添加 (status, created_at) 复合索引
-- 按状态+时间范围查询对战是常见场景
CREATE INDEX IF NOT EXISTS idx_match_status_created ON match_record(status, created_at DESC);

-- 5) player 表添加 email 索引（如后续支持邮箱登录）
CREATE INDEX IF NOT EXISTS idx_player_email ON player(email) WHERE email IS NOT NULL;

-- 6) friend_request 添加 requester_id 索引
-- 查询"我发出的好友请求"时使用
CREATE INDEX IF NOT EXISTS idx_friend_request_requester ON friend_request(requester_id, status);

-- 7) player_season_rank 添加 player_id 单列索引
-- 查询某玩家所有赛季段位记录
CREATE INDEX IF NOT EXISTS idx_psr_player ON player_season_rank(player_id);

-- 8) match_detail 添加 (match_id, team_side) 复合索引
-- 按对战+阵营查询参战玩家
CREATE INDEX IF NOT EXISTS idx_detail_match_team ON match_detail(match_id, team_side);

-- 9) hero 添加 (is_active, role) 复合索引
-- 查询在役英雄按角色筛选
CREATE INDEX IF NOT EXISTS idx_hero_active_role ON hero(is_active, role) WHERE is_active = TRUE;

-- 10) shop_item 添加 (is_on_sale, item_type) 复合索引
-- 商城页面查询在售商品按类型筛选
CREATE INDEX IF NOT EXISTS idx_shop_sale_type ON shop_item(is_on_sale, item_type) WHERE is_on_sale = TRUE;

-- 11) ANALYZE 更新统计信息，让查询优化器使用新索引
ANALYZE;
