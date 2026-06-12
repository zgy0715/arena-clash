"""
赛季中心路由（模块4）：赛季列表 + 赛季重置（存储过程 fn_reset_season，CTE 段位衰减迁移）
赛季历史排名复用排行榜 /api/leaderboard/season/{id}（窗口函数 RANK/LAG/LEAD）
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import require_admin

router = APIRouter()


@router.get("", summary="赛季列表（含参与人数，子查询）")
async def list_seasons(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(text("""
        SELECT s.id, s.name, s.status, s.start_date, s.end_date,
               (SELECT COUNT(*) FROM player_season_rank psr WHERE psr.season_id = s.id) AS players
        FROM season s
        ORDER BY s.id DESC
    """))).fetchall()
    out = []
    for r in rows:
        d = dict(r._mapping)
        d["start_date"] = str(d["start_date"]) if d["start_date"] else None
        d["end_date"] = str(d["end_date"]) if d["end_date"] else None
        out.append(d)
    return {"seasons": out}


@router.post("/reset", summary="重置赛季（存储过程 fn_reset_season：归档旧赛季+段位衰减迁移）")
async def reset_season(admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    row = (await db.execute(text("SELECT * FROM fn_reset_season()"))).fetchone()
    await db.commit()
    if not row.success:
        raise HTTPException(status_code=400, detail=row.message)
    return {"success": True, "message": row.message}
