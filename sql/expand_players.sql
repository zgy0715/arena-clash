-- ============================================
-- Arena Clash 玩家数据扩展脚本
-- 新增 75 名玩家 (player26 - player100)
-- 包含：玩家、赛季段位、好友关系、好友请求
-- 幂等设计：已存在的玩家不会重复插入
-- ============================================

-- ============================================
-- 1. 插入新玩家 (player26 - player100)
-- ============================================
DO $$
DECLARE
    v_password_hash TEXT := '$2b$12$khQph93S.msZ49YZCu6x4ODve8ZQcRZGuFaFO7qX45c1dAWvnDtmi';
    v_nicknames TEXT[] := ARRAY[
        '剑圣无双', '暗影猎手', '雷霆战神', '冰霜女皇', '烈焰骑士',
        '虚空行者', '星辰守护', '龙魂战士', '凤翼天翔', '狂风绝息',
        '永恒之刃', '破晓剑意', '深渊领主', '铁壁战魂', '幻影刺客',
        '苍穹之翼', '碧海潮生', '紫电青霜', '赤焰凤凰', '银河猎鹰',
        '墨影流光', '天罚之刃', '霜华绝代', '炎龙破阵', '星河倒转',
        '暗夜君王', '碧落黄泉', '雷鸣九天', '冰心无尘', '火舞狂沙',
        '风华绝世', '龙吟九霄', '月华如水', '云破天惊', '剑气纵横',
        '血月降临', '金戈铁马', '雪域苍狼', '炎阳真诀', '幽冥鬼影',
        '天命归一', '破军星君', '流光飞舞', '寒冰王座', '烈日当空',
        '暗潮涌动', '星陨如雨', '龙战于野', '凤舞九天', '雷神降世',
        '冰魄银针', '火眼金睛', '风卷残云', '月下花前', '云中白鹤',
        '剑指苍穹', '血战八方', '金刚不坏', '雪舞轻扬', '炎帝焚天',
        '幽兰飘香', '天机妙算', '破浪乘风', '流萤飞舞', '寒梅傲雪',
        '烈风斩月', '暗夜精灵', '星火燎原', '龙腾四海', '凤鸣朝阳',
        '雷霆万钧', '冰封万里', '火凤燎原', '风林火山', '月影霜华',
        '云端漫步', '剑心通明', '血色浪漫', '金蝉脱壳'
    ];
    v_elo       INT;
    v_level     INT;
    v_exp       INT;
    v_gold      INT;
    v_total     INT;
    v_wins      INT;
    v_losses    INT;
    v_status    TEXT;
    v_created   TIMESTAMP;
    v_i         INT;
    v_rand      DOUBLE PRECISION;
