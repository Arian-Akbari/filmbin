"""Assembles every router under the versioned prefix.

Order matters: routers whose paths start with a literal segment (`/titles/search`)
are registered before the ones that capture a parameter in the same position.
"""

from __future__ import annotations

from fastapi import APIRouter

from app.api.routes import (
    admin,
    auth,
    health,
    lists,
    reviews,
    social,
    titles,
    tracking,
    users,
)

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(titles.router)
api_router.include_router(tracking.router)
api_router.include_router(tracking.watchlist_router)
api_router.include_router(reviews.router)
api_router.include_router(reviews.standalone_router)
api_router.include_router(lists.router)
api_router.include_router(social.feed_router)
api_router.include_router(social.chat_router)
api_router.include_router(admin.router)
