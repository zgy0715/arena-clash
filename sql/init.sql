-- ============================================
-- Arena Clash 数据库初始化脚本
-- PostgreSQL 16
-- 包含：扩展、表结构、索引、物化视图
-- ============================================

-- 0. 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. 通用触发器函数：updated_at 自动更新
-- ============================================
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 2. 赛季表 (season)
-- ============================================
CREATE TABLE season (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    start_date  TIMESTAMP NOT NULL,
    end_date    TIMESTAMP,
    status      VARCHAR(20) DEFAULT 'active'
                CHECK (status IN ('active', 'completed', 'archived')),
    created_at  TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 3. 段位表 (rank_tier)
-- ============================================
CREATE TABLE rank_tier (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,
    tier_level  INT NOT NULL UNIQUE,
    icon_url    VARCHAR(500),
    min_points  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 4. 玩家表 (player)
-- ============================================
CREATE TABLE player (
    id              SERIAL PRIMARY KEY,
    username        VARCHAR(50) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    nickname        VARCHAR(50) NOT NULL,
    avatar_url      VARCHAR(500),
    email           VARCHAR(100),
    elo_rating      INT NOT NULL DEFAULT 1500,
    level           INT NOT NULL DEFAULT 1,
    experience      INT NOT NULL DEFAULT 0,
    gold            INT NOT NULL DEFAULT 1000,
    total_matches   INT NOT NULL DEFAULT 0,
    wins            INT NOT NULL DEFAULT 0,
    losses          INT NOT NULL DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'online'
                    CHECK (status IN ('online', 'offline', 'in_match', 'banned')),
    last_login      TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER trg_player_updated
    BEFORE UPDATE ON player
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================
-- 5. 英雄表 (hero)
-- ============================================
CREATE TABLE hero (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    title           VARCHAR(100),
    role            VARCHAR(30) NOT NULL
                    CHECK (role IN ('fighter','mage','assassin','marksman','support','tank')),
    price_gold      INT NOT NULL DEFAULT 4500,
    price_rp        INT NOT NULL DEFAULT 0,
    difficulty      INT NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 10),
    description     TEXT,
    is_free         BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER trg_hero_updated
    BEFORE UPDATE ON hero
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================
-- 6. 对战记录表 (match_record)
-- ============================================
CREATE TABLE match_record (
    id              SERIAL PRIMARY KEY,
    match_code      VARCHAR(20) UNIQUE NOT NULL,
    season_id       INT NOT NULL REFERENCES season(id),
    map_name        VARCHAR(100) DEFAULT '召唤师峡谷',
    match_mode      VARCHAR(30) DEFAULT 'ranked'
                    CHECK (match_mode IN ('ranked','casual','custom')),
    duration_sec    INT CHECK (duration_sec IS NULL OR duration_sec > 0),
    winner_side     INT CHECK (winner_side IS NULL OR winner_side IN (1, 2)),
    status          VARCHAR(20) DEFAULT 'pending'
                    CHECK (status IN ('pending','in_progress','completed','cancelled')),
    started_at      TIMESTAMP,
    ended_at        TIMESTAMP,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW(),

    CHECK (started_at IS NULL OR ended_at IS NULL OR started_at <= ended_at)
);

CREATE TRIGGER trg_match_updated
    BEFORE UPDATE ON match_record
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================
-- 7. 对战详情表 (match_detail)
-- ============================================
CREATE TABLE match_detail (
    id              SERIAL PRIMARY KEY,
    match_id        INT NOT NULL REFERENCES match_record(id),
    player_id       INT NOT NULL REFERENCES player(id),
    hero_id         INT NOT NULL REFERENCES hero(id),
    team_side       INT NOT NULL CHECK (team_side IN (1, 2)),
    kills           INT NOT NULL DEFAULT 0 CHECK (kills >= 0),
    deaths          INT NOT NULL DEFAULT 0 CHECK (deaths >= 0),
    assists         INT NOT NULL DEFAULT 0 CHECK (assists >= 0),
    damage_dealt    INT NOT NULL DEFAULT 0 CHECK (damage_dealt >= 0),
    damage_taken    INT NOT NULL DEFAULT 0 CHECK (damage_taken >= 0),
    gold_earned     INT NOT NULL DEFAULT 0 CHECK (gold_earned >= 0),
    exp_earned      INT NOT NULL DEFAULT 0 CHECK (exp_earned >= 0),
    elo_change      INT NOT NULL DEFAULT 0,
    is_mvp          BOOLEAN DEFAULT FALSE,

    -- 生成列：KDA 自动计算
    kda             DECIMAL(5,2) GENERATED ALWAYS AS (
                        CASE WHEN deaths = 0 THEN (kills + assists) * 1.0
                             ELSE (kills + assists)::DECIMAL / deaths END
                    ) STORED,

    extra_data      JSONB DEFAULT '{}',
    created_at      TIMESTAMP DEFAULT NOW(),

    UNIQUE(match_id, player_id)
);

-- ============================================
-- 8. 玩家赛季段位表 (player_season_rank)
-- ============================================
CREATE TABLE player_season_rank (
    id              SERIAL PRIMARY KEY,
    player_id       INT NOT NULL REFERENCES player(id),
    season_id       INT NOT NULL REFERENCES season(id),
    rank_tier_id    INT NOT NULL REFERENCES rank_tier(id),
    rank_points     INT NOT NULL DEFAULT 0,
    peak_points     INT NOT NULL DEFAULT 0,
    matches_played  INT NOT NULL DEFAULT 0 CHECK (matches_played >= 0),
    wins            INT NOT NULL DEFAULT 0 CHECK (wins >= 0),
    losses          INT NOT NULL DEFAULT 0 CHECK (losses >= 0),

    -- 生成列：胜率自动计算
    win_rate        DECIMAL(5,2) GENERATED ALWAYS AS (
                        CASE WHEN matches_played = 0 THEN 0
                             ELSE (wins::DECIMAL / matches_played) * 100 END
                    ) STORED,

    created_at      TIMESTAMP DEFAULT NOW(),

    UNIQUE(player_id, season_id),
    CHECK (wins + losses = matches_played)
);

-- ============================================
-- 9. 虚拟商城商品表 (shop_item)
-- ============================================
CREATE TABLE shop_item (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    item_type       VARCHAR(30) NOT NULL
                    CHECK (item_type IN ('hero','skin','emote','frame')),
    hero_id         INT REFERENCES hero(id),
    price_gold      INT NOT NULL DEFAULT 0,
    price_rp        INT NOT NULL DEFAULT 0,
    stock           INT NOT NULL DEFAULT -1,
    is_limited      BOOLEAN DEFAULT FALSE,
    is_on_sale      BOOLEAN DEFAULT TRUE,
    start_time      TIMESTAMP,
    end_time        TIMESTAMP,
    description     TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),

    CHECK (price_gold > 0 OR price_rp > 0),
    CHECK (is_limited = FALSE OR stock >= 0),
    CHECK (start_time IS NULL OR end_time IS NULL OR start_time < end_time)
);

-- ============================================
-- 10. 购买记录表 (purchase_record)
-- ============================================
CREATE TABLE purchase_record (
    id              SERIAL PRIMARY KEY,
    player_id       INT NOT NULL REFERENCES player(id),
    item_id         INT NOT NULL REFERENCES shop_item(id),
    currency_type   VARCHAR(10) NOT NULL CHECK (currency_type IN ('gold','rp')),
    price_paid      INT NOT NULL CHECK (price_paid > 0),
    created_at      TIMESTAMP DEFAULT NOW(),

    UNIQUE(player_id, item_id)
);

-- ============================================
-- 11. 操作日志表（审计）(audit_log)
-- ============================================
CREATE TABLE audit_log (
    id              SERIAL PRIMARY KEY,
    player_id       INT,
    action          VARCHAR(50) NOT NULL,
    detail          JSONB DEFAULT '{}',
    ip_address      INET,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 索引策略
-- ============================================

-- 玩家索引
CREATE INDEX idx_player_username   ON player(username);
CREATE INDEX idx_player_elo        ON player(elo_rating DESC);
CREATE INDEX idx_player_status     ON player(status);

-- 对战索引
CREATE INDEX idx_match_season      ON match_record(season_id, status);
CREATE INDEX idx_match_created     ON match_record(created_at DESC);
CREATE INDEX idx_match_code        ON match_record(match_code);

-- 对战详情索引
CREATE INDEX idx_detail_match      ON match_detail(match_id);
CREATE INDEX idx_detail_player     ON match_detail(player_id, created_at DESC);
CREATE INDEX idx_detail_hero       ON match_detail(hero_id);
CREATE INDEX idx_detail_mvp        ON match_detail(is_mvp) WHERE is_mvp = TRUE;
CREATE INDEX idx_detail_extra      ON match_detail USING GIN (extra_data);

-- 赛季段位索引
CREATE INDEX idx_psr_season        ON player_season_rank(season_id, rank_points DESC);

-- 商城索引
CREATE INDEX idx_shop_type         ON shop_item(item_type, is_on_sale);
CREATE INDEX idx_shop_limited      ON shop_item(is_limited, stock)
    WHERE is_limited = TRUE AND stock >= 0;

-- 购买记录索引
CREATE INDEX idx_purchase_player   ON purchase_record(player_id, created_at DESC);

-- 审计日志索引
CREATE INDEX idx_audit_action      ON audit_log(action, created_at DESC);
CREATE INDEX idx_audit_detail      ON audit_log USING GIN (detail);

-- ============================================
-- 物化视图：赛季英雄统计
-- ============================================
CREATE MATERIALIZED VIEW mv_season_statistics AS
SELECT
    mr.season_id,
    h.id        AS hero_id,
    h.name      AS hero_name,
    h.role,
    COUNT(*)    AS picks,
    SUM(CASE WHEN md.team_side = mr.winner_side THEN 1 ELSE 0 END) AS wins,
    ROUND(
        SUM(CASE WHEN md.team_side = mr.winner_side THEN 1 ELSE 0 END)::DECIMAL
        / NULLIF(COUNT(*), 0) * 100, 1
    ) AS win_rate,
    ROUND(AVG(md.kda), 2) AS avg_kda,
    SUM(CASE WHEN md.is_mvp THEN 1 ELSE 0 END) AS mvp_count
FROM match_detail md
    JOIN match_record mr ON md.match_id = mr.id
    JOIN hero h ON md.hero_id = h.id
WHERE mr.status = 'completed'
GROUP BY mr.season_id, h.id, h.name, h.role;

CREATE UNIQUE INDEX idx_mv_season_hero ON mv_season_statistics (season_id, hero_id);
