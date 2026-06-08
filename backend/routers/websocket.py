"""
WebSocket 实时通信路由
JWT 认证 + 连接管理 + 心跳检测
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from jose import jwt

from config import settings

router = APIRouter()


class ConnectionManager:
    """WebSocket 连接管理器"""
    def __init__(self):
        self.active: dict[int, WebSocket] = {}

    async def connect(self, player_id: int, websocket: WebSocket):
        await websocket.accept()
        self.active[player_id] = websocket

    def disconnect(self, player_id: int):
        self.active.pop(player_id, None)

    async def send(self, player_id: int, message: dict):
        ws = self.active.get(player_id)
        if ws:
            await ws.send_json(message)

    async def broadcast(self, message: dict):
        for ws in self.active.values():
            await ws.send_json(message)


manager = ConnectionManager()


def verify_ws_token(token: str) -> int | None:
    """验证 WebSocket 连接中的 JWT Token"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        return int(payload["sub"])
    except Exception:
        return None


@router.websocket("/game")
async def game_websocket(websocket: WebSocket, token: str = Query(...)):
    """游戏实时通信 WebSocket"""
    player_id = verify_ws_token(token)
    if player_id is None:
        await websocket.close(code=4001, reason="认证失败")
        return

    await manager.connect(player_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")

            if msg_type == "ping":
                await manager.send(player_id, {"type": "pong"})
            elif msg_type == "chat":
                await manager.broadcast({
                    "type": "chat",
                    "player_id": player_id,
                    "message": data.get("message", ""),
                })
    except WebSocketDisconnect:
        manager.disconnect(player_id)
