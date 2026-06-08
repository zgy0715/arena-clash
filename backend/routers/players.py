"""
玩家路由：信息查询、战绩统计、资料更新
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import get_current_user

router = APIRouter()


@router.get("/{player_id}", summary="查询玩家信息")
async def get_player(player_id: int, db: AsyncSession = Depends(get_db)):
    """查询玩家基本信息、段位、赛季数据"""
    result = await db.execute(
        text("""
            SELECT p.id, p.username, p.nickname, p.elo_rating, p.level,
                   p.experience, p.gold, p.total_matches, p.wins, p.losses,
                   p.status, p.last_login, p.created_at, rt.name AS rank_name
            FROM player p
            LEFT JOIN player_season_rank psr ON p.id = psr.player_id
                AND psr.season_id = (SELECT id FROM season WHERE status = 'active' LIMIT 1)
            LEFT JOIN rank_tier rt ON psr.rank_tier_id = rt.id
            WHERE p.id = :pid
        """),
        {"pid": player_id},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="玩家不存在")

    return {
        "id": row.id,
        "username": row.username,
        "nickname": row.nickname,
        "elo_rating": row.elo_rating,
        "level": row.level,
        "experience": row.experience,
        "gold": row.gold,
        "total_matches": row.total_matches,
        "wins": row.wins,
        "losses": row.losses,
        "win_rate": round(row.wins / row.total_matches * 100, 1) if row.total_matches > 0 else 0,
        "status": row.status,
        "rank_name": row.rank_name,
        "last_login": str(row.last_login) if row.last_login else None,
        "created_at": str(row.created_at),
    }


@router.get("/{player_id}/stats", summary="查询玩家战绩统计")
async def get_player_stats(player_id: int, db: AsyncSession = Depends(get_db)):
    """查询玩家历史战绩统计（窗口函数演示）"""
    # 最近20场对战的滑动窗口统计
    result = await db.execute(
        text("""
            SELECT mr.match_code, md.kills, md.deaths, md.assists,
                   md.kda, md.elo_change,
                   CASE WHEN md.team_side = mr.winner_side THEN '胜' ELSE '负' END AS result,
                   h.name AS hero_name,
                   ROUND(AVG(md.kda) OVER (
                       ORDER BY mr.created_at ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
                   ), 2) AS rolling_5_kda,
                   SUM(md.elo_change) OVER (
                       ORDER BY mr.created_at
                   ) AS cumulative_elo
            FROM match_detail md
            JOIN match_record mr ON md.match_id = mr.id
            JOIN hero h ON md.hero_id = h.id
            WHERE md.player_id = :pid AND mr.status = 'completed'
            ORDER BY mr.created_at DESC
            LIMIT 20
        """),
        {"pid": player_id},
    )
    rows = result.fetchall()

    return {
        "player_id": player_id,
        "recent_matches": [
            {
                "match_code": r.match_code,
                "hero": r.hero_name,
                "kda": f"{r.kills}/{r.deaths}/{r.assists}",
                "kda_value": float(r.kda),
                "elo_change": r.elo_change,
                "result": r.result,
                "rolling_5_kda": float(r.rolling_5_kda) if r.rolling_5_kda else None,
                "cumulative_elo": r.cumulative_elo,
            }
            for r in rows
        ],
    }


@router.put("/{player_id}", summary="更新玩家资料")
async def update_player(
    player_id: int,
    nickname: str | None = None,
    current_user: int = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """更新自己的昵称（需认证）"""
    if player_id != current_user:
        raise HTTPException(status_code=403, detail="只能修改自己的资料")

    if nickname is not None:
        await db.execute(
            text("UPDATE player SET nickname = :n WHERE id = :i"),
            {"n": nickname, "i": player_id},
        )
        await db.commit()

    return {"message": "更新成功"}
