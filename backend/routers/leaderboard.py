"""
排行榜路由：Redis 实时排行、PostgreSQL 赛季排行、PG→Redis 同步
"""
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import redis.asyncio as aioredis

from database import get_db
from dependencies import require_admin
from redis_client import get_redis

router = APIRouter()

ELO_KEY = "leaderboard:elo"


@router.get("/global", summary="全球实时排行榜")
async def global_leaderboard(
    top_n: int = 100,
    redis: aioredis.Redis = Depends(get_redis),
):
    """Redis Sorted Set 实时排行榜 Top N"""
    top = await redis.zrevrange(ELO_KEY, 0, top_n - 1, withscores=True)
    return {
        "leaderboard": [
            {"rank": i + 1, "player_id": int(pid), "elo": int(score)}
            for i, (pid, score) in enumerate(top)
        ]
    }


@router.get("/season/{season_id}", summary="赛季排行榜")
async def season_leaderboard(
    season_id: int,
    top_n: int = 100,
    db: AsyncSession = Depends(get_db),
):
    """PostgreSQL 赛季段位排行（窗口函数 RANK + LAG + LEAD）"""
    result = await db.execute(
        text("""
            SELECT p.nickname, psr.rank_points, rt.name AS rank_name,
                   psr.win_rate, psr.matches_played,
                   RANK() OVER (ORDER BY psr.rank_points DESC) AS rank_no,
                   psr.rank_points - LAG(psr.rank_points) OVER (
                       ORDER BY psr.rank_points DESC
                   ) AS gap_above,
                   LEAD(psr.rank_points) OVER (
                       ORDER BY psr.rank_points DESC
                   ) AS next_points
            FROM player_season_rank psr
            JOIN player p ON psr.player_id = p.id
            JOIN rank_tier rt ON psr.rank_tier_id = rt.id
            WHERE psr.season_id = :sid
            ORDER BY rank_no
            LIMIT :lim
        """),
        {"sid": season_id, "lim": top_n},
    )
    rows = result.fetchall()

    return {
        "season_id": season_id,
        "rankings": [
            {
                "rank": r.rank_no,
                "nickname": r.nickname,
                "rank_name": r.rank_name,
                "rank_points": r.rank_points,
                "win_rate": float(r.win_rate),
                "matches_played": r.matches_played,
                "gap_above": r.gap_above,
                "next_points": r.next_points,
            }
            for r in rows
        ],
    }


@router.post("/sync", summary="PG → Redis 同步排行榜")
async def sync_leaderboard(
    admin_id: int = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """将 PostgreSQL 玩家 ELO 数据同步到 Redis（Redis 重启后恢复）"""
    result = await db.execute(
        text("SELECT id, elo_rating FROM player ORDER BY elo_rating DESC")
    )
    rows = result.fetchall()

    if rows:
        pipe = redis.pipeline()
        pipe.delete(ELO_KEY)
        for row in rows:
            pipe.zadd(ELO_KEY, {str(row.id): row.elo_rating})
        await pipe.execute()

    return {"message": f"同步完成，共 {len(rows)} 名玩家"}
