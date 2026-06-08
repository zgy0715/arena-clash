"""
对战系统路由：创建对战、结算、查询列表
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import get_current_user

router = APIRouter()


class CreateMatchRequest(BaseModel):
    season_id: int = Field(gt=0, description="赛季ID")
    map_name: str = Field(default="召唤师峡谷")
    match_mode: str = Field(default="ranked", pattern="^(ranked|casual|custom)$")


class SettleMatchRequest(BaseModel):
    winner_side: int = Field(ge=1, le=2, description="获胜方：1=蓝方，2=红方")


@router.post("/create", summary="创建对战房间")
async def create_match(
    body: CreateMatchRequest,
    db: AsyncSession = Depends(get_db),
):
    """创建新的对战，自动生成 match_code"""
    result = await db.execute(
        text("""
            INSERT INTO match_record(season_id, map_name, match_mode, status)
            VALUES(:sid, :m, :md, 'pending')
            RETURNING id, match_code
        """),
        {"sid": body.season_id, "m": body.map_name, "md": body.match_mode},
    )
    row = result.fetchone()
    await db.commit()

    return {"id": row.id, "match_code": row.match_code, "message": "对战创建成功"}


@router.post("/{match_id}/start", summary="开始对战")
async def start_match(
    match_id: int,
    db: AsyncSession = Depends(get_db),
):
    """将对战状态改为 in_progress（触发器会同步玩家状态）"""
    await db.execute(
        text("UPDATE match_record SET status = 'in_progress', started_at = NOW() WHERE id = :m"),
        {"m": match_id},
    )
    await db.commit()
    return {"message": "对战已开始"}


@router.post("/{match_id}/settle", summary="对战结算")
async def settle_match(
    match_id: int,
    body: SettleMatchRequest,
    db: AsyncSession = Depends(get_db),
):
    """调用存储过程 fn_settle_match 进行对战结算"""
    result = await db.execute(
        text("SELECT * FROM fn_settle_match(:m, :w)"),
        {"m": match_id, "w": body.winner_side},
    )
    row = result.fetchone()
    await db.commit()

    return {"success": row.success, "message": row.message}


@router.get("", summary="对战列表")
async def list_matches(
    season_id: int | None = None,
    status: str | None = None,
    limit: int = 20,
    db: AsyncSession = Depends(get_db),
):
    """查询对战列表，支持按赛季和状态筛选"""
    query = """
        SELECT mr.id, mr.match_code, mr.map_name, mr.match_mode,
               mr.status, mr.duration_sec, mr.winner_side,
               mr.started_at, mr.ended_at, mr.created_at
        FROM match_record mr WHERE 1=1
    """
    params = {}
    if season_id:
        query += " AND mr.season_id = :sid"
        params["sid"] = season_id
    if status:
        query += " AND mr.status = :st"
        params["st"] = status
    query += " ORDER BY mr.created_at DESC LIMIT :lim"
    params["lim"] = limit

    result = await db.execute(text(query), params)
    rows = result.fetchall()

    return {
        "matches": [
            {
                "id": r.id,
                "match_code": r.match_code,
                "map_name": r.map_name,
                "match_mode": r.match_mode,
                "status": r.status,
                "duration_sec": r.duration_sec,
                "winner_side": r.winner_side,
                "started_at": str(r.started_at) if r.started_at else None,
                "ended_at": str(r.ended_at) if r.ended_at else None,
            }
            for r in rows
        ]
    }
