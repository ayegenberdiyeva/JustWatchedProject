from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from app.schemas.movie import MediaType

class WatchlistItem(BaseModel):
    user_id: str
    media_id: str
    media_type: MediaType
    media_title: str
    poster_path: Optional[str] = None
    added_at: datetime

class WatchlistItemCreate(BaseModel):
    media_id: str
    media_type: MediaType
    media_title: str
    poster_path: Optional[str] = None

class WatchlistResponse(BaseModel):
    items: List[WatchlistItem]
    total_count: int

class WatchlistCheckResponse(BaseModel):
    media_id: str
    is_in_watchlist: bool 