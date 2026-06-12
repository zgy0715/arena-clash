"""
对战系统路由：创建对战、结算、查询列表
"""
import json

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
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
    me: int = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """创建新的对战，自动生成 match_code（需登录）"""
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
    me: int = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """将对战状态改为 in_progress（触发器会同步玩家状态；需登录）"""
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
    me: int = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """调用存储过程 fn_settle_match 进行对战结算（需登录）"""
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
    status: str | None = Query(default=None, pattern="^(pending|in_progress|completed|cancelled)$"),
    limit: int = Query(default=20, le=200),
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


# ======================================================================
# 对战中心（模块2）新增端点
# ======================================================================
class MatchPlayer(BaseModel):
    player_id: int = Field(gt=0)
    hero_id: int = Field(gt=0)
    team_side: int = Field(ge=1, le=2, description="1=蓝方，2=红方")


class CreateFullMatchRequest(BaseModel):
    season_id: int = Field(gt=0)
    map_name: str = Field(default="召唤师峡谷")
    match_mode: str = Field(default="ranked", pattern="^(ranked|casual|custom)$")
    players: list[MatchPlayer]


@router.get("/lookups/heroes", summary="英雄下拉（建对战用，仅在役英雄）")
async def lookup_heroes(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        text("SELECT id, name, role FROM hero WHERE is_active = TRUE ORDER BY id")
    )
    return {"heroes": [dict(r._mapping) for r in result.fetchall()]}


@router.post("/create-full", summary="一次性创建满员对战（存储过程 fn_create_match_with_players）")
async def create_full_match(body: CreateFullMatchRequest, me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """通过 JSONB 数组一次性创建对战+参战名单（触发器自动补 match_code；需登录）"""
    if not body.players:
        raise HTTPException(status_code=400, detail="至少需要一名参战玩家")
    players_json = json.dumps([p.model_dump() for p in body.players])
    try:
        result = await db.execute(
            text("SELECT * FROM fn_create_match_with_players(:sid, :map, :mode, CAST(:players AS JSONB))"),
            {"sid": body.season_id, "map": body.map_name, "mode": body.match_mode, "players": players_json},
        )
        row = result.fetchone()
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="创建失败：玩家/英雄不存在，或同一玩家在该对战中重复")
    return {"match_id": row.out_match_id, "match_code": row.out_match_code, "message": "对战已创建"}


@router.post("/{match_id}/players", summary="为对战追加参战玩家（插入 match_detail）")
async def add_match_player(match_id: int, body: MatchPlayer, me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    try:
        await db.execute(text("""
            INSERT INTO match_detail(match_id, player_id, hero_id, team_side)
            VALUES (:m, :p, :h, :t)
        """), {"m": match_id, "p": body.player_id, "h": body.hero_id, "t": body.team_side})
        await db.commit()
        return {"message": "已添加参战玩家"}
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="添加失败：对战/玩家/英雄不存在，或该玩家已在此对战中")


@router.get("/{match_id}", summary="对战详情（含参战名单与结算结果，多表 JOIN）")
async def get_match(match_id: int, db: AsyncSession = Depends(get_db)):
    head = (await db.execute(text("""
        SELECT mr.id, mr.match_code, mr.map_name, mr.match_mode, mr.status,
               mr.winner_side, mr.duration_sec,
               mr.started_at, mr.ended_at, s.name AS season_name
        FROM match_record mr JOIN season s ON mr.season_id = s.id
        WHERE mr.id = :m
    """), {"m": match_id})).fetchone()
    if not head:
        raise HTTPException(status_code=404, detail="对战不存在")

    rows = (await db.execute(text("""
        SELECT md.team_side, md.kills, md.deaths, md.assists, md.kda,
               md.elo_change, md.is_mvp,
               p.id AS player_id, p.nickname, p.status AS player_status,
               h.name AS hero_name
        FROM match_detail md
        JOIN player p ON md.player_id = p.id
        JOIN hero h ON md.hero_id = h.id
        WHERE md.match_id = :m
        ORDER BY md.team_side, md.is_mvp DESC, md.kda DESC
    """), {"m": match_id})).fetchall()

    head_d = dict(head._mapping)
    head_d["started_at"] = str(head_d["started_at"]) if head_d["started_at"] else None
    head_d["ended_at"] = str(head_d["ended_at"]) if head_d["ended_at"] else None
    return {"match": head_d, "players": [dict(r._mapping) for r in rows]}
