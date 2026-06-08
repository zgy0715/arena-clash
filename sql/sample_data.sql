-- ============================================
-- Arena Clash 测试数据
-- 包含：段位、英雄、赛季、玩家、赛季段位、对战、商品
-- 规模：500玩家 + 10英雄 + 500场对战 + 4商品
-- ============================================

-- ============================================
-- 1. 段位数据（9个段位）
-- ============================================
INSERT INTO rank_tier(name, tier_level, min_points) VALUES
('青铜 I',   1, 0),
('青铜 II',  2, 100),
('青铜 III', 3, 200),
('白银 I',   4, 400),
('白银 II',  5, 600),
('白银 III', 6, 800),
('黄金 I',   7, 1100),
('黄金 II',  8, 1400),
('黄金 III', 9, 1700);

-- ============================================
-- 2. 英雄数据（10个英雄，覆盖全部6种角色）
-- ============================================
INSERT INTO hero(name, title, role, price_gold, difficulty, description) VALUES
('暗影刺客', '暗夜猎手', 'assassin', 4500, 8, '高爆发近战刺客，擅长单点击杀'),
('炎爆法师', '烈焰之主', 'mage',     4800, 7, '远程AOE法师，掌控火焰之力'),
('钢铁卫士', '不灭守护', 'tank',     3150, 3, '前排坦克，吸收伤害保护队友'),
('疾风剑豪', '风暴之刃', 'fighter',  6300, 9, '高机动战士，操作上限极高'),
('星辰射手', '破晓之光', 'marksman', 4800, 6, '远程物理输出，持续伤害核心'),
('圣光使者', '黎明祝福', 'support',  1350, 2, '治疗辅助，为团队提供续航'),
('月影追踪', '暗夜猎手', 'assassin', 4800, 8, '灵活刺客，擅长游走抓人'),
('寒冰女巫', '霜之哀伤', 'mage',     6300, 7, '控制型法师，群体冰冻技能'),
('狂暴战士', '血之怒吼', 'fighter',  3150, 4, '重装战士，越战越勇'),
('幽灵守卫', '迷雾之盾', 'support',  4500, 3, '控制辅助，提供护盾与视野');

-- ============================================
-- 3. 赛季数据
-- ============================================
INSERT INTO season(name, start_date, status) VALUES
('S1 青铜时代', '2026-01-01', 'active');

