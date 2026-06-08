"""
Arena Clash API 入口
FastAPI + SlowAPI 限流 + structlog 结构化日志 + Redis 生命周期管理
"""
import logging
from contextlib import asynccontextmanager

import redis.asyncio as aioredis
import structlog
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from config import settings
from database import engine
from routers import auth, players, matchmaking, matches, leaderboard, shop, stats
from routers.websocket import router as ws_router

# ============================================
# 结构化日志配置
# ============================================
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
)
logger = structlog.get_logger()

# ============================================
# 限流器配置（基于 Redis 分布式限流）
# ============================================
limiter = Limiter(key_func=get_remote_address, storage_uri=settings.REDIS_URL)


# ============================================
# 应用生命周期
# ============================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动：初始化 Redis
    global redis_client
    redis_client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    logger.info(
        "Arena Clash 服务启动",
        redis_url=settings.REDIS_URL.split("@")[-1],  # 隐藏密码部分
        env=settings.APP_ENV,
    )
    yield
    # 关闭：清理资源
    await redis_client.close()
    await engine.dispose()
    logger.info("Arena Clash 服务关闭")


# ============================================
# FastAPI 应用
# ============================================
app = FastAPI(
    title="Arena Clash API",
    version="1.0.0",
    description="多人在线竞技游戏数据管理平台",
    lifespan=lifespan,
)

# 限流器绑定
app.state.limiter = limiter
app.add_exception_handler(
    RateLimitExceeded,
    lambda request, exc: JSONResponse(
        status_code=429,
        content={"detail": "请求过于频繁，请稍后再试"},
    ),
)

# CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 开发环境允许所有来源
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================
# 健康检查
# ============================================
@app.get("/health", summary="健康检查")
async def health():
    return {"status": "ok", "service": "Arena Clash API"}


# ============================================
# 注册路由
# ============================================
app.include_router(auth.router, prefix="/api/auth", tags=["认证"])
app.include_router(players.router, prefix="/api/players", tags=["玩家"])
app.include_router(matchmaking.router, prefix="/api/matchmaking", tags=["匹配"])
app.include_router(matches.router, prefix="/api/matches", tags=["对战"])
app.include_router(leaderboard.router, prefix="/api/leaderboard", tags=["排行榜"])
app.include_router(shop.router, prefix="/api/shop", tags=["商城"])
app.include_router(stats.router, prefix="/api/stats", tags=["数据统计"])
app.include_router(ws_router, prefix="/ws", tags=["实时通信"])


# ============================================
# 启动入口
# ============================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=(settings.APP_ENV == "development"),
    )
