"""
管理后台路由（仅管理员，依赖 require_admin）
模块1：英雄 / 商品 / 玩家 的增、改、删（含级联删除）+ 物化视图刷新
"""
import json

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import require_admin

router = APIRouter()


async def _audit(db: AsyncSession, admin_id: int, action: str, detail: dict):
    """统一写审计日志（复刻存储过程里的审计模式）"""
    await db.execute(
        text("INSERT INTO audit_log(player_id, action, detail) VALUES (:p, :a, CAST(:d AS JSONB))"),
        {"p": admin_id, "a": action, "d": json.dumps(detail, ensure_ascii=False)},
    )


# ======================================================================
# 英雄管理
# ======================================================================
class HeroBody(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    title: str | None = None
    role: str = Field(pattern="^(fighter|mage|assassin|marksman|support|tank)$")
    price_gold: int = Field(default=4500, ge=0)
    price_rp: int = Field(default=0, ge=0)
    difficulty: int = Field(default=1, ge=1, le=10)
    description: str | None = None
    is_free: bool = False
    is_active: bool = True


@router.get("/heroes", summary="英雄列表（管理视图，含已下架）")
async def admin_list_heroes(admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("""
        SELECT id, name, title, role, price_gold, price_rp, difficulty,
               description, is_free, is_active
        FROM hero ORDER BY id
    """))
    return {"heroes": [dict(r._mapping) for r in result.fetchall()]}


@router.post("/heroes", summary="新增英雄")
async def admin_create_hero(body: HeroBody, admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("""
        INSERT INTO hero(name, title, role, price_gold, price_rp, difficulty, description, is_free, is_active)
        VALUES (:name, :title, :role, :pg, :pr, :diff, :desc, :free, :active)
        RETURNING id
    """), {"name": body.name, "title": body.title, "role": body.role, "pg": body.price_gold,
           "pr": body.price_rp, "diff": body.difficulty, "desc": body.description,
           "free": body.is_free, "active": body.is_active})
    new_id = result.fetchone()[0]
    await _audit(db, admin_id, "hero_create", {"hero_id": new_id, "name": body.name})
    await db.commit()
    return {"id": new_id, "message": "英雄已创建"}


@router.put("/heroes/{hero_id}", summary="修改英雄")
async def admin_update_hero(hero_id: int, body: HeroBody, admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("""
        UPDATE hero SET name=:name, title=:title, role=:role, price_gold=:pg, price_rp=:pr,
               difficulty=:diff, description=:desc, is_free=:free, is_active=:active
        WHERE id=:id
    """), {"name": body.name, "title": body.title, "role": body.role, "pg": body.price_gold,
           "pr": body.price_rp, "diff": body.difficulty, "desc": body.description,
           "free": body.is_free, "active": body.is_active, "id": hero_id})
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="英雄不存在")
    await _audit(db, admin_id, "hero_update", {"hero_id": hero_id, "name": body.name})
    await db.commit()
    return {"message": "英雄已更新"}