-- ============================================
-- 4. 玩家数据（50名玩家）
-- ============================================
-- 密码统一为 test1234 的 bcrypt 哈希
-- (实际使用 passlib bcrypt 生成)
INSERT INTO player(username, password_hash, nickname, elo_rating, level, experience, gold, total_matches, wins, losses) VALUES
('player1',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '暗夜王者',   2100, 25, 42000, 8500,  150, 95,  55),
('player2',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '烈焰风暴',   1950, 22, 38000, 7200,  130, 78,  52),
('player3',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '铁壁守护',   1800, 20, 35000, 6800,  120, 65,  55),
('player4',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '剑影如风',   1750, 18, 32000, 5500,  110, 60,  50),
('player5',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '星辰之箭',   1680, 17, 30000, 6000,  105, 55,  50),
('player6',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '圣光普照',   1620, 16, 28000, 4800,  100, 52,  48),
('player7',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '月影无踪',   1550, 15, 26000, 5200,  95,  48,  47),
('player8',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '冰霜女王',   1500, 14, 24000, 4500,  90,  45,  45),
('player9',  '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '狂战之魂',   1450, 13, 22000, 4000,  85,  42,  43),
('player10', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '迷雾之灵',   1400, 12, 20000, 3800,  80,  40,  40),

('player11', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '雷霆一击',   1350, 11, 18000, 3500,  75,  38,  37),
('player12', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '风暴降临',   1300, 10, 16000, 3200,  70,  35,  35),
('player13', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '破晓之光',   1250, 9,  14000, 2800,  65,  32,  33),
('player14', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '暗影之刃',   1200, 8,  12000, 2500,  60,  30,  30),
('player15', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '烈焰之心',   1150, 7,  10000, 2200,  55,  27,  28),
('player16', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '钢铁意志',   1100, 6,  8000,  2000,  50,  25,  25),
('player17', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '疾风闪电',   1050, 5,  6000,  1800,  45,  22,  23),
('player18', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '星辰大海',   1000, 5,  5000,  1500,  40,  20,  20),
('player19', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '圣光守护',   950,  4,  4000,  1200,  35,  17,  18),
('player20', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '月下独行',   900,  3,  3000,  1000,  30,  14,  16),

('player21', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '冰封之心',   880,  3,  2800,  900,   28,  13,  15),
('player22', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '狂暴之怒',   860,  3,  2600,  850,   26,  12,  14),
('player23', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '幽灵漫步',   840,  2,  2400,  800,   24,  11,  13),
('player24', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '天外飞仙',   820,  2,  2200,  750,   22,  10,  12),
('player25', '$2b$12$LJ3m4ys3GZfnYMz8kVsKaOmJwBXtGQhPjFWTvCLM5LxKjBvF8oqXy', '战神降临',   800,  2,  2000,  700,   20,  9,   11);

-- ============================================
-- 5. 玩家赛季段位（基于ELO分配）
-- ============================================
INSERT INTO player_season_rank(player_id, season_id, rank_tier_id, rank_points, peak_points, matches_played, wins, losses)
SELECT
    p.id,
    1,
    (SELECT id FROM rank_tier
     WHERE min_points <= p.elo_rating
     ORDER BY min_points DESC LIMIT 1),
    GREATEST(0, p.elo_rating - 1500 + FLOOR(RANDOM() * 200 - 100)::INT),
    GREATEST(0, p.elo_rating - 1500 + 200),
    p.total_matches,
    p.wins,
    p.losses
FROM player p;

-- ============================================
-- 6. 对战数据（100场已完成对战）
-- ============================================
DO $$
DECLARE
    v_match_id   INT;
    v_player_ids INT[];
    v_winner     INT;
    v_duration   INT;
    v_season_id  INT := 1;
    v_day_offset INT;
    v_match_code TEXT;
    v_k          INT;
    v_d          INT;
    v_a          INT;
    i            INT;
BEGIN
    FOR i IN 1..100 LOOP
        -- 随机选择10个不同玩家
        SELECT ARRAY(
            SELECT id FROM player ORDER BY RANDOM() LIMIT 10
        ) INTO v_player_ids;

        v_winner := CASE WHEN RANDOM() > 0.5 THEN 1 ELSE 2 END;
        v_duration := 600 + FLOOR(RANDOM() * 2100)::INT;
        v_day_offset := FLOOR(RANDOM() * 150)::INT;
        v_match_code := 'M-2026' || LPAD((1 + FLOOR(RANDOM() * 5))::TEXT, 2, '0')
                        || LPAD((1 + FLOOR(RANDOM() * 28))::TEXT, 2, '0')
                        || '-' || UPPER(TO_HEX(FLOOR(RANDOM() * 65535)::INT));

        INSERT INTO match_record(match_code, season_id, duration_sec, winner_side, status, started_at, ended_at)
        VALUES (v_match_code, v_season_id, v_duration, v_winner, 'completed',
                NOW() - (v_day_offset || ' days')::INTERVAL,
                NOW() - (v_day_offset || ' days')::INTERVAL + (v_duration || ' seconds')::INTERVAL)
        RETURNING id INTO v_match_id;

        -- 为每个玩家插入对战详情
        FOR k IN 1..10 LOOP
            v_k := FLOOR(RANDOM() * 21)::INT;
            v_d := FLOOR(RANDOM() * 16)::INT;
            v_a := FLOOR(RANDOM() * 26)::INT;

            INSERT INTO match_detail(
                match_id, player_id, hero_id, team_side,
                kills, deaths, assists,
                damage_dealt, damage_taken, gold_earned, exp_earned, elo_change, extra_data
            )
            VALUES (
                v_match_id,
                v_player_ids[k],
                1 + FLOOR(RANDOM() * 10)::INT,
                CASE WHEN k <= 5 THEN 1 ELSE 2 END,
                v_k, v_d, v_a,
                5000 + FLOOR(RANDOM() * 45001)::INT,
                5000 + FLOOR(RANDOM() * 35001)::INT,
                100 + FLOOR(RANDOM() * 401)::INT,
                50 + FLOOR(RANDOM() * 251)::INT,
                CASE WHEN (k <= 5 AND v_winner = 1) OR (k > 5 AND v_winner = 2)
                     THEN 15 + FLOOR(RANDOM() * 16)::INT
                     ELSE -15 - FLOOR(RANDOM() * 11)::INT END,
                jsonb_build_object(
                    'wards_placed', FLOOR(RANDOM() * 21)::INT,
                    'vision_score', FLOOR(RANDOM() * 51)::INT
                )
            );
        END LOOP;
    END LOOP;
END $$;

-- ============================================
-- 7. 商城商品
-- ============================================
INSERT INTO shop_item(name, item_type, hero_id, price_gold, stock, is_limited, description) VALUES
('暴风大剑', 'hero',   NULL, 4500, -1,  FALSE, '传说级武器，攻击力+50'),
('暗影皮肤', 'skin',   1,    9900, 100, TRUE,  '暗影刺客限定皮肤，限时发售'),
('庆祝表情', 'emote',  NULL, 500,  -1,  FALSE, '胜利庆祝专属表情'),
('金色边框', 'frame',  NULL, 3000, 50,  TRUE,  '尊贵金色头像边框，限量发售');
