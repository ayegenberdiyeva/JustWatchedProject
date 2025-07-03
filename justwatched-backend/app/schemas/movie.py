from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum
from datetime import datetime
from app.schemas.user import ReviewStatus

class MediaType(str, Enum):
    MOVIE = "movie"
    TV = "tv"

class Movie(BaseModel):
    movie_id: str
    title: str
    year: Optional[int] = None
    genres: Optional[List[str]] = None
    director: Optional[List[str]] = None
    cast: Optional[List[str]] = None
    description: Optional[str] = None
    poster_url: Optional[str] = None
    rating: Optional[float] = None

class Review(BaseModel):
    review_id: str
    user_id: str
    media_id: str
    media_type: MediaType = Field(..., description="Type of media being reviewed (movie or tv)")
    status: ReviewStatus = ReviewStatus.WATCHED
    rating: float = Field(..., ge=0, le=5)
    review_text: Optional[str] = None
    watched_date: Optional[datetime] = None
    media_title: Optional[str] = None
    poster_path: Optional[str] = None
    created_at: datetime
    updated_at: datetime

class ReviewCreate(BaseModel):
    media_id: str
    media_type: MediaType
    status: ReviewStatus = ReviewStatus.WATCHED
    rating: float = Field(..., ge=0, le=5)
    review_text: Optional[str] = None
    watched_date: Optional[datetime] = None
    media_title: Optional[str] = None
    poster_path: Optional[str] = None
    collections: Optional[List[str]] = None

class ReviewUpdate(BaseModel):
    status: Optional[ReviewStatus] = None
    rating: Optional[float] = Field(None, ge=0, le=5)
    review_text: Optional[str] = None
    watched_date: Optional[datetime] = None 