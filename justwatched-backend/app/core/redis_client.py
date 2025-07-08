import redis
from app.core.config import settings

# Create Redis client instance
redis_client = redis.Redis.from_url(settings.CELERY_RESULT_BACKEND) 