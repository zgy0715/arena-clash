"""
Arena Clash 配置管理
使用 pydantic-settings 从 .env 文件加载配置
"""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # 数据库
    DATABASE_URL: str = "postgresql+asyncpg://arena_admin:change_me@localhost:5432/arena_clash"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # JWT
    SECRET_KEY: str = "change_me"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # CORS（生产环境设置具体源）
    CORS_ORIGIN: str = "http://localhost:3000"

    # 应用
    APP_ENV: str = "development"
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = "../.env"
        env_file_encoding = "utf-8"
        extra = "ignore"


settings = Settings()
