# app/utils/rate_limiter.py

import time
from collections import defaultdict
from fastapi import Request, HTTPException

# In-memory store: ip -> list of request timestamps
_request_log: dict = defaultdict(list)


def rate_limit(
    request: Request,
    max_requests: int = 10,
    window_seconds: int = 60,
):
    """
    Simple in-memory rate limiter.

    Raises HTTP 429 if the client IP exceeds max_requests
    within the rolling window_seconds window.
    """
    ip  = request.client.host if request.client else "unknown"
    now = time.time()

    # Remove timestamps outside the window
    _request_log[ip] = [
        t for t in _request_log[ip]
        if now - t < window_seconds
    ]

    if len(_request_log[ip]) >= max_requests:
        retry_after = int(window_seconds - (now - _request_log[ip][0]))
        raise HTTPException(
            status_code=429,
            detail={
                "error":       "Too many requests",
                "message":     f"Maximum {max_requests} requests per "
                               f"{window_seconds} seconds allowed.",
                "retry_after": max(retry_after, 1),
            },
            headers={"Retry-After": str(max(retry_after, 1))},
        )

    _request_log[ip].append(now)