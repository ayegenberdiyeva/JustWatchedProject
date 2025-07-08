from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Project Info
    PROJECT_NAME: str = "JustWatched"
    API_V1_STR: str = "/api/v1"

    # Firebase Configuration
    GOOGLE_APPLICATION_CREDENTIALS: str
    FIREBASE_API_KEY: str  # Firebase Web API Key for client operations

    # OpenAI Configuration
    # OPENAI_API_KEY: str

    # # OpenAI Assistant IDs
    # TASTE_PROFILER_ASSISTANT_ID: str
    # PERSONAL_RECOMMEDER_ASSISTABT_ID: str
    # ROOM_MODERATOR_ASSISTANT_ID: str
    # CREATIVE_ASSET_ASSISTANT_ID: str

    # JWT Settings
    JWT_SECRET_KEY: str = "supersecret"  # Should be overridden in production
    JWT_ALGORITHM: str = "HS256"
    JWT_AUDIENCE: str = "justwatched.app"
    JWT_ISSUER: str = "justwatched.api"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # External APIs
    TMDB_API_KEY: str

    # Celery Configuration
    CELERY_BROKER_URL: str = "redis://redis:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://redis:6379/0"

    AZURE_OPENAI_KEY: str
    AZURE_ENDPOINT: str
    AZURE_DEPLOYMENT_NAME: str
    AZURE_API_VERSION: str = "2024-12-01-preview"

settings = Settings() 