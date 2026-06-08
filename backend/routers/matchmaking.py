"""
匹配系统路由：ELO 匹配队列、Redis Stream
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import redis.asyncio as aioredis

from database import get_db
from dependencies import get_current_user
from redis_client import get_redis

router = APIRouter()

MATCH_QUEUE_KEY = "matchmaking:queue"


@router.post("/join", summary="加入匹配队列")
async def join_matchmaking(
    current_user: int = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """玩家加入匹配队列，Redis Sorted Set 按 ELO 排序"""
    # 获取玩家 ELO 和状态
    result = await db.execute(
        text("SELECT elo_rating, status FROM player WHERE id = :i"),
        {"i": current_user},
    )
    row = result.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="玩家不存在")
    if row.status == "banned":
        raise HTTPException(status_code=403, detail="账号已被封禁")
    if row.status == "in_match":
        raise HTTPException(status_code=400, detail="正在对战中")

    # 加入匹配队列（Redis Sorted Set: score=ELO, member=player_id）
    await redis.zadd(MATCH_QUEUE_KEY, {str(current_user): row.elo_rating})
    queue_pos = await redis.zrank(MATCH_QUEUE_KEY, str(current_user))

    return {
        "message": "已加入匹配队列",
        "queue_position": queue_pos + 1 if queue_pos is not None else -1,
        "elo": row.elo_rating,
    }


@router.post("/leave", summary="离开匹配队列")
async def leave_matchmaking(
    current_user: int = Depends(get_current_user),
    redis: aioredis.Redis = Depends(get_redis),
):
    """玩家离开匹配队列"""
    await redis.zrem(MATCH_QUEUE_KEY, str(current_user))
    return {"message": "已离开匹配队列"}


@router.get("/status", summary="查询匹配状态")
async def matchmaking_status(
    current_user: int = Depends(get_current_user),
    redis: aioredis.Redis = Depends(get_redis),
):
    """查询当前匹配队列状态"""
    rank = await redis.zrank(MATCH_QUEUE_KEY, str(current_user))
    total = await redis.zcard(MATCH_QUEUE_KEY)

    return {
        "in_queue": rank is not None,
        "position": rank + 1 if rank is not None else None,
        "total_in_queue": total,
    }