@router.delete("/heroes/{hero_id}", summary="删除英雄（默认软删；hard=true 尝试硬删，被引用则 409）")
async def admin_delete_hero(
    hero_id: int,
    hard: bool = Query(False, description="true=硬删除（被对战引用会失败）"),
    admin_id: int = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    if hard:
        try:
            result = await db.execute(text("DELETE FROM hero WHERE id=:id"), {"id": hero_id})
            if result.rowcount == 0:
                await db.rollback()
                raise HTTPException(status_code=404, detail="英雄不存在")
            await _audit(db, admin_id, "hero_hard_delete", {"hero_id": hero_id})
            await db.commit()
            return {"success": True, "message": "英雄已硬删除"}
        except IntegrityError:
            await db.rollback()
            raise HTTPException(status_code=409, detail="英雄已被对战记录引用，无法硬删除，请改为下架（软删除）")
    # 软删除（存储过程）
    result = await db.execute(text("SELECT * FROM fn_soft_delete_hero(:id)"), {"id": hero_id})
    row = result.fetchone()
    await _audit(db, admin_id, "hero_soft_delete_api", {"hero_id": hero_id})
    await db.commit()
    if not row.success:
        raise HTTPException(status_code=404, detail=row.message)
    return {"success": True, "message": row.message}


# ======================================================================
# 商品管理
# ======================================================================
class ShopBody(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    item_type: str = Field(pattern="^(hero|skin|emote|frame)$")
    hero_id: int | None = None
    price_gold: int = Field(default=0, ge=0)
    price_rp: int = Field(default=0, ge=0)
    stock: int = -1
    is_limited: bool = False
    is_on_sale: bool = True
    description: str | None = None


@router.get("/shop-items", summary="商品列表（管理视图）")
async def admin_list_items(admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("""
        SELECT id, name, item_type, hero_id, price_gold, price_rp, stock,
               is_limited, is_on_sale, description
        FROM shop_item ORDER BY id
    """))
    return {"items": [dict(r._mapping) for r in result.fetchall()]}


@router.post("/shop-items", summary="新增商品")
async def admin_create_item(body: ShopBody, admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    try:
        result = await db.execute(text("""
            INSERT INTO shop_item(name, item_type, hero_id, price_gold, price_rp, stock, is_limited, is_on_sale, description)
            VALUES (:name, :t, :hid, :pg, :pr, :stock, :lim, :sale, :desc)
            RETURNING id
        """), {"name": body.name, "t": body.item_type, "hid": body.hero_id, "pg": body.price_gold,
               "pr": body.price_rp, "stock": body.stock, "lim": body.is_limited,
               "sale": body.is_on_sale, "desc": body.description})
        new_id = result.fetchone()[0]
        await _audit(db, admin_id, "item_create", {"item_id": new_id, "name": body.name})
        await db.commit()
        return {"id": new_id, "message": "商品已创建"}
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="违反数据约束（价格需>0；限量商品库存需≥0）")


@router.put("/shop-items/{item_id}", summary="修改商品")
async def admin_update_item(item_id: int, body: ShopBody, admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    try:
        result = await db.execute(text("""
            UPDATE shop_item SET name=:name, item_type=:t, hero_id=:hid, price_gold=:pg, price_rp=:pr,
                   stock=:stock, is_limited=:lim, is_on_sale=:sale, description=:desc
            WHERE id=:id
        """), {"name": body.name, "t": body.item_type, "hid": body.hero_id, "pg": body.price_gold,
               "pr": body.price_rp, "stock": body.stock, "lim": body.is_limited,
               "sale": body.is_on_sale, "desc": body.description, "id": item_id})
        if result.rowcount == 0:
            await db.rollback()
            raise HTTPException(status_code=404, detail="商品不存在")
        await _audit(db, admin_id, "item_update", {"item_id": item_id, "name": body.name})
        await db.commit()
        return {"message": "商品已更新"}
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="违反数据约束（价格需>0；限量商品库存需≥0）")


@router.delete("/shop-items/{item_id}", summary="删除商品（购买记录级联删除）")
async def admin_delete_item(item_id: int, admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("DELETE FROM shop_item WHERE id=:id"), {"id": item_id})
    if result.rowcount == 0:
        await db.rollback()
        raise HTTPException(status_code=404, detail="商品不存在")
    await _audit(db, admin_id, "item_delete", {"item_id": item_id})
    await db.commit()
    return {"success": True, "message": "商品已删除（关联购买记录已级联清理）"}


# ======================================================================
# 玩家管理
# ======================================================================
class PlayerAdminBody(BaseModel):
    nickname: str | None = None
    gold: int | None = Field(default=None, ge=0)
    elo_rating: int | None = Field(default=None, ge=0)
    status: str | None = Field(default=None, pattern="^(online|offline|in_match|banned)$")
    is_admin: bool | None = None


@router.get("/players", summary="玩家列表（管理视图，支持搜索/分页）")
async def admin_list_players(
    q: str | None = None,
    page: int = 1,
    page_size: int = 20,
    admin_id: int = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    where = "WHERE 1=1"
    params: dict = {}
    if q:
        where += " AND (username ILIKE :q OR nickname ILIKE :q)"
        params["q"] = f"%{q}%"
    total = (await db.execute(text(f"SELECT COUNT(*) FROM player {where}"), params)).scalar()
    params["lim"] = page_size
    params["off"] = (page - 1) * page_size
    result = await db.execute(text(f"""
        SELECT id, username, nickname, elo_rating, gold, level, status,
               is_admin, friend_count, total_matches, wins, losses, created_at
        FROM player {where} ORDER BY id LIMIT :lim OFFSET :off
    """), params)
    return {"total": total, "page": page, "players": [dict(r._mapping) for r in result.fetchall()]}


@router.put("/players/{player_id}", summary="管理员修改玩家（昵称/金币/ELO/状态/管理员）")
async def admin_update_player(player_id: int, body: PlayerAdminBody, admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    fields = []
    params: dict = {"id": player_id}
    for col, val in [("nickname", body.nickname), ("gold", body.gold),
                     ("elo_rating", body.elo_rating), ("status", body.status),
                     ("is_admin", body.is_admin)]:
        if val is not None:
            fields.append(f"{col} = :{col}")   # 列名来自固定白名单，非用户输入
            params[col] = val
    if not fields:
        raise HTTPException(status_code=400, detail="没有需要更新的字段")
    result = await db.execute(text(f"UPDATE player SET {', '.join(fields)} WHERE id=:id"), params)
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="玩家不存在")
    await _audit(db, admin_id, "player_admin_update", {"player_id": player_id, "fields": [f.split(" = ")[0] for f in fields]})
    await db.commit()
    return {"message": "玩家已更新"}


@router.delete("/players/{player_id}", summary="级联删除玩家（存储过程 fn_delete_player_cascade）")
async def admin_delete_player(player_id: int, admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        text("SELECT * FROM fn_delete_player_cascade(:a, :t)"),
        {"a": admin_id, "t": player_id},
    )
    row = result.fetchone()
    await db.commit()
    if not row.success:
        raise HTTPException(status_code=400, detail=row.message)
    return {"success": True, "message": row.message}


# ======================================================================
# 统计维护
# ======================================================================
@router.post("/refresh-stats", summary="刷新物化视图 mv_season_statistics")
async def admin_refresh_stats(admin_id: int = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    await db.execute(text("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_season_statistics"))
    await db.commit()
    return {"message": "统计视图已刷新（CONCURRENTLY 模式，不阻塞读取）"}