BEGIN
    FOR v_i IN 26..100 LOOP
        -- 幂等检查：用户名已存在则跳过
        IF EXISTS (SELECT 1 FROM player WHERE username = 'player' || v_i) THEN
            CONTINUE;
        END IF;

        -- 生成正态分布的 ELO（均值 1400，标准差 300，范围 800-2200）
        -- Box-Muller 变换近似正态分布
        v_rand := RANDOM();
        v_elo := GREATEST(800, LEAST(2200,
            ROUND(1400 + 300 * SQRT(-2 * LN(GREATEST(v_rand, 0.0001))) * COS(2 * PI() * RANDOM()))
        ));
        -- 确保为整数
        v_elo := v_elo::INT;

        -- 等级：与 ELO 正相关 (1-50)
        v_level := GREATEST(1, LEAST(50, ROUND((v_elo - 600) / 40.0)::INT));

        -- 经验值：与等级正相关
        v_exp := v_level * 1600 + FLOOR(RANDOM() * 1000)::INT;

        -- 金币：500 - 50000，与等级有一定关联
        v_gold := GREATEST(500, LEAST(50000, v_level * 600 + FLOOR(RANDOM() * 5000)::INT));

        -- 总场次：10 - 500，与等级有一定关联
        v_total := GREATEST(10, LEAST(500, v_level * 8 + FLOOR(RANDOM() * 50)::INT));

        -- 胜率 40%-60%，计算胜场和负场
        v_wins := ROUND(v_total * (0.4 + RANDOM() * 0.2))::INT;
        v_losses := v_total - v_wins;
        -- 确保非负
        IF v_wins < 0 THEN v_wins := 0; END IF;
        IF v_losses < 0 THEN v_losses := 0; END IF;

        -- 状态：约 80% 离线，20% 在线
        v_status := CASE WHEN RANDOM() < 0.2 THEN 'online' ELSE 'offline' END;

        -- 创建时间：最近 180 天内随机
        v_created := NOW() - (FLOOR(RANDOM() * 180)::INT || ' days')::INTERVAL
                     - (FLOOR(RANDOM() * 86400)::INT || ' seconds')::INTERVAL;

        INSERT INTO player(
            username, password_hash, nickname,
            elo_rating, level, experience, gold,
            total_matches, wins, losses,
            status, is_admin, friend_count, created_at
        ) VALUES (
            'player' || v_i,
            v_password_hash,
            v_nicknames[v_i - 25],
            v_elo, v_level, v_exp, v_gold,
            v_total, v_wins, v_losses,
            v_status, FALSE, 0, v_created
        );
    END LOOP;
END $$;

-- ============================================
-- 2. 为新玩家插入赛季段位 (player_season_rank)
-- ============================================
INSERT INTO player_season_rank(player_id, season_id, rank_tier_id, rank_points, peak_points, matches_played, wins, losses)
SELECT
    p.id,
    1,  -- season_id = 1 (S1 青铜时代)
    CASE
        WHEN p.elo_rating < 600  THEN 1   -- 青铜I
        WHEN p.elo_rating < 800  THEN 2   -- 青铜II
        WHEN p.elo_rating < 1000 THEN 3   -- 青铜III
        WHEN p.elo_rating < 1200 THEN 4   -- 白银I
        WHEN p.elo_rating < 1400 THEN 5   -- 白银II
        WHEN p.elo_rating < 1600 THEN 6   -- 白银III
        WHEN p.elo_rating < 1800 THEN 7   -- 黄金I
        WHEN p.elo_rating < 2000 THEN 8   -- 黄金II
        ELSE 9                                -- 黄金III
    END,
    GREATEST(0, p.elo_rating - 500 + FLOOR(RANDOM() * 200 - 100)::INT),  -- rank_points
    GREATEST(0, p.elo_rating - 500 + FLOOR(RANDOM() * 100 + 50)::INT),   -- peak_points
    p.total_matches,
    p.wins,
    p.losses
FROM player p
WHERE p.username LIKE 'player%'
  AND p.username ~ '^player\d+$'
  AND NOT EXISTS (
      SELECT 1 FROM player_season_rank psr
      WHERE psr.player_id = p.id AND psr.season_id = 1
  );

-- ============================================
-- 3. 添加好友关系（约 40 条双向好友记录）
-- ============================================
DO $$
DECLARE
    v_new_ids   INT[];
    v_old_ids   INT[];
    v_i         INT;
    v_new_id    INT;
    v_old_id    INT;
    v_count     INT := 0;
    v_max_count INT := 40;
