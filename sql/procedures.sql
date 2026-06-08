-- ============================================
-- Arena Clash 存储过程
-- PostgreSQL 16
-- ============================================

-- ============================================
-- 存储过程1：对战结算
-- 功能：结算一场对战，计算经验/金币/ELO变化，评选MVP
-- 特性：行级锁 FOR UPDATE、CHECK约束兼容、自动创建赛季记录
-- ============================================
CREATE OR REPLACE FUNCTION fn_settle_match(
    p_match_id    INT,
    p_winner_side INT
) RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_detail     RECORD;
    v_base_exp   INT := 200;
    v_base_gold  INT := 150;
    v_mvp_id     INT := -1;
    v_max_kda    DECIMAL := -1;
    v_match_rec  match_record%ROWTYPE;
    v_exp        INT;
    v_gold       INT;
    v_elo_change INT;
    v_is_winner  BOOLEAN;
BEGIN
    -- 锁定对战记录，防止并发修改
    SELECT * INTO v_match_rec FROM match_record WHERE id = p_match_id FOR UPDATE;

    IF v_match_rec IS NULL THEN
        RETURN QUERY SELECT FALSE, '对战记录不存在'::TEXT;
        RETURN;
    END IF;
    IF v_match_rec.status != 'in_progress' THEN
        RETURN QUERY SELECT FALSE, '对战状态不是 in_progress，无法结算'::TEXT;
        RETURN;
    END IF;
    IF p_winner_side NOT IN (1, 2) THEN
        RETURN QUERY SELECT FALSE, 'winner_side 必须是 1 或 2'::TEXT;
        RETURN;
    END IF;

    -- 更新对战状态
    UPDATE match_record
    SET winner_side = p_winner_side,
        status = 'completed',
        ended_at = NOW(),
        updated_at = NOW()
    WHERE id = p_match_id;

    -- 遍历每个参战玩家
    FOR v_detail IN
        SELECT md.id AS detail_id, md.player_id, md.team_side,
               md.kills, md.deaths, md.assists, md.kda,
               p.elo_rating
        FROM match_detail md
            JOIN player p ON md.player_id = p.id
        WHERE md.match_id = p_match_id
    LOOP
        -- 计算经验值
        v_exp := GREATEST(0, v_base_exp
            + CASE WHEN v_detail.team_side = p_winner_side THEN 100 ELSE 50 END
            + (v_detail.kills * 10 + v_detail.assists * 5 - v_detail.deaths * 8));

        -- 计算金币
        v_gold := v_base_gold
            + CASE WHEN v_detail.team_side = p_winner_side THEN 80 ELSE 30 END
            + v_detail.kills * 20;

        -- 计算 ELO 变化（ELO 评分机制）
        v_elo_change := CASE
            WHEN v_detail.team_side = p_winner_side THEN
                GREATEST(10, 25 - (v_detail.elo_rating - 1500) / 50)
            ELSE
                LEAST(-10, -25 + (1500 - v_detail.elo_rating) / 50)
        END;

        v_is_winner := (v_detail.team_side = p_winner_side);

        -- 更新 MVP 候选
        IF v_detail.kda > v_max_kda THEN
            v_max_kda := v_detail.kda;
            v_mvp_id := v_detail.detail_id;
        END IF;

        -- 更新对战详情
        UPDATE match_detail
        SET exp_earned = v_exp, gold_earned = v_gold, elo_change = v_elo_change
        WHERE id = v_detail.detail_id;

        -- 更新玩家属性
        UPDATE player
        SET experience = experience + v_exp,
            gold = gold + v_gold,
            elo_rating = elo_rating + v_elo_change,
            total_matches = total_matches + 1,
            wins = wins + CASE WHEN v_is_winner THEN 1 ELSE 0 END,
            losses = losses + CASE WHEN NOT v_is_winner THEN 1 ELSE 0 END
        WHERE id = v_detail.player_id;

        -- ⚠️ 关键：单条 UPDATE 同时更新 wins/losses/matches_played，满足 CHECK 约束
        UPDATE player_season_rank
        SET rank_points = rank_points + v_elo_change,
            peak_points = GREATEST(peak_points, rank_points + v_elo_change),
            matches_played = matches_played + 1,
            wins = wins + CASE WHEN v_is_winner THEN 1 ELSE 0 END,
            losses = losses + CASE WHEN NOT v_is_winner THEN 1 ELSE 0 END
        WHERE player_id = v_detail.player_id
          AND season_id = v_match_rec.season_id;

        -- 如果玩家在该赛季没有段位记录，自动创建
        IF NOT FOUND THEN
            INSERT INTO player_season_rank (
                player_id, season_id, rank_tier_id,
                rank_points, peak_points, matches_played, wins, losses
            )
            VALUES (
                v_detail.player_id, v_match_rec.season_id,
                (SELECT id FROM rank_tier ORDER BY tier_level ASC LIMIT 1),
                v_elo_change, GREATEST(0, v_elo_change), 1,
                CASE WHEN v_is_winner THEN 1 ELSE 0 END,
                CASE WHEN NOT v_is_winner THEN 1 ELSE 0 END
            );
        END IF;
    END LOOP;

    -- 评选 MVP
    IF v_mvp_id > 0 THEN
        UPDATE match_detail SET is_mvp = FALSE
        WHERE match_id = p_match_id AND id != v_mvp_id;
        UPDATE match_detail SET is_mvp = TRUE WHERE id = v_mvp_id;
    END IF;

    -- 审计日志
    INSERT INTO audit_log(action, detail)
    VALUES ('match_settle', jsonb_build_object(
        'match_id', p_match_id,
        'winner_side', p_winner_side,
        'mvp_detail_id', v_mvp_id,
        'mvp_kda', v_max_kda
    ));

    RETURN QUERY SELECT TRUE, '对战结算完成'::TEXT;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 存储过程2：商品购买
