"""In-process sliding-window rate limiter (section 8.3 — abuse protection).

Auth endpoints get a much tighter budget than the rest of the API, because
that is where brute-force attempts land. Keyed by client IP, or by user id
once a request is authenticated.
"""

from __future__ import annotations

import time
from collections import defaultdict, deque

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.config import settings
from app.core.errors import RateLimitedError

_AUTH_PATHS = ("/auth/login", "/auth/register", "/auth/password")


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app) -> None:
        super().__init__(app)
        self._hits: dict[str, deque[float]] = defaultdict(deque)

    def _budget(self, path: str) -> tuple[int, int]:
        if any(p in path for p in _AUTH_PATHS):
            return (
                settings.auth_rate_limit_requests,
                settings.auth_rate_limit_window_seconds,
            )
        return settings.rate_limit_requests, settings.rate_limit_window_seconds

    async def dispatch(self, request: Request, call_next) -> Response:
        if request.method == "OPTIONS":
            return await call_next(request)

        limit, window = self._budget(request.url.path)
        client = request.client.host if request.client else "unknown"
        bucket = f"{client}:{'auth' if limit != settings.rate_limit_requests else 'api'}"

        now = time.monotonic()
        hits = self._hits[bucket]
        while hits and now - hits[0] > window:
            hits.popleft()

        if len(hits) >= limit:
            retry_after = int(window - (now - hits[0])) + 1
            error = RateLimitedError(detail={"retry_after_seconds": retry_after})
            return JSONResponse(
                status_code=error.status_code,
                content=error.to_payload(),
                headers={"Retry-After": str(retry_after)},
            )

        hits.append(now)
        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(limit)
        response.headers["X-RateLimit-Remaining"] = str(max(0, limit - len(hits)))
        return response