BEGIN
    -- 获取新玩家 ID 列表 (player26-player100)
    SELECT ARRAY(
        SELECT id FROM player
        WHERE username LIKE 'player%'
          AND username ~ '^player\d+$'
          AND CAST(REGEXP_REPLACE(username, '\D', '', 'g') AS INT) >= 26
        ORDER BY id
    ) INTO v_new_ids;

    -- 获取老玩家 ID 列表 (player1-player25)
    SELECT ARRAY(
        SELECT id FROM player
        WHERE username LIKE 'player%'
          AND username ~ '^player\d+$'
          AND CAST(REGEXP_REPLACE(username, '\D', '', 'g') AS INT) <= 25
        ORDER BY id
    ) INTO v_old_ids;

    -- 随机建立好友关系（新玩家 <-> 老玩家）
    FOR v_i IN 1..v_max_count LOOP
        v_new_id := v_new_ids[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_new_ids, 1))::INT];
        v_old_id := v_old_ids[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_old_ids, 1))::INT];

        -- 幂等检查：好友关系已存在则跳过
        IF NOT EXISTS (
            SELECT 1 FROM friendship
            WHERE player_id = v_new_id AND friend_id = v_old_id
        ) AND v_new_id IS DISTINCT FROM v_old_id THEN
            -- 插入双向好友关系
            INSERT INTO friendship(player_id, friend_id) VALUES
                (v_new_id, v_old_id),
                (v_old_id, v_new_id);
            v_count := v_count + 1;
        END IF;
    END LOOP;

    RAISE NOTICE '已插入 % 条双向好友关系', v_count;
END $$;

-- 回填好友计数
UPDATE player SET friend_count = (
    SELECT COUNT(*) FROM friendship f WHERE f.player_id = player.id
);

-- ============================================
-- 4. 添加好友请求（约 8 条待处理请求）
-- ============================================
DO $$
DECLARE
    v_new_ids   INT[];
    v_old_ids   INT[];
    v_i         INT;
    v_new_id    INT;
    v_old_id    INT;
    v_count     INT := 0;
    v_max_count INT := 8;
BEGIN
    -- 获取新玩家 ID 列表
    SELECT ARRAY(
        SELECT id FROM player
        WHERE username LIKE 'player%'
          AND username ~ '^player\d+$'
          AND CAST(REGEXP_REPLACE(username, '\D', '', 'g') AS INT) >= 26
        ORDER BY id
    ) INTO v_new_ids;

    -- 获取老玩家 ID 列表
    SELECT ARRAY(
        SELECT id FROM player
        WHERE username LIKE 'player%'
          AND username ~ '^player\d+$'
          AND CAST(REGEXP_REPLACE(username, '\D', '', 'g') AS INT) <= 25
        ORDER BY id
    ) INTO v_old_ids;

    -- 随机生成好友请求（新玩家 -> 老玩家）
    FOR v_i IN 1..v_max_count LOOP
        v_new_id := v_new_ids[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_new_ids, 1))::INT];
        v_old_id := v_old_ids[1 + FLOOR(RANDOM() * ARRAY_LENGTH(v_old_ids, 1))::INT];

        -- 幂等检查：请求已存在则跳过；也不能已经是好友
        IF NOT EXISTS (
            SELECT 1 FROM friend_request
            WHERE requester_id = v_new_id AND addressee_id = v_old_id
        ) AND NOT EXISTS (
            SELECT 1 FROM friendship
            WHERE player_id = v_new_id AND friend_id = v_old_id
        ) AND v_new_id IS DISTINCT FROM v_old_id THEN
            INSERT INTO friend_request(requester_id, addressee_id, status)
            VALUES (v_new_id, v_old_id, 'pending');
            v_count := v_count + 1;
        END IF;
    END LOOP;

    RAISE NOTICE '已插入 % 条好友请求', v_count;
END $$;

-- ============================================
-- 5. 刷新物化视图（需通过管理后台 API 触发）
-- ============================================
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_season_statistics;
-- 注意：arena_admin 用户可能无权直接刷新物化视图
-- 请登录后访问管理后台点击"刷新统计视图"按钮，或调用 POST /api/admin/refresh-stats

-- ============================================
-- 6. 验证查询
-- ============================================
SELECT 'players' AS table_name, COUNT(*) FROM player
UNION ALL SELECT 'season_ranks', COUNT(*) FROM player_season_rank
UNION ALL SELECT 'friendships', COUNT(*) FROM friendship
UNION ALL SELECT 'friend_requests', COUNT(*) FROM friend_request;
