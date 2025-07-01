from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

class SearchQuery(BaseModel):
    """Individual search query entry"""
    query: str = Field(..., min_length=1, max_length=200)
    timestamp: datetime
    result_count: Optional[int] = None
    search_type: str = Field(default="movie", description="Type of search: movie, actor, director, etc.")

class SearchHistoryEntry(BaseModel):
    """Complete search history entry with metadata"""
    search_id: str
    user_id: str
    query: str = Field(..., min_length=1, max_length=200)
    timestamp: datetime
    result_count: Optional[int] = None
    search_type: str = Field(default="movie", description="Type of search: movie, actor, director, etc.")
    clicked_results: Optional[List[str]] = Field(default_factory=list, description="List of movie IDs that user clicked on")
    session_id: Optional[str] = None

class SearchHistoryResponse(BaseModel):
    """Response model for search history"""
    searches: List[SearchHistoryEntry]
    total_count: int
    has_more: bool = False

class SearchHistoryRequest(BaseModel):
    """Request model for creating search history entry"""
    query: str = Field(..., min_length=1, max_length=200)
    result_count: Optional[int] = None
    search_type: str = Field(default="movie")
    clicked_results: Optional[List[str]] = Field(default_factory=list)
    session_id: Optional[str] = None

class SearchAnalytics(BaseModel):
    """Analytics data for search patterns"""
    total_searches: int
    unique_queries: int
    most_searched_terms: List[dict]
    search_frequency_by_day: List[dict]
    average_results_per_search: float 