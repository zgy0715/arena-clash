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
