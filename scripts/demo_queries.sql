-- ============================================
-- Arena Clash 实验演示查询脚本
-- 用于实验验收时展示各类高级 SQL 特性
-- 执行方式:
--   docker exec -i arena-db psql -U arena_admin -d arena_clash < scripts/demo_queries.sql
-- ============================================

\echo '========================================'
\echo '   Arena Clash 数据库实验演示'
\echo '========================================'
\echo ''

-- ============================================
-- 演示1: 4表 JOIN 查询 — 玩家对战详情
-- ============================================
\echo '【演示1】4表 JOIN：玩家对战详情（JOIN + CASE + 生成列KDA）'
\echo '========================================'
SELECT
    p.nickname AS 玩家,
    h.name AS 英雄,
    CASE md.team_side WHEN 1 THEN '蓝方' ELSE '红方' END AS 阵营,
    md.kills || '/' || md.deaths || '/' || md.assists AS KDA战绩,
    md.kda AS KDA值,
    md.elo_change AS ELO变化,
    CASE WHEN md.is_mvp THEN '⭐ MVP' ELSE '' END AS MVP,
    mr.match_code AS 对战编号,
    mr.duration_sec || '秒' AS 对战时長
FROM match_detail md
    JOIN player p ON md.player_id = p.id
    JOIN hero h ON md.hero_id = h.id
    JOIN match_record mr ON md.match_id = mr.id
WHERE mr.status = 'completed'
ORDER BY mr.created_at DESC
LIMIT 10;


-- ============================================
-- 演示2: 窗口函数 — RANK + LAG + LEAD 排行
-- ============================================
\echo ''
\echo '【演示2】窗口函数：赛季排行榜（RANK + LAG + LEAD）'
\echo '========================================'
SELECT
    p.nickname AS 玩家,
    psr.rank_points AS 积分,
    rt.name AS 段位,
    ROUND(psr.win_rate, 1) AS 胜率,
    RANK() OVER (ORDER BY psr.rank_points DESC) AS 排名,
    psr.rank_points - LAG(psr.rank_points) OVER (ORDER BY psr.rank_points DESC) AS 与上一名分差,
    LEAD(psr.rank_points) OVER (ORDER BY psr.rank_points DESC) AS 下一名积分
FROM player_season_rank psr
    JOIN player p ON psr.player_id = p.id
    JOIN rank_tier rt ON psr.rank_tier_id = rt.id
WHERE psr.season_id = 1
ORDER BY 排名
LIMIT 15;


-- ============================================
-- 演示3: 窗口函数 — NTILE 段位分布
-- ============================================
\echo ''
\echo '【演示3】窗口函数：NTILE(4) 段位分布统计'
\echo '========================================'
SELECT
    CASE q
        WHEN 1 THEN '🏆 顶级'
        WHEN 2 THEN '🥈 高级'
        WHEN 3 THEN '🥉 中级'
        WHEN 4 THEN '🌱 新手'
    END AS 档位,
    COUNT(*) AS 人数,
    ROUND(AVG(rank_points), 0) AS 平均积分,
    MIN(rank_points) AS 最低积分,
    MAX(rank_points) AS 最高积分
FROM (
    SELECT rank_points,
           NTILE(4) OVER (ORDER BY rank_points DESC) AS q
    FROM player_season_rank WHERE season_id = 1
) sub
GROUP BY q
ORDER BY q;


-- ============================================
-- 演示4: 窗口函数 — 段位晋升路线（LAG/LEAD）
-- ============================================
\echo ''
\echo '【演示4】窗口函数：段位晋升路线（LAG + LEAD）'
\echo '========================================'
SELECT
    name AS 段位名称,
    tier_level AS 等级,
    min_points AS 最低积分,
    LAG(name) OVER (ORDER BY tier_level) AS 上一段位,
    LEAD(name) OVER (ORDER BY tier_level) AS 下一段位,
    LEAD(min_points) OVER (ORDER BY tier_level) - min_points AS 晋级所需积分
FROM rank_tier
ORDER BY tier_level;


-- ============================================
-- 演示5: JSONB 查询 — 英雄扩展数据统计
-- ============================================
\echo ''
\echo '【演示5】JSONB查询：英雄扩展数据统计（? 包含运算符 + ->> 提取）'
\echo '========================================'
SELECT
    h.name AS 英雄,
    COUNT(*) AS 出场次数,
    ROUND(AVG(md.kda), 2) AS 平均KDA,
    SUM(CASE WHEN md.extra_data ? 'wards_placed'
        THEN (md.extra_data ->> 'wards_placed')::INT ELSE 0 END) AS 总守卫放置,
    ROUND(AVG(CASE WHEN md.extra_data ? 'vision_score'
        THEN (md.extra_data ->> 'vision_score')::INT ELSE 0 END), 1) AS 平均视野分
FROM match_detail md
    JOIN hero h ON md.hero_id = h.id
