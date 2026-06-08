"""
Arena Clash Redis 连接管理
支持密码认证、连接池
"""
import redis.asyncio as aioredis
from config import settings


async def get_redis():
    """获取 Redis 连接"""
    client = aioredis.from_url(
        settings.REDIS_URL,
        decode_responses=True,
        max_connections=20,
    )
    try:
        yield client
    finally:
        await client.close()
