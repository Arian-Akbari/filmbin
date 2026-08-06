"""HTTP transport for IMDb's GraphQL endpoint.

Three things this layer is responsible for, all of them from section 8.4:

* **Retries** — a single dropped packet should not surface as an error.
* **A circuit breaker** — once IMDb has failed N times in a row we stop calling
  it for a cooldown period. The backend keeps serving cached data instead of
  piling up timeouts, so an IMDb outage never takes the whole API down.
* **Turning transport failures into typed errors** the API layer can map onto
  the standard error envelope.
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any

import httpx

from app.core.config import settings
from app.core.errors import UpstreamError, UpstreamUnavailableError

logger = logging.getLogger("filmbin.imdb")

# IMDb's edge rejects calls that do not look like they came from its own site.
# `referer` is the header it actually checks — without it every request comes
# back 403, no matter how browser-like the user-agent is.
_HEADERS = {
    "content-type": "application/json",
    "accept": "application/json",
    "user-agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    ),
    "origin": "https://www.imdb.com",
    "referer": "https://www.imdb.com/",
}


class CircuitBreaker:
    def __init__(self, threshold: int, cooldown: float) -> None:
        self.threshold = threshold
        self.cooldown = cooldown
        self.failures = 0
        self.opened_at: float | None = None

    @property
    def is_open(self) -> bool:
        if self.opened_at is None:
            return False
        if time.monotonic() - self.opened_at >= self.cooldown:
            # Half-open: let the next call through and see what happens.
            self.opened_at = None
            self.failures = 0
            return False
        return True

    def record_success(self) -> None:
        self.failures = 0
        self.opened_at = None

    def record_failure(self) -> None:
        self.failures += 1
        if self.failures >= self.threshold and self.opened_at is None:
            self.opened_at = time.monotonic()
            logger.warning("IMDb circuit breaker opened after %s failures", self.failures)


class ImdbClient:
    def __init__(self) -> None:
        self._client: httpx.AsyncClient | None = None
        self.breaker = CircuitBreaker(
            settings.breaker_failure_threshold, settings.breaker_cooldown_seconds
        )

    async def start(self) -> None:
        if self._client is None:
            self._client = httpx.AsyncClient(
                base_url=settings.imdb_graphql_url,
                timeout=httpx.Timeout(settings.imdb_timeout_seconds),
                headers=_HEADERS,
                limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
                follow_redirects=True,
            )

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None

    async def execute(
        self, query: str, variables: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        if self.breaker.is_open:
            raise UpstreamUnavailableError(
                "سرویس IMDb موقتاً در دسترس نیست.",
                detail={"reason": "circuit_open"},
            )

        await self.start()
        assert self._client is not None
        payload = {"query": query, "variables": variables or {}}
        last_error: Exception | None = None

        for attempt in range(settings.imdb_max_retries + 1):
            try:
                response = await self._client.post("", json=payload)
                if response.status_code >= 500:
                    raise httpx.HTTPStatusError(
                        f"IMDb {response.status_code}",
                        request=response.request,
                        response=response,
                    )
                if response.status_code == 429:
                    raise httpx.HTTPStatusError(
                        "IMDb rate limited", request=response.request, response=response
                    )
                data = response.json()
                if data.get("errors"):
                    # A GraphQL-level error is our bug, not an outage — do not
                    # trip the breaker, just report it.
                    message = data["errors"][0].get("message", "unknown")
                    logger.error("IMDb GraphQL error: %s", message)
                    self.breaker.record_success()
                    raise UpstreamError(detail={"graphql_error": message})
                self.breaker.record_success()
                return data.get("data") or {}
            except (httpx.TimeoutException, httpx.HTTPStatusError, httpx.TransportError) as exc:
                last_error = exc
                if attempt < settings.imdb_max_retries:
                    await asyncio.sleep(0.4 * (2**attempt))
                continue

        self.breaker.record_failure()
        logger.warning("IMDb request failed after retries: %s", last_error)
        raise UpstreamUnavailableError(detail={"reason": type(last_error).__name__})


imdb_client = ImdbClient()
