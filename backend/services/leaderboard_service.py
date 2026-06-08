"""
排行榜服务：Redis Sorted Set 实时排行 + PG 同步恢复
"""
import redis.asyncio as aioredis
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text


class LeaderboardService:
    """ELO 实时排行榜服务"""

    ELO_KEY = "leaderboard:elo"

    def __init__(self, redis: aioredis.Redis):
        self.redis = redis

    async def update_elo(self, player_id: int, elo: int) -> None:
        """更新玩家在 Redis 排行榜中的 ELO 分数"""
        await self.redis.zadd(self.ELO_KEY, {str(player_id): elo})

    async def get_rank(self, player_id: int) -> int:
        """获取玩家当前排名（1-indexed）"""
        rank = await self.redis.zrevrank(self.ELO_KEY, str(player_id))
        return rank + 1 if rank is not None else -1

    async def get_top_n(self, n: int = 100) -> list[dict]:
        """获取排行榜 Top N"""
        top = await self.redis.zrevrange(self.ELO_KEY, 0, n - 1, withscores=True)
        return [
            {"rank": i + 1, "player_id": int(pid), "elo": int(score)}
            for i, (pid, score) in enumerate(top)
        ]

    async def get_nearby(self, player_id: int, range_size: int = 5) -> list[dict]:
        """获取玩家附近排名（用于排行榜动画）"""
        rank = await self.redis.zrevrank(self.ELO_KEY, str(player_id))
        if rank is None:
            return []

        start = max(0, rank - range_size)
        end = rank + range_size
        nearby = await self.redis.zrevrange(
            self.ELO_KEY, start, end, withscores=True
        )
        return [
            {"rank": start + i + 1, "player_id": int(pid), "elo": int(score)}
            for i, (pid, score) in enumerate(nearby)
        ]

    async def sync_from_db(self, db: AsyncSession) -> int:
        """
        PostgreSQL → Redis 全量同步
        Redis 重启后调用此方法恢复排行榜数据
        使用 Pipeline 批量写入提高性能
        """
        result = await db.execute(
            text("SELECT id, elo_rating FROM player ORDER BY elo_rating DESC")
        )
        rows = result.fetchall()
        if rows:
            pipe = self.redis.pipeline()
            pipe.delete(self.ELO_KEY)
            for row in rows:
                pipe.zadd(self.ELO_KEY, {str(row.id): row.elo_rating})
            await pipe.execute()
        return len(rows)
