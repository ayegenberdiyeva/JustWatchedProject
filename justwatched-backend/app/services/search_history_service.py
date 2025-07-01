from typing import List, Dict, Any, Optional
from app.crud.search_history_crud import SearchHistoryCRUD
from app.schemas.search import SearchHistoryEntry, SearchHistoryRequest, SearchHistoryResponse, SearchAnalytics
from datetime import datetime

class SearchHistoryService:
    """
    Business logic layer for search history operations.
    """
    def __init__(self, search_history_crud: SearchHistoryCRUD = SearchHistoryCRUD()):
        self.search_history_crud = search_history_crud

    async def record_search(
        self, 
        user_id: str, 
        query: str, 
        result_count: Optional[int] = None,
        search_type: str = "movie",
        session_id: Optional[str] = None
    ) -> SearchHistoryEntry:
        """Record a new search in user's history."""
        search_data = SearchHistoryRequest(
            query=query,
            result_count=result_count,
            search_type=search_type,
            session_id=session_id
        )
        return await self.search_history_crud.create_search_entry(user_id, search_data)

    async def get_user_search_history(
        self, 
        user_id: str, 
        limit: int = 20, 
        offset: int = 0,
        days_back: Optional[int] = None
    ) -> SearchHistoryResponse:
        """Get paginated search history for a user."""
        searches = await self.search_history_crud.get_user_search_history(
            user_id, limit, offset, days_back
        )
        
        total_count = await self.search_history_crud.get_total_search_count(user_id, days_back)
        has_more = (offset + limit) < total_count
        
        return SearchHistoryResponse(
            searches=searches,
            total_count=total_count,
            has_more=has_more
        )

    async def record_movie_click(self, search_id: str, movie_id: str) -> bool:
        """Record when a user clicks on a movie from search results."""
        return await self.search_history_crud.update_clicked_results(search_id, movie_id)

    async def delete_search_entry(self, user_id: str, search_id: str) -> bool:
        """Delete a specific search entry."""
        return await self.search_history_crud.delete_search_entry(user_id, search_id)

    async def clear_search_history(
        self, 
        user_id: str, 
        days_back: Optional[int] = None
    ) -> Dict[str, Any]:
        """Clear user's search history, optionally within a time range."""
        deleted_count = await self.search_history_crud.clear_user_search_history(user_id, days_back)
        
        return {
            "message": f"Successfully deleted {deleted_count} search entries",
            "deleted_count": deleted_count,
            "user_id": user_id
        }

    async def get_search_analytics(self, user_id: str, days_back: int = 30) -> SearchAnalytics:
        """Get analytics data for user's search patterns."""
        analytics_data = await self.search_history_crud.get_search_analytics(user_id, days_back)
        return SearchAnalytics(**analytics_data)

    async def get_recent_searches(self, user_id: str, limit: int = 10) -> List[str]:
        """Get user's most recent search queries for autocomplete suggestions."""
        searches = await self.search_history_crud.get_user_search_history(user_id, limit=limit)
        return [search.query for search in searches]

    async def get_popular_searches(self, user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Get user's most frequently searched terms."""
        analytics = await self.get_search_analytics(user_id, days_back=30)
        return analytics.most_searched_terms[:limit]

    async def search_with_history_tracking(
        self, 
        user_id: str, 
        query: str, 
        search_results: List[Dict[str, Any]],
        search_type: str = "movie",
        session_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Perform a search and automatically record it in history.
        This method combines search functionality with history tracking.
        """
        # Record the search
        search_entry = await self.record_search(
            user_id=user_id,
            query=query,
            result_count=len(search_results),
            search_type=search_type,
            session_id=session_id
        )
        
        return {
            "search_id": search_entry.search_id,
            "results": search_results,
            "total_results": len(search_results),
            "query": query,
            "timestamp": search_entry.timestamp
        } 