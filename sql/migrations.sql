-- ============================================
-- Arena Clash 增量迁移脚本（用于"已有数据库"，幂等可重复执行）
-- ============================================
-- 说明：
--   * 全新初始化无需本文件——init.sql / procedures.sql / triggers.sql / sample_data.sql
--     已内联全部新功能；执行 `docker compose down -v && docker compose up -d` 即可。
--   * 已有运行中的数据库（不想清库）：执行本文件一次即可完成所有结构/存储过程/触发器升级：
--       psql -U arena_admin -d arena_clash -f sql/migrations.sql
--   * OpenGauss 兼容性：本文件均为标准 SQL / PL/pgSQL；如迁移到 OpenGauss，需复验
--     物化视图 REFRESH、GENERATED ALWAYS STORED 列、JSONB/GIN（详见实验报告"存在的问题"）。
-- ============================================

-- 1) 新增列 ----------------------------------------------------------------
ALTER TABLE player ADD COLUMN IF NOT EXISTS is_admin     BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE player ADD COLUMN IF NOT EXISTS friend_count INT     NOT NULL DEFAULT 0;
ALTER TABLE hero   ADD COLUMN IF NOT EXISTS is_active    BOOLEAN NOT NULL DEFAULT TRUE;

-- 2) 外键级联策略（先删后建，幂等）----------------------------------------
ALTER TABLE match_detail DROP CONSTRAINT IF EXISTS match_detail_match_id_fkey;
ALTER TABLE match_detail ADD  CONSTRAINT match_detail_match_id_fkey
    FOREIGN KEY (match_id) REFERENCES match_record(id) ON DELETE CASCADE;

ALTER TABLE match_detail DROP CONSTRAINT IF EXISTS match_detail_player_id_fkey;
ALTER TABLE match_detail ADD  CONSTRAINT match_detail_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE;

ALTER TABLE match_detail DROP CONSTRAINT IF EXISTS match_detail_hero_id_fkey;
ALTER TABLE match_detail ADD  CONSTRAINT match_detail_hero_id_fkey
    FOREIGN KEY (hero_id) REFERENCES hero(id) ON DELETE RESTRICT;   -- 英雄软删，硬删被拦截

ALTER TABLE player_season_rank DROP CONSTRAINT IF EXISTS player_season_rank_player_id_fkey;
ALTER TABLE player_season_rank ADD  CONSTRAINT player_season_rank_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE;

ALTER TABLE shop_item DROP CONSTRAINT IF EXISTS shop_item_hero_id_fkey;
ALTER TABLE shop_item ADD  CONSTRAINT shop_item_hero_id_fkey
    FOREIGN KEY (hero_id) REFERENCES hero(id) ON DELETE SET NULL;

ALTER TABLE purchase_record DROP CONSTRAINT IF EXISTS purchase_record_player_id_fkey;
ALTER TABLE purchase_record ADD  CONSTRAINT purchase_record_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE CASCADE;

ALTER TABLE purchase_record DROP CONSTRAINT IF EXISTS purchase_record_item_id_fkey;
ALTER TABLE purchase_record ADD  CONSTRAINT purchase_record_item_id_fkey
    FOREIGN KEY (item_id) REFERENCES shop_item(id) ON DELETE CASCADE;

ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS audit_log_player_id_fkey;
ALTER TABLE audit_log ADD  CONSTRAINT audit_log_player_id_fkey
    FOREIGN KEY (player_id) REFERENCES player(id) ON DELETE SET NULL;

-- 3) 社交表 ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS friend_request (
    id              SERIAL PRIMARY KEY,
    requester_id    INT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    addressee_id    INT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at      TIMESTAMP DEFAULT NOW(),
    responded_at    TIMESTAMP,
    CHECK (requester_id <> addressee_id),
    UNIQUE (requester_id, addressee_id)
);

CREATE TABLE IF NOT EXISTS friendship (
    id              SERIAL PRIMARY KEY,
    player_id       INT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    friend_id       INT NOT NULL REFERENCES player(id) ON DELETE CASCADE,
    created_at      TIMESTAMP DEFAULT NOW(),
    CHECK (player_id <> friend_id),
    UNIQUE (player_id, friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_request_addressee ON friend_request(addressee_id, status);
CREATE INDEX IF NOT EXISTS idx_friendship_player        ON friendship(player_id);

-- 4) 审计统计视图 ----------------------------------------------------------
CREATE OR REPLACE VIEW v_audit_action_stats AS
SELECT action,
       COUNT(*)                                                        AS cnt,
       MAX(created_at)                                                 AS last_at,
       COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days')  AS last_7d
FROM audit_log
GROUP BY action;

-- 5) 新存储过程（CREATE OR REPLACE，可安全重跑）---------------------------
CREATE OR REPLACE FUNCTION fn_delete_player_cascade(
    p_admin_id  INT,
    p_target_id INT
) RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_target        player%ROWTYPE;
    v_detail_cnt    INT;
    v_rank_cnt      INT;
    v_purchase_cnt  INT;
