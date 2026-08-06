#!/usr/bin/env python
"""Small admin CLI for the backend.

    python scripts/manage.py create-admin --email a@b.com --password ... --username admin
    python scripts/manage.py promote --email a@b.com
    python scripts/manage.py seed          # warm the cache with popular titles
    python scripts/manage.py purge-cache   # drop mirrored IMDb payloads
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select  # noqa: E402

from app.core.security import hash_password  # noqa: E402
from app.db.base import SessionLocal, init_db  # noqa: E402
from app.db.models import Title, User, UserRole  # noqa: E402
from app.imdb import service as imdb_service  # noqa: E402
from app.imdb.client import imdb_client  # noqa: E402


async def create_admin(email: str, password: str, username: str, full_name: str) -> None:
    await init_db()
    async with SessionLocal() as session:
        existing = (
            await session.execute(select(User).where(User.email == email.lower()))
        ).scalar_one_or_none()
        if existing:
            existing.role = UserRole.ADMIN.value
            existing.password_hash = hash_password(password)
            await session.commit()
            print(f"existing user {email} promoted to admin and password reset")
            return

        session.add(
            User(
                full_name=full_name,
                username=username.lower(),
                email=email.lower(),
                password_hash=hash_password(password),
                role=UserRole.ADMIN.value,
            )
        )
        await session.commit()
        print(f"admin {email} created")


async def promote(email: str) -> None:
    await init_db()
    async with SessionLocal() as session:
        user = (
            await session.execute(select(User).where(User.email == email.lower()))
        ).scalar_one_or_none()
        if user is None:
            print(f"no user with email {email}")
            return
        user.role = UserRole.ADMIN.value
        await session.commit()
        print(f"{email} is now an admin")


async def seed() -> None:
    """Pre-fill the mirror so a demo works even with a flaky connection."""
    await init_db()
    await imdb_client.start()
    async with SessionLocal() as session:
        for section in (
            "popular_movies",
            "popular_series",
            "top_rated",
            "top_rated_series",
            "new_releases",
        ):
            titles = await imdb_service.get_section(session, section, limit=20)
            await session.commit()
            print(f"{section}: {len(titles)} titles cached")
        total = len((await session.execute(select(Title))).scalars().all())
        print(f"mirror now holds {total} titles")
    await imdb_client.close()


async def purge_cache() -> None:
    await init_db()
    async with SessionLocal() as session:
        removed = await imdb_service.purge_cache(session, older_than_hours=0)
        await session.commit()
        print(f"{removed} cached payloads removed")


def main() -> None:
    parser = argparse.ArgumentParser(description="FilmBin backend management")
    sub = parser.add_subparsers(dest="command", required=True)

    admin = sub.add_parser("create-admin")
    admin.add_argument("--email", required=True)
    admin.add_argument("--password", required=True)
    admin.add_argument("--username", default="admin")
    admin.add_argument("--full-name", default="مدیر سیستم")

    promote_parser = sub.add_parser("promote")
    promote_parser.add_argument("--email", required=True)

    sub.add_parser("seed")
    sub.add_parser("purge-cache")

    args = parser.parse_args()
    if args.command == "create-admin":
        asyncio.run(create_admin(args.email, args.password, args.username, args.full_name))
    elif args.command == "promote":
        asyncio.run(promote(args.email))
    elif args.command == "seed":
        asyncio.run(seed())
    elif args.command == "purge-cache":
        asyncio.run(purge_cache())


if __name__ == "__main__":
    main()