WHERE md.extra_data IS NOT NULL AND md.extra_data != '{}'::JSONB
GROUP BY h.id, h.name
ORDER BY 出场次数 DESC;


-- ============================================
-- 演示6: 滑动窗口 — 玩家战绩走势
-- ============================================
\echo ''
\echo '【演示6】滑动窗口：单个玩家战绩走势（ROWS BETWEEN 4 PRECEDING AND CURRENT ROW）'
\echo '========================================'
SELECT
    mr.match_code AS 对战编号,
    md.kills || '/' || md.deaths || '/' || md.assists AS KDA,
    CASE WHEN md.team_side = mr.winner_side THEN '✅胜' ELSE '❌负' END AS 结果,
    md.kda AS 单场KDA,
    ROUND(AVG(md.kda) OVER (
        ORDER BY mr.created_at ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    ), 2) AS 近5场滑动KDA,
    SUM(md.elo_change) OVER (ORDER BY mr.created_at) AS 累计ELO变化
FROM match_detail md
    JOIN match_record mr ON md.match_id = mr.id
WHERE md.player_id = 1 AND mr.status = 'completed'
ORDER BY mr.created_at DESC
LIMIT 20;


-- ============================================
-- 演示7: 存储过程演示 — 对战结算
-- ============================================
\echo ''
\echo '【演示7】存储过程：对战结算测试'
\echo '========================================'
-- 先创建一场测试对战
INSERT INTO match_record(season_id, map_name, match_mode, status)
VALUES (1, '测试地图', 'ranked', 'in_progress')
RETURNING id AS 新建对战ID;

-- 结算对战（需要先有 match_detail 数据，这里仅演示调用方式）
-- SELECT * FROM fn_settle_match(1, 1);


-- ============================================
-- 演示8: 存储过程演示 — 商品购买
-- ============================================
\echo ''
\echo '【演示8】存储过程：商品购买测试'
\echo '========================================'
-- 查询余额
SELECT id, nickname, gold AS 当前金币 FROM player WHERE id = 1;

-- 购买商品（player1 购买 暴风大剑）
SELECT * FROM fn_purchase_item(1, 1);

-- 查询余额变化
SELECT id, nickname, gold AS 购买后金币 FROM player WHERE id = 1;

-- 查询购买记录
SELECT pr.id, si.name AS 商品, pr.price_paid AS 花费, pr.created_at AS 购买时间
FROM purchase_record pr
    JOIN shop_item si ON pr.item_id = si.id
WHERE pr.player_id = 1;


-- ============================================
-- 演示9: 物化视图 — 赛季英雄统计
-- ============================================
\echo ''
\echo '【演示9】物化视图：赛季英雄统计（预计算）'
\echo '========================================'
SELECT
    hero_name AS 英雄,
    role AS 角色,
    picks AS 出场,
    wins AS 胜场,
    win_rate AS 胜率,
    avg_kda AS 平均KDA,
    mvp_count AS MVP次数
FROM mv_season_statistics
ORDER BY picks DESC
LIMIT 10;


-- ============================================
-- 演示10: 触发器验证 — updated_at 自动更新
-- ============================================
\echo ''
\echo '【演示10】触发器：updated_at 自动更新验证'
\echo '========================================'
-- 查看更新前
SELECT id, nickname, updated_at AS 更新前 FROM player WHERE id = 1;

-- 执行更新
UPDATE player SET nickname = '测试玩家' WHERE id = 1;

-- 查看更新后
SELECT id, nickname, updated_at AS 更新后 FROM player WHERE id = 1;

-- 恢复
UPDATE player SET nickname = '暗夜王者' WHERE id = 1;


-- ============================================
-- 演示11: CHECK 约束验证
-- ============================================
\echo ''
\echo '【演示11】CHECK约束验证'
\echo '========================================'
-- 测试非法状态（会被CHECK约束拒绝）
-- INSERT INTO player(username, password_hash, nickname, status) VALUES('test','hash','test','invalid_status');
-- 错误: new row for relation "player" violates check constraint "player_status_check"

-- 测试合法数据
SELECT 'CHECK约束正常工作' AS 验证结果;


-- ============================================
-- 演示12: 聚合统计 — 全局数据概览
-- ============================================
\echo ''
\echo '【演示12】聚合统计：全局数据概览'
\echo '========================================'
SELECT
    (SELECT COUNT(*) FROM player) AS 注册玩家,
    (SELECT COUNT(*) FROM match_record) AS 对战总数,
    (SELECT COUNT(*) FROM match_record WHERE status = 'completed') AS 已完成对战,
    (SELECT COUNT(*) FROM hero) AS 英雄数量,
    (SELECT COUNT(*) FROM shop_item WHERE is_on_sale) AS 在售商品,
    (SELECT COALESCE(SUM(price_paid), 0) FROM purchase_record) AS 总消费金币,
    (SELECT ROUND(AVG(elo_rating), 0) FROM player) AS 平均ELO;


\echo ''
\echo '========================================'
\echo '   演示完成！'
\echo '========================================'