BEGIN
    SELECT * INTO v_target FROM player WHERE id = p_target_id FOR UPDATE;
    IF v_target IS NULL THEN
        RETURN QUERY SELECT FALSE, '玩家不存在'::TEXT; RETURN;
    END IF;
    IF v_target.is_admin THEN
        RETURN QUERY SELECT FALSE, '不能删除管理员账号'::TEXT; RETURN;
    END IF;

    SELECT COUNT(*) INTO v_detail_cnt   FROM match_detail       WHERE player_id = p_target_id;
    SELECT COUNT(*) INTO v_rank_cnt     FROM player_season_rank WHERE player_id = p_target_id;
    SELECT COUNT(*) INTO v_purchase_cnt FROM purchase_record    WHERE player_id = p_target_id;

    INSERT INTO audit_log(player_id, action, detail)
    VALUES (p_admin_id, 'player_delete_cascade', jsonb_build_object(
        'admin_id', p_admin_id, 'target_id', p_target_id,
        'target_nickname', v_target.nickname,
        'cascade_match_detail', v_detail_cnt,
        'cascade_season_rank', v_rank_cnt,
        'cascade_purchase', v_purchase_cnt));

    DELETE FROM player WHERE id = p_target_id;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_season_statistics;

    RETURN QUERY SELECT TRUE,
        FORMAT('已删除玩家「%s」，级联清理 对战详情%s条 / 赛季段位%s条 / 购买记录%s条',
               v_target.nickname, v_detail_cnt, v_rank_cnt, v_purchase_cnt)::TEXT;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_accept_friend_request(
    p_request_id INT
) RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_req friend_request%ROWTYPE;
BEGIN
    SELECT * INTO v_req FROM friend_request WHERE id = p_request_id FOR UPDATE;
    IF v_req IS NULL THEN
        RETURN QUERY SELECT FALSE, '好友请求不存在'::TEXT; RETURN;
    END IF;
    IF v_req.status <> 'pending' THEN
        RETURN QUERY SELECT FALSE, '该请求已处理过'::TEXT; RETURN;
    END IF;

    UPDATE friend_request SET status = 'accepted', responded_at = NOW() WHERE id = p_request_id;

    INSERT INTO friendship(player_id, friend_id)
    VALUES (v_req.requester_id, v_req.addressee_id),
           (v_req.addressee_id, v_req.requester_id)
    ON CONFLICT (player_id, friend_id) DO NOTHING;

    INSERT INTO audit_log(player_id, action, detail)
    VALUES (v_req.addressee_id, 'friend_accept', jsonb_build_object(
        'request_id', p_request_id, 'requester_id', v_req.requester_id,
        'addressee_id', v_req.addressee_id));

    RETURN QUERY SELECT TRUE, '已添加为好友'::TEXT;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_create_match_with_players(
    p_season_id INT, p_map TEXT, p_mode TEXT, p_players JSONB
) RETURNS TABLE(out_match_id INT, out_match_code VARCHAR) AS $$
DECLARE
    v_match_id   INT;
    v_match_code VARCHAR(20);
    v_p          JSONB;
BEGIN
    INSERT INTO match_record(season_id, map_name, match_mode, status)
    VALUES (p_season_id, COALESCE(p_map, '召唤师峡谷'), COALESCE(p_mode, 'ranked'), 'pending')
    RETURNING id, match_code INTO v_match_id, v_match_code;

    FOR v_p IN SELECT * FROM jsonb_array_elements(p_players)
    LOOP
        INSERT INTO match_detail(match_id, player_id, hero_id, team_side)
        VALUES (v_match_id, (v_p->>'player_id')::INT, (v_p->>'hero_id')::INT, (v_p->>'team_side')::INT);
    END LOOP;

    RETURN QUERY SELECT v_match_id, v_match_code;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_soft_delete_hero(
    p_hero_id INT
) RETURNS TABLE(success BOOLEAN, message TEXT) AS $$
DECLARE
    v_name TEXT;
BEGIN
    SELECT name INTO v_name FROM hero WHERE id = p_hero_id;
    IF v_name IS NULL THEN
        RETURN QUERY SELECT FALSE, '英雄不存在'::TEXT; RETURN;
    END IF;
    UPDATE hero SET is_active = FALSE WHERE id = p_hero_id;
    UPDATE shop_item SET hero_id = NULL WHERE hero_id = p_hero_id;
    INSERT INTO audit_log(action, detail)
    VALUES ('hero_soft_delete', jsonb_build_object('hero_id', p_hero_id, 'name', v_name));
    RETURN QUERY SELECT TRUE, FORMAT('英雄「%s」已下架（软删除）', v_name)::TEXT;
END;
$$ LANGUAGE plpgsql;

-- 6) 新触发器（DROP IF EXISTS + CREATE，可安全重跑）-----------------------
CREATE OR REPLACE FUNCTION fn_trigger_audit_player_delete()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(action, detail)
    VALUES ('player_deleted_trigger', jsonb_build_object(
        'id', OLD.id, 'username', OLD.username,
        'nickname', OLD.nickname, 'elo_rating', OLD.elo_rating));
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_player_delete ON player;
CREATE TRIGGER trg_audit_player_delete
    AFTER DELETE ON player
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_audit_player_delete();

CREATE OR REPLACE FUNCTION fn_trigger_friend_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE player SET friend_count = friend_count + 1 WHERE id = NEW.player_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE player SET friend_count = GREATEST(0, friend_count - 1) WHERE id = OLD.player_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_friendship_count ON friendship;
CREATE TRIGGER trg_friendship_count
    AFTER INSERT OR DELETE ON friendship
    FOR EACH ROW EXECUTE FUNCTION fn_trigger_friend_count();

-- 7) 设管理员（按需修改用户名）--------------------------------------------
UPDATE player SET is_admin = TRUE WHERE username = 'player1';
