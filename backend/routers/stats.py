"""
数据统计路由：数据大屏、段位分布、英雄统计、趋势分析
"""
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db

router = APIRouter()


@router.get("/overview", summary="数据总览")
async def stats_overview(db: AsyncSession = Depends(get_db)):
    """平台核心数据概览"""
    result = await db.execute(
        text("""
            SELECT
                (SELECT COUNT(*) FROM player) AS total_players,
                (SELECT COUNT(*) FROM match_record WHERE status = 'completed') AS total_matches,
                (SELECT COUNT(*) FROM hero) AS total_heroes,
                (SELECT COUNT(*) FROM shop_item WHERE is_on_sale = TRUE) AS shop_items,
                (SELECT COALESCE(SUM(price_paid), 0) FROM purchase_record) AS total_revenue
        """)
    )
    row = result.fetchone()
    return {
        "total_players": row.total_players,
        "total_matches": row.total_matches,
        "total_heroes": row.total_heroes,
        "shop_items": row.shop_items,
        "total_revenue": row.total_revenue,
    }


@router.get("/tier-distribution", summary="段位分布（NTILE分桶）")
async def tier_distribution(db: AsyncSession = Depends(get_db)):
    """NTILE(4) 将玩家按段位分4档"""
    result = await db.execute(
        text("""
            SELECT
                CASE q
                    WHEN 1 THEN '顶级'
                    WHEN 2 THEN '高级'
                    WHEN 3 THEN '中级'
                    WHEN 4 THEN '新手'
                END AS tier_bucket,
                COUNT(*) AS player_count,
                ROUND(AVG(rank_points), 0) AS avg_points,
                MIN(rank_points) AS min_points,
                MAX(rank_points) AS max_points
            FROM (
                SELECT rank_points,
                       NTILE(4) OVER (ORDER BY rank_points DESC) AS q
                FROM player_season_rank
                WHERE season_id = (SELECT id FROM season WHERE status = 'active' LIMIT 1)
            ) sub
            GROUP BY q
            ORDER BY q
        """)
    )
    rows = result.fetchall()
    return {
        "distribution": [
            {
                "tier": r.tier_bucket,
                "player_count": r.player_count,
                "avg_points": int(r.avg_points),
                "min_points": r.min_points,
                "max_points": r.max_points,
            }
            for r in rows
        ]
    }


@router.get("/hero-stats", summary="英雄统计")
async def hero_stats(db: AsyncSession = Depends(get_db)):
    """查询每个英雄的出场次数、胜率、平均KDA"""
    result = await db.execute(
        text("""
            SELECT h.name, h.role, h.difficulty,
                   COUNT(*) AS total_picks,
                   SUM(CASE WHEN md.team_side = mr.winner_side THEN 1 ELSE 0 END) AS wins,
                   ROUND(AVG(md.kda), 2) AS avg_kda,
                   SUM(CASE WHEN md.is_mvp THEN 1 ELSE 0 END) AS mvp_count
            FROM match_detail md
            JOIN hero h ON md.hero_id = h.id
            JOIN match_record mr ON md.match_id = mr.id
            WHERE mr.status = 'completed'
            GROUP BY h.id, h.name, h.role, h.difficulty
            ORDER BY total_picks DESC
        """)
    )
    rows = result.fetchall()
    return {
        "heroes": [
            {
                "name": r.name,
                "role": r.role,
                "difficulty": r.difficulty,
                "total_picks": r.total_picks,
                "wins": r.wins,
                "win_rate": round(r.wins / r.total_picks * 100, 1) if r.total_picks > 0 else 0,
                "avg_kda": float(r.avg_kda),
                "mvp_count": r.mvp_count,
            }
            for r in rows
        ]
    }


@router.get("/match-trend", summary="对战趋势")
async def match_trend(days: int = 30, db: AsyncSession = Depends(get_db)):
    """最近N天每日对战趋势"""
    from datetime import datetime, timedelta, timezone
    start = datetime.now(timezone.utc) - timedelta(days=days)
    result = await db.execute(
        text("""
            SELECT DATE(created_at) AS match_date,
                   COUNT(*) AS match_count,
                   ROUND(AVG(duration_sec)::DECIMAL, 0) AS avg_duration
            FROM match_record
            WHERE created_at >= :start_date
              AND status = 'completed'
            GROUP BY DATE(created_at)
            ORDER BY match_date
        """),
        {"start_date": start},
    )
    rows = result.fetchall()
    return {
        "trend": [
            {
                "date": str(r.match_date),
                "match_count": r.match_count,
                "avg_duration_sec": int(r.avg_duration),
            }
            for r in rows
        ]
    }


@router.get("/mv-season", summary="物化视图：赛季英雄统计")
async def mv_season_stats(db: AsyncSession = Depends(get_db)):
    """从物化视图查询预计算的赛季英雄统计"""
    result = await db.execute(
        text("SELECT * FROM mv_season_statistics ORDER BY picks DESC LIMIT 20")
    )
    rows = result.fetchall()
    return {
        "season_hero_stats": [
            {
                "season_id": r.season_id,
                "hero_name": r.hero_name,
                "role": r.role,
                "picks": r.picks,
                "wins": r.wins,
                "win_rate": float(r.win_rate),
                "avg_kda": float(r.avg_kda),
                "mvp_count": r.mvp_count,
            }
            for r in rows
        ]
    }
