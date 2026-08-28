from __future__ import annotations

import secrets

from fastapi import Header, HTTPException, Request, status


async def verify_api_key(
    request: Request,
    x_api_key: str | None = Header(default=None),
) -> None:
    configured_key = request.app.state.settings.api_key
    if configured_key is None or configured_key == "":
        return
    if x_api_key is None or not secrets.compare_digest(x_api_key, configured_key):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )
