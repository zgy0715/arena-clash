"""
社交模块路由（模块3，需登录 get_current_user）
好友请求、好友列表、删除好友、与好友战绩对比（player↔player 自连接）
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import get_current_user

router = APIRouter()


class FriendRequestBody(BaseModel):
    addressee_id: int = Field(gt=0, description="想添加的玩家ID")


@router.post("/friend-requests", summary="发送好友请求")
async def send_friend_request(body: FriendRequestBody, me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if body.addressee_id == me:
        raise HTTPException(status_code=400, detail="不能添加自己为好友")
    # 检查是否已经是好友
    exists = (await db.execute(
        text("SELECT 1 FROM friendship WHERE player_id=:m AND friend_id=:f"),
        {"m": me, "f": body.addressee_id},
    )).fetchone()
    if exists:
        raise HTTPException(status_code=400, detail="你们已经是好友了")
    # 检查是否已有历史请求
    existing = (await db.execute(
        text("SELECT status FROM friend_request WHERE requester_id=:r AND addressee_id=:a"),
        {"r": me, "a": body.addressee_id},
    )).fetchone()
    if existing:
        if existing.status == "rejected":
            raise HTTPException(status_code=400, detail="对方已拒绝你的好友请求，无法重复发送")
        elif existing.status == "pending":
            raise HTTPException(status_code=400, detail="已发送过好友请求，请等待回复")
    try:
        await db.execute(text("""
            INSERT INTO friend_request(requester_id, addressee_id, status)
            VALUES (:r, :a, 'pending')
        """), {"r": me, "a": body.addressee_id})
        await db.commit()
        return {"message": "好友请求已发送"}
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=400, detail="请求失败：对方玩家不存在")


@router.get("/friend-requests/incoming", summary="收到的待处理好友请求")
async def incoming_requests(me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(text("""
        SELECT fr.id, fr.requester_id, p.nickname AS requester_nickname,
               p.elo_rating AS requester_elo, fr.created_at
        FROM friend_request fr
        JOIN player p ON fr.requester_id = p.id
        WHERE fr.addressee_id = :me AND fr.status = 'pending'
        ORDER BY fr.created_at DESC
    """), {"me": me})).fetchall()
    out = []
    for r in rows:
        d = dict(r._mapping)
        d["created_at"] = str(d["created_at"])
        out.append(d)
    return {"requests": out}


@router.post("/friend-requests/{req_id}/accept", summary="接受好友请求（存储过程 fn_accept_friend_request）")
async def accept_request(req_id: int, me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    owner = (await db.execute(
        text("SELECT addressee_id FROM friend_request WHERE id=:i"), {"i": req_id}
    )).fetchone()
    if not owner:
        raise HTTPException(status_code=404, detail="请求不存在")
    if owner.addressee_id != me:
        raise HTTPException(status_code=403, detail="只能处理发给自己的好友请求")
    row = (await db.execute(text("SELECT * FROM fn_accept_friend_request(:i)"), {"i": req_id})).fetchone()
    await db.commit()
    if not row.success:
        raise HTTPException(status_code=400, detail=row.message)
    return {"success": True, "message": row.message}


@router.post("/friend-requests/{req_id}/reject", summary="拒绝好友请求")
async def reject_request(req_id: int, me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("""
        UPDATE friend_request SET status='rejected', responded_at=NOW()
        WHERE id=:i AND addressee_id=:me AND status='pending'
    """), {"i": req_id, "me": me})
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=400, detail="请求不存在、无权处理或已处理")
    return {"message": "已拒绝该请求"}


@router.get("/friends", summary="我的好友列表")
async def my_friends(me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(text("""
        SELECT f.friend_id, p.nickname, p.elo_rating, p.status, p.level,
               p.total_matches, p.friend_count, f.created_at
        FROM friendship f
        JOIN player p ON f.friend_id = p.id
        WHERE f.player_id = :me
        ORDER BY p.elo_rating DESC
    """), {"me": me})).fetchall()
    out = []
    for r in rows:
        d = dict(r._mapping)
        d["created_at"] = str(d["created_at"])
        out.append(d)
    return {"friends": out}


@router.delete("/friends/{friend_id}", summary="删除好友（双向删除，计数由触发器维护）")
async def delete_friend(friend_id: int, me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(text("""
        DELETE FROM friendship
        WHERE (player_id=:me AND friend_id=:f) OR (player_id=:f AND friend_id=:me)
    """), {"me": me, "f": friend_id})
    await db.commit()
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="你们不是好友")
    return {"message": "已删除好友"}


@router.get("/compare/{friend_id}", summary="与好友战绩对比（player↔player 自连接）")
async def compare_with_friend(friend_id: int, me: int = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    is_friend = (await db.execute(
        text("SELECT 1 FROM friendship WHERE player_id=:me AND friend_id=:f"),
        {"me": me, "f": friend_id},
    )).fetchone()
    if not is_friend:
        raise HTTPException(status_code=400, detail="对方不是你的好友")
    row = (await db.execute(text("""
        SELECT me.id  AS me_id,  me.nickname AS me_nick,  me.elo_rating AS me_elo,
               me.wins AS me_wins, me.losses AS me_losses, me.total_matches AS me_total, me.level AS me_level,
               fr.id  AS fr_id,  fr.nickname AS fr_nick,  fr.elo_rating AS fr_elo,
               fr.wins AS fr_wins, fr.losses AS fr_losses, fr.total_matches AS fr_total, fr.level AS fr_level
        FROM player me
        JOIN player fr ON fr.id = :f
        WHERE me.id = :me
    """), {"me": me, "f": friend_id})).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="玩家不存在")
    d = dict(row._mapping)

    def wr(w, t):
        return round(w / t * 100, 1) if t else 0

    return {
        "me": {"id": d["me_id"], "nickname": d["me_nick"], "elo": d["me_elo"],
               "wins": d["me_wins"], "losses": d["me_losses"], "total": d["me_total"],
               "level": d["me_level"], "win_rate": wr(d["me_wins"], d["me_total"])},
        "friend": {"id": d["fr_id"], "nickname": d["fr_nick"], "elo": d["fr_elo"],
                   "wins": d["fr_wins"], "losses": d["fr_losses"], "total": d["fr_total"],
                   "level": d["fr_level"], "win_rate": wr(d["fr_wins"], d["fr_total"])},
    }