-- 功能：玩家购买商城商品，行级锁防超卖
-- 特性：FOR UPDATE 行级锁、多重校验、审计日志
-- ============================================
CREATE OR REPLACE FUNCTION fn_purchase_item(
    p_player_id INT,
    p_item_id   INT
) RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_player player%ROWTYPE;
    v_item   shop_item%ROWTYPE;
    v_owned  BOOLEAN;
BEGIN
    -- 锁定玩家行，防止并发扣款
    SELECT * INTO v_player FROM player WHERE id = p_player_id FOR UPDATE;
    IF v_player IS NULL THEN
        RETURN QUERY SELECT FALSE, '玩家不存在'::TEXT;
        RETURN;
    END IF;

    -- 锁定商品行，防止并发超卖
    SELECT * INTO v_item FROM shop_item WHERE id = p_item_id FOR UPDATE;
    IF v_item IS NULL THEN
        RETURN QUERY SELECT FALSE, '商品不存在'::TEXT;
        RETURN;
    END IF;
    IF NOT v_item.is_on_sale THEN
        RETURN QUERY SELECT FALSE, '商品已下架'::TEXT;
        RETURN;
    END IF;
    IF v_item.start_time IS NOT NULL AND NOW() < v_item.start_time THEN
        RETURN QUERY SELECT FALSE, '商品尚未开售'::TEXT;
        RETURN;
    END IF;
    IF v_item.end_time IS NOT NULL AND NOW() > v_item.end_time THEN
        RETURN QUERY SELECT FALSE, '商品已过期'::TEXT;
        RETURN;
    END IF;

    -- 检查是否已拥有
    SELECT EXISTS(
        SELECT 1 FROM purchase_record
        WHERE player_id = p_player_id AND item_id = p_item_id
    ) INTO v_owned;
    IF v_owned THEN
        RETURN QUERY SELECT FALSE, '您已拥有此商品，无需重复购买'::TEXT;
        RETURN;
    END IF;

    -- 检查库存
    IF v_item.is_limited AND v_item.stock <= 0 THEN
        RETURN QUERY SELECT FALSE, '商品已售罄'::TEXT;
        RETURN;
    END IF;

    -- 检查余额
    IF v_player.gold < v_item.price_gold THEN
        RETURN QUERY SELECT FALSE,
            FORMAT('金币不足！需要 %s，当前 %s', v_item.price_gold, v_player.gold)::TEXT;
        RETURN;
    END IF;

    -- 执行购买
    UPDATE player SET gold = gold - v_item.price_gold WHERE id = p_player_id;

    INSERT INTO purchase_record(player_id, item_id, currency_type, price_paid)
    VALUES (p_player_id, p_item_id, 'gold', v_item.price_gold);

    IF v_item.is_limited AND v_item.stock > 0 THEN
        UPDATE shop_item SET stock = stock - 1 WHERE id = p_item_id;
    END IF;

    -- 审计日志
    INSERT INTO audit_log(player_id, action, detail)
    VALUES (p_player_id, 'purchase', jsonb_build_object(
        'item_id', p_item_id,
        'item_name', v_item.name,
        'price', v_item.price_gold,
        'remaining_gold', v_player.gold - v_item.price_gold
    ));

    RETURN QUERY SELECT TRUE,
        FORMAT('购买成功！消耗 %s 金币，剩余 %s 金币',
               v_item.price_gold, v_player.gold - v_item.price_gold)::TEXT;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 存储过程3：赛季重置
