"""
Arena Clash Redis 连接管理
复用 main.py lifespan 中创建的全局 Redis 连接
"""
import redis.asyncio as aioredis

# 全局 Redis 客户端，由 main.py lifespan 初始化
redis_client: aioredis.Redis | None = None


async def get_redis():
    """获取 Redis 连接（依赖注入用，复用全局实例）"""
    if redis_client is None:
        raise RuntimeError("Redis 未初始化，请检查服务是否正常启动")
    yield redis_client
