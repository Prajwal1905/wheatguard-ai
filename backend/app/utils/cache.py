# utils/cache.py
import time
import os


USE_REDIS = os.getenv("REDIS_URL") is not None

if USE_REDIS:
    import redis
    rcache = redis.Redis.from_url(os.getenv("REDIS_URL"))
else:
    rcache = {}
    print(" Redis not found. Using in-memory cache.")


def cache_get(key):
    if USE_REDIS:
        val = rcache.get(key)
        return float(val) if val else None
    return rcache.get(key)


def cache_set(key, value, ttl=86400):
    if USE_REDIS:
        rcache.set(key, value, ex=ttl)
    else:
        rcache[key] = value
