-- ============================================
-- Arena Clash 触发器
-- PostgreSQL 16
-- ============================================

-- ============================================
-- 触发器1：对战状态变化 → 玩家在线状态同步
-- 功能：
--   - pending → in_progress：参战玩家状态设为 in_match
--   - in_progress → completed/cancelled：参战玩家状态恢复为 online
-- ============================================
CREATE OR REPLACE FUNCTION fn_trigger_match_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- 对战开始：玩家设为 in_match
    IF NEW.status = 'in_progress' AND OLD.status = 'pending' THEN
        UPDATE player SET status = 'in_match'
        WHERE id IN (
            SELECT player_id FROM match_detail WHERE match_id = NEW.id
        )
        AND status != 'banned';
    END IF;

    -- 对战结束：玩家恢复 online
    IF NEW.status IN ('completed', 'cancelled') AND OLD.status = 'in_progress' THEN
        UPDATE player SET status = 'online'
        WHERE id IN (
            SELECT player_id FROM match_detail WHERE match_id = NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_match_status_change
    AFTER UPDATE OF status ON match_record
    FOR EACH ROW
    EXECUTE FUNCTION fn_trigger_match_status_change();


-- ============================================
-- 触发器2：自动填充对战编号
-- 功能：INSERT 时如果 match_code 为空，自动生成
-- ============================================
CREATE OR REPLACE FUNCTION fn_trigger_auto_match_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.match_code IS NULL OR NEW.match_code = '' THEN
        NEW.match_code := fn_generate_match_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_match_code
    BEFORE INSERT ON match_record
    FOR EACH ROW
    EXECUTE FUNCTION fn_trigger_auto_match_code();


-- ============================================
-- 触发器3：玩家删除审计（AFTER DELETE ON player）—— 新增
-- 功能：任何方式删除玩家都写入审计日志，保证可追溯（此前无 DELETE 触发器）
-- ============================================
CREATE OR REPLACE FUNCTION fn_trigger_audit_player_delete()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(action, detail)
    VALUES ('player_deleted_trigger', jsonb_build_object(
        'id', OLD.id,
        'username', OLD.username,
        'nickname', OLD.nickname,
        'elo_rating', OLD.elo_rating
    ));
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_player_delete ON player;
CREATE TRIGGER trg_audit_player_delete
    AFTER DELETE ON player
    FOR EACH ROW
    EXECUTE FUNCTION fn_trigger_audit_player_delete();


-- ============================================
-- 触发器4：好友数维护（AFTER INSERT OR DELETE ON friendship）—— 新增
-- 功能：插入/删除好友关系时同步维护 player.friend_count 反范式计数
-- ============================================
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
    FOR EACH ROW
    EXECUTE FUNCTION fn_trigger_friend_count();
