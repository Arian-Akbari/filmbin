"""Bonus features (section 13): activity feed and a live chat room per title."""

from __future__ import annotations

import logging
from collections import defaultdict
from typing import Annotated

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from pydantic import ValidationError as PydanticValidationError
from sqlalchemy import select

from app.core.deps import CurrentUser, DbSession
from app.core.errors import AppError
from app.core.security import decode_access_token
from app.db.base import SessionLocal
from app.db.models import Activity, ChatMessage, Follow, Title, User
from app.imdb import service as imdb_service
from app.schemas.review import ReviewAuthor
from app.schemas.social import (
    ChatHistoryResponse,
    ChatMessageIn,
    ChatMessageOut,
    FeedItem,
    FeedResponse,
)
from app.services import titles as title_service

logger = logging.getLogger("filmbin.chat")

feed_router = APIRouter(tags=["اجتماعی"])
chat_router = APIRouter(prefix="/titles", tags=["اجتماعی"])


@feed_router.get(
    "/feed",
    response_model=FeedResponse,
    summary="فعالیت کاربرانی که دنبال می‌کنید",
)
async def feed(
    db: DbSession,
    user: CurrentUser,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
) -> FeedResponse:
    following = [
        row
        for row in (
            await db.execute(select(Follow.following_id).where(Follow.follower_id == user.id))
        ).scalars()
    ]
    if not following:
        return FeedResponse(items=[])

    rows = list(
        (
            await db.execute(
                select(Activity, User)
                .join(User, User.id == Activity.user_id)
                .where(Activity.user_id.in_(following))
                .order_by(Activity.created_at.desc(), Activity.id.desc())
                .limit(limit)
            )
        ).all()
    )

    title_ids = [row[0].title_id for row in rows if row[0].title_id]
    titles = {
        title.imdb_id: title
        for title in (
            await db.execute(select(Title).where(Title.imdb_id.in_(title_ids)))
        ).scalars()
    }
    summaries = {
        summary.imdb_id: summary
        for summary in await title_service.summarize(db, titles.values(), user.id)
    }

    return FeedResponse(
        items=[
            FeedItem(
                id=activity.id,
                type=activity.type,
                created_at=activity.created_at,
                user=ReviewAuthor.model_validate(author),
                title=summaries.get(activity.title_id) if activity.title_id else None,
                payload=activity.payload,
            )
            for activity, author in rows
        ]
    )


@chat_router.get(
    "/{imdb_id}/chat",
    response_model=ChatHistoryResponse,
    summary="تاریخچهٔ گفت‌وگوی یک اثر",
)
async def chat_history(
    imdb_id: str,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> ChatHistoryResponse:
    rows = list(
        (
            await db.execute(
                select(ChatMessage)
                .where(ChatMessage.room == imdb_id)
                .order_by(ChatMessage.created_at.desc())
                .limit(limit)
            )
        ).scalars()
    )
    return ChatHistoryResponse(
        items=[ChatMessageOut.model_validate(row) for row in reversed(rows)]
    )


@chat_router.post(
    "/{imdb_id}/chat",
    response_model=ChatMessageOut,
    status_code=status.HTTP_201_CREATED,
    summary="ارسال پیام در گفت‌وگوی یک اثر",
)
async def post_message(
    imdb_id: str, payload: ChatMessageIn, db: DbSession, user: CurrentUser
) -> ChatMessageOut:
    await imdb_service.get_title(db, imdb_id)
    message = ChatMessage(room=imdb_id, user_id=user.id, text=payload.text)
    db.add(message)
    await db.flush()
    await db.refresh(message, ["user"])

    out = ChatMessageOut.model_validate(message)
    await manager.broadcast(imdb_id, out)
    return out


class ChatManager:
    """Keeps the open sockets per room and fans messages out to them."""

    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = defaultdict(set)

    async def connect(self, room: str, socket: WebSocket) -> None:
        await socket.accept()
        self._rooms[room].add(socket)

    def disconnect(self, room: str, socket: WebSocket) -> None:
        self._rooms[room].discard(socket)
        if not self._rooms[room]:
            self._rooms.pop(room, None)

    async def broadcast(self, room: str, message: ChatMessageOut) -> None:
        payload = message.model_dump(mode="json")
        for socket in list(self._rooms.get(room, ())):
            try:
                await socket.send_json(payload)
            except Exception:  # noqa: BLE001 — a dead socket must not stop the fan-out
                self.disconnect(room, socket)


manager = ChatManager()


@chat_router.websocket("/{imdb_id}/chat/ws")
async def chat_socket(websocket: WebSocket, imdb_id: str, token: str = Query(...)) -> None:
    """Live room. The access token travels as a query parameter because browsers
    cannot set headers on a WebSocket handshake."""
    try:
        payload = decode_access_token(token)
    except AppError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    user_id = int(payload["sub"])
    await manager.connect(imdb_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            try:
                incoming = ChatMessageIn(**data)
            except PydanticValidationError:
                await websocket.send_json({"error": "متن پیام نامعتبر است."})
                continue

            async with SessionLocal() as session:
                user = await session.get(User, user_id)
                if user is None or not user.is_active:
                    await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                    return
                message = ChatMessage(room=imdb_id, user_id=user_id, text=incoming.text)
                session.add(message)
                await session.commit()
                await session.refresh(message, ["user"])
                out = ChatMessageOut.model_validate(message)

            await manager.broadcast(imdb_id, out)
    except WebSocketDisconnect:
        manager.disconnect(imdb_id, websocket)
    except Exception:  # noqa: BLE001
        logger.exception("chat socket failed")
        manager.disconnect(imdb_id, websocket)
