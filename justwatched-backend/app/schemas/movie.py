from pydantic import BaseModel, Field
from typing import List, Optional
from enum import Enum
from datetime import datetime

class MediaType(str, Enum):
    MOVIE = "movie"
    TV = "tv"

class Movie(BaseModel):
    movie_id: str
    title: str
    year: Optional[int] = None
    genres: Optional[List[str]] = None
    director: Optional[str] = None
    cast: Optional[List[str]] = None
    description: Optional[str] = None
    poster_url: Optional[str] = None
    rating: Optional[float] = None

class Review(BaseModel):
    media_id: str
    media_type: MediaType = Field(..., description="Type of media being reviewed (movie or tv)")
    rating: float = Field(..., ge=0, le=5)
    review_text: Optional[str] = None
    watched_date: Optional[datetime] = None
    media_title: Optional[str] = None
    poster_path: Optional[str] = None 