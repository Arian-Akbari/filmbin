"""Section 5.17 — user-made lists such as «بهترین فیلم‌های اکشن»."""

from __future__ import annotations

from fastapi import APIRouter, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.core.deps import CurrentUser, DbSession, OptionalUser
from app.core.errors import ConflictError, NotFoundError, PermissionDeniedError
from app.db.models import ActivityType, CustomList, CustomListItem, Title, User
from app.imdb import service as imdb_service
from app.schemas.tracking import ListCreate, ListDetail, ListItemCreate, ListOut, ListUpdate
from app.services import titles as title_service
from app.services.activity import record

router = APIRouter(prefix="/lists", tags=["فهرست‌های شخصی"])


async def _load(db: DbSession, list_id: int) -> CustomList:
    row = (
        await db.execute(
            select(CustomList)
            .options(selectinload(CustomList.items))
            .where(CustomList.id == list_id)
        )
    ).scalar_one_or_none()
    if row is None:
        raise NotFoundError("این فهرست وجود ندارد.", code="LIST_NOT_FOUND")
    return row


def _require_owner(row: CustomList, user: User) -> None:
    if row.user_id != user.id and not user.is_admin:
        raise PermissionDeniedError("این فهرست متعلق به شما نیست.")


async def _to_out(db: DbSession, row: CustomList) -> ListOut:
    owner = await db.get(User, row.user_id)
    count = int(
        (
            await db.execute(
                select(func.count())
                .select_from(CustomListItem)
                .where(CustomListItem.list_id == row.id)
            )
        ).scalar_one()
    )
    return ListOut(
        id=row.id,
        name=row.name,
        description=row.description,
        is_public=row.is_public,
        item_count=count,
        owner_username=owner.username if owner else None,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


@router.get("", response_model=list[ListOut], summary="فهرست‌های من")
async def my_lists(db: DbSession, user: CurrentUser) -> list[ListOut]:
    rows = list(
        (
            await db.execute(
                select(CustomList)
                .where(CustomList.user_id == user.id)
                .order_by(CustomList.created_at.desc())
            )
        ).scalars()
    )
    return [await _to_out(db, row) for row in rows]


@router.post(
    "",
    response_model=ListOut,
    status_code=status.HTTP_201_CREATED,
    summary="ساخت فهرست تازه",
    description="مثلاً «بهترین فیلم‌های اکشن» یا «فیلم‌هایی که باید ببینم».",
)
async def create_list(payload: ListCreate, db: DbSession, user: CurrentUser) -> ListOut:
    row = CustomList(
        user_id=user.id,
        name=payload.name,
        description=payload.description,
        is_public=payload.is_public,
    )
    db.add(row)
    await db.flush()
    await record(db, user.id, ActivityType.LIST_CREATED, payload={"name": row.name})
    return await _to_out(db, row)


@router.get(
    "/{list_id}",
    response_model=ListDetail,
    summary="جزئیات یک فهرست",
    responses={403: {"description": "فهرست خصوصی است"}, 404: {"description": "پیدا نشد"}},
)
async def list_detail(list_id: int, db: DbSession, viewer: OptionalUser) -> ListDetail:
    row = await _load(db, list_id)
    if not row.is_public and (viewer is None or viewer.id != row.user_id):
        if viewer is None:
            raise PermissionDeniedError("این فهرست خصوصی است.", status_code=401)
        raise PermissionDeniedError("این فهرست خصوصی است.")

    titles = list(
        (
            await db.execute(
                select(Title)
                .join(CustomListItem, CustomListItem.title_id == Title.imdb_id)
                .where(CustomListItem.list_id == list_id)
                .order_by(CustomListItem.position, CustomListItem.added_at)
            )
        ).scalars()
    )

    base = await _to_out(db, row)
    return ListDetail(
        **base.model_dump(),
        items=await title_service.summarize(db, titles, viewer.id if viewer else None),
    )


@router.patch("/{list_id}", response_model=ListOut, summary="ویرایش فهرست")
async def update_list(
    list_id: int, payload: ListUpdate, db: DbSession, user: CurrentUser
) -> ListOut:
    row = await _load(db, list_id)
    _require_owner(row, user)

    if payload.name is not None:
        row.name = payload.name
    if payload.description is not None:
        row.description = payload.description
    if payload.is_public is not None:
        row.is_public = payload.is_public
    await db.flush()
    return await _to_out(db, row)


@router.delete(
    "/{list_id}", status_code=status.HTTP_204_NO_CONTENT, summary="حذف فهرست"
)
async def delete_list(list_id: int, db: DbSession, user: CurrentUser) -> Response:
    row = await _load(db, list_id)
    _require_owner(row, user)
    await db.delete(row)
    await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{list_id}/items",
    response_model=ListDetail,
    status_code=status.HTTP_201_CREATED,
    summary="افزودن اثر به فهرست",
    responses={409: {"description": "این اثر از قبل در فهرست است"}},
)
async def add_item(
    list_id: int, payload: ListItemCreate, db: DbSession, user: CurrentUser
) -> ListDetail:
    row = await _load(db, list_id)
    _require_owner(row, user)
    await imdb_service.get_title(db, payload.imdb_id)

    exists = (
        await db.execute(
            select(CustomListItem).where(
                CustomListItem.list_id == list_id,
                CustomListItem.title_id == payload.imdb_id,
            )
        )
    ).scalar_one_or_none()
    if exists is not None:
        raise ConflictError("این اثر از قبل در فهرست هست.", code="ALREADY_IN_LIST")

    position = int(
        (
            await db.execute(
                select(func.count())
                .select_from(CustomListItem)
                .where(CustomListItem.list_id == list_id)
            )
        ).scalar_one()
    )
    db.add(
        CustomListItem(list_id=list_id, title_id=payload.imdb_id, position=position)
    )
    await db.flush()
    return await list_detail(list_id, db, user)


@router.delete(
    "/{list_id}/items/{imdb_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="حذف اثر از فهرست",
)
async def remove_item(
    list_id: int, imdb_id: str, db: DbSession, user: CurrentUser
) -> Response:
    row = await _load(db, list_id)
    _require_owner(row, user)

    item = (
        await db.execute(
            select(CustomListItem).where(
                CustomListItem.list_id == list_id, CustomListItem.title_id == imdb_id
            )
        )
    ).scalar_one_or_none()
    if item is None:
        raise NotFoundError("این اثر در فهرست نیست.", code="ITEM_NOT_IN_LIST")

    await db.delete(item)
    await db.flush()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
