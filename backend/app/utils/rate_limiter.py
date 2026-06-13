# app/utils/rate_limiter.py

import os
import time
from collections import defaultdict
from fastapi import Request, HTTPException

USE_REDIS = os.getenv("REDIS_URL") is not None

if USE_REDIS:
    import redis
    rcache = redis.Redis.from_url(os.getenv("REDIS_URL"))
else:
    # In-memory store: ip -> list of request timestamps
    _request_log: dict = defaultdict(list)
    print("Redis not found. Using in-memory rate limiter.")


def rate_limit(
    request: Request,
    max_requests: int = 10,
    window_seconds: int = 60,
):
    
    ip = request.client.host if request.client else "unknown"

    if USE_REDIS:
        try:
            key = f"ratelimit:{ip}"
            count = rcache.incr(key)
            if count == 1:
                rcache.expire(key, window_seconds)

            if count > max_requests:
                ttl = rcache.ttl(key)
                retry_after = ttl if ttl and ttl > 0 else window_seconds
                raise HTTPException(
                    status_code=429,
                    detail={
                        "error":       "Too many requests",
                        "message":     f"Maximum {max_requests} requests per "
                                       f"{window_seconds} seconds allowed.",
                        "retry_after": retry_after,
                    },
                    headers={"Retry-After": str(retry_after)},
                )
            return
        except HTTPException:
            raise
        except Exception as e:
            
            print(f"Rate limiter: Redis unavailable ({e}) — allowing request")
            return

    now = time.time()

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