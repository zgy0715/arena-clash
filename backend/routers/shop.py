"""
商城路由：商品列表、购买（行级锁 + 限流）
"""
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import get_current_user

router = APIRouter()
limiter = Limiter(key_func=get_remote_address, storage_uri="redis://localhost:6379/0")


class PurchaseRequest(BaseModel):
    item_id: int = Field(gt=0, description="商品ID必须大于0")


@router.get("/items", summary="商品列表")
async def list_items(
    item_type: str | None = None,
    page: int = 1,
    page_size: int = 20,
    db: AsyncSession = Depends(get_db),
):
    """分页查询商城商品，支持按类型筛选"""
    query = "SELECT id, name, item_type, hero_id, price_gold, price_rp, stock, is_limited, is_on_sale, description FROM shop_item WHERE 1=1"
    params = {}

    if item_type:
        query += " AND item_type = :t"
        params["t"] = item_type

    query += " ORDER BY id LIMIT :lim OFFSET :off"
    params["lim"] = page_size
    params["off"] = (page - 1) * page_size

    result = await db.execute(text(query), params)
    rows = result.fetchall()

    return {
        "page": page,
        "page_size": page_size,
        "items": [
            {
                "id": r.id,
                "name": r.name,
                "item_type": r.item_type,
                "price_gold": r.price_gold,
                "price_rp": r.price_rp,
                "stock": r.stock if r.is_limited else "无限",
                "is_limited": r.is_limited,
                "is_on_sale": r.is_on_sale,
                "description": r.description,
            }
            for r in rows
        ],
    }


@router.post("/purchase", summary="购买商品")
@limiter.limit("10/minute")
async def purchase_item(
    request: Request,
    body: PurchaseRequest,
    player_id: int = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """调用存储过程 fn_purchase_item 购买商品（行级锁防超卖）"""
    result = await db.execute(
        text("SELECT * FROM fn_purchase_item(:p, :i)"),
        {"p": player_id, "i": body.item_id},
    )
    row = result.fetchone()
    await db.commit()

    return {"success": row.success, "message": row.message}
