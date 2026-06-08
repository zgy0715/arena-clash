"""
认证路由：注册、登录
JWT Token 签发
"""
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from jose import jwt
from passlib.hash import bcrypt

from config import settings
from database import get_db

router = APIRouter()


class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50, description="用户名")
    password: str = Field(min_length=6, max_length=100, description="密码")
    nickname: str = Field(min_length=1, max_length=50, description="昵称")


class LoginRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    password: str = Field(min_length=6, max_length=100)


@router.post("/register", summary="用户注册")
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """注册新用户，初始金币1000，ELO 1500"""
    # 检查重名
    result = await db.execute(
        text("SELECT id FROM player WHERE username = :u"),
        {"u": body.username},
    )
    if result.fetchone():
        raise HTTPException(status_code=400, detail="用户名已存在")

    password_hash = bcrypt.hash(body.password)
    result = await db.execute(
        text("""
            INSERT INTO player(username, password_hash, nickname)
            VALUES(:u, :p, :n) RETURNING id
        """),
        {"u": body.username, "p": password_hash, "n": body.nickname},
    )
    player_id = result.fetchone()[0]
    await db.commit()

    return {"id": player_id, "message": "注册成功"}


@router.post("/login", summary="用户登录")
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    """登录成功返回 JWT Token"""
    result = await db.execute(
        text("SELECT id, password_hash, nickname, elo_rating FROM player WHERE username = :u"),
        {"u": body.username},
    )
    row = result.fetchone()
    if not row or not bcrypt.verify(body.password, row.password_hash):
        raise HTTPException(status_code=401, detail="用户名或密码错误")

    # 签发 JWT
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(row.id), "exp": expire}
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm="HS256")

    # 更新登录时间
    await db.execute(
        text("UPDATE player SET last_login = NOW() WHERE id = :i"),
        {"i": row.id},
    )
    await db.commit()

    return {
        "access_token": token,
        "token_type": "bearer",
        "player": {
            "id": row.id,
            "nickname": row.nickname,
            "elo_rating": row.elo_rating,
        },
    }