-- 功能：归档旧赛季，创建新赛季，段位衰减后迁移玩家
-- 特性：CTE 批量处理、编号自动生成、JSONB 审计
-- ============================================
CREATE OR REPLACE FUNCTION fn_reset_season()
RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_old_id   INT;
    v_old_name TEXT;
    v_new_id   INT;
    v_new_name TEXT;
    v_next     INT;
    v_count    INT;
BEGIN
    -- 查找活跃赛季
    SELECT id, name INTO v_old_id, v_old_name
    FROM season WHERE status = 'active' LIMIT 1;

    IF v_old_id IS NULL THEN
        RETURN QUERY SELECT FALSE, '没有活跃赛季可以重置'::TEXT;
        RETURN;
    END IF;

    -- 归档旧赛季
    UPDATE season SET status = 'archived', end_date = NOW() WHERE id = v_old_id;

    -- 生成新赛季编号
    SELECT COALESCE(MAX(CAST(regexp_replace(name, '[^0-9]', '', 'g') AS INT)), 0) + 1
    INTO v_next FROM season;
    v_new_name := 'S' || v_next || ' 新赛季';

    -- 创建新赛季
    INSERT INTO season(name, start_date, status)
    VALUES (v_new_name, NOW(), 'active')
    RETURNING id INTO v_new_id;

    -- CTE: 段位衰减 200 分后批量迁移
    WITH old_ranks AS (
        SELECT
            player_id,
            GREATEST(0, rank_points - 200) AS new_points
        FROM player_season_rank
        WHERE season_id = v_old_id
    ),
    resolved AS (
        SELECT
            player_id,
            new_points,
            (SELECT id FROM rank_tier
             WHERE min_points <= new_points
             ORDER BY min_points DESC LIMIT 1) AS tid
        FROM old_ranks
    )
    INSERT INTO player_season_rank (
        player_id, season_id, rank_tier_id,
        rank_points, peak_points, matches_played, wins, losses
    )
    SELECT
        player_id, v_new_id,
        COALESCE(tid, (SELECT id FROM rank_tier ORDER BY tier_level ASC LIMIT 1)),
        new_points, new_points, 0, 0, 0
    FROM resolved;

    -- 统计迁移人数
    SELECT COUNT(*) INTO v_count
    FROM player_season_rank WHERE season_id = v_new_id;

    -- 审计日志
    INSERT INTO audit_log(action, detail)
    VALUES ('season_reset', jsonb_build_object(
        'old_season', v_old_name,
        'new_season', v_new_name,
        'players_migrated', v_count
    ));

    RETURN QUERY SELECT TRUE,
        FORMAT('赛季重置完成：%s → %s，迁移 %s 名玩家',
               v_old_name, v_new_name, v_count)::TEXT;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 存储过程4：生成对战编号
-- 功能：生成唯一对战编号 M-YYYYMMDD-XXXX
-- ============================================
CREATE OR REPLACE FUNCTION fn_generate_match_code()
RETURNS VARCHAR(20) AS $$
DECLARE
    v_code   VARCHAR(20);
    v_exists BOOLEAN;
BEGIN
    LOOP
        v_code := 'M-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-'
                  || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 4));
        SELECT EXISTS(
            SELECT 1 FROM match_record WHERE match_code = v_code
        ) INTO v_exists;
        EXIT WHEN NOT v_exists;
    END LOOP;
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;
