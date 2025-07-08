from celery import Celery
from celery.schedules import crontab
from app.core.config import settings

celery_app = Celery(
    "justwatched",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=['app.tasks.recommendation_tasks']  # Include tasks without circular import
)
celery_app.conf.update(task_track_started=True)

celery_app.conf.beat_schedule = {
    'refresh-recommendations-for-all-users': {
        'task': 'tasks.refresh_recommendations_for_all_users',
        'schedule': crontab(hour=3, minute=0),
    },
}