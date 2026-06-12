"""
Arena Clash 共享限流器实例
由 main.py 设置到 app.state.limiter，路由端点导入装饰器使用
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

from config import settings

limiter = Limiter(key_func=get_remote_address, storage_uri=settings.REDIS_URL)
