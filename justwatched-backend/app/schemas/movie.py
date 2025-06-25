from pydantic import BaseModel
from typing import List, Optional

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