# utils/cache.py
import os


USE_REDIS = os.getenv("REDIS_URL") is not None

if USE_REDIS:
    import redis
    rcache = redis.Redis.from_url(os.getenv("REDIS_URL"))
else:
    rcache = {}
    print("Redis not found. Using in-memory cache.")


def cache_get(key):
    if USE_REDIS:
        try:
            val = rcache.get(key)
            return float(val) if val else None
        except Exception as e:
            
            print(f"Cache: Redis unavailable on get ({e}) — treating as cache miss")
            return None
    return rcache.get(key)


def cache_set(key, value, ttl=86400):
    if USE_REDIS:
        try:
            rcache.set(key, value, ex=ttl)
        except Exception as e:
           
            print(f"Cache: Redis unavailable on set ({e}) — skipping cache")
    else:
        rcache[key] = value