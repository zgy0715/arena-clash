"""
审计日志路由（模块5，仅管理员 require_admin）
日志过滤查询（动态 WHERE）+ JSONB detail 展示 + 操作统计视图 v_audit_action_stats
"""
import json

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import require_admin

router = APIRouter()


@router.get("/logs", summary="审计日志（按操作类型/玩家过滤，分页）")
async def list_logs(
    action: str | None = None,
    player_id: int | None = None,
    limit: int = 50,
    offset: int = 0,
    admin_id: int = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    query = "SELECT id, player_id, action, detail, ip_address, created_at FROM audit_log WHERE 1=1"
    params: dict = {}
    if action:
        query += " AND action = :a"
        params["a"] = action
    if player_id:
        query += " AND player_id = :p"
        params["p"] = player_id
    query += " ORDER BY created_at DESC, id DESC LIMIT :lim OFFSET :off"
    params["lim"] = limit
    params["off"] = offset
    rows = (await db.execute(text(query), params)).fetchall()
    out = []
    for r in rows:
        d = dict(r._mapping)
        # 原生 text() 查询下 asyncpg 返回 jsonb 为字符串，这里解析成对象
        det = d.get("detail")
        if isinstance(det, str):
            try:
                det = json.loads(det)
            except (ValueError, TypeError):
                pass
        d["detail"] = det
        d["created_at"] = str(d["created_at"])
        d["ip_address"] = str(d["ip_address"]) if d["ip_address"] else None
        out.append(d)
    return {"logs": out}


@router.get("/actions", summary="所有出现过的操作类型（过滤下拉用）")
async def list_actions(admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(text("SELECT DISTINCT action FROM audit_log ORDER BY action"))).fetchall()
    return {"actions": [r.action for r in rows]}


@router.get("/stats", summary="审计操作统计（视图 v_audit_action_stats）")
async def audit_stats(admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(
        text("SELECT action, cnt, last_at, last_7d FROM v_audit_action_stats ORDER BY cnt DESC")
    )).fetchall()
    out = []
    for r in rows:
        d = dict(r._mapping)
        d["last_at"] = str(d["last_at"]) if d["last_at"] else None
        out.append(d)
    return {"stats": out}
