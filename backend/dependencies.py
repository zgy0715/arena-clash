"""
Arena Clash 依赖注入
JWT 认证、用户身份验证
"""
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from config import settings
from database import get_db

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


async def get_current_user(token: str = Depends(oauth2_scheme)) -> int:
    """
    验证 JWT Token，返回当前用户 ID
    使用 HS256 算法，Token 中包含 sub 字段（用户ID）
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = int(payload["sub"])
        return user_id
    except (JWTError, ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证令牌",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def require_admin(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> int:
    """
    管理员门禁：验证 JWT，并回查数据库 player.is_admin
    回查而非只读 token，避免刚提权/降权后旧 token 仍然有效
    返回当前管理员用户 ID；非管理员抛 403
    """
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = int(payload["sub"])
    except (JWTError, ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证令牌",
            headers={"WWW-Authenticate": "Bearer"},
        )

    result = await db.execute(
        text("SELECT is_admin FROM player WHERE id = :i"),
        {"i": user_id},
    )
    row = result.fetchone()
    if not row or not row.is_admin:
        raise HTTPException(status_code=403, detail="需要管理员权限")
    return user_id
