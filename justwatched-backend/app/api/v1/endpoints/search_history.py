from fastapi import APIRouter, Depends, HTTPException, Query, Path, status
from typing import Optional, List
from app.services.search_history_service import SearchHistoryService
from app.schemas.search import SearchHistoryResponse, SearchAnalytics, SearchHistoryRequest
from app.core.security import get_current_user
from app.api.v1.endpoints.movies import TMDB_BASE_URL, get_tmdb_search_endpoint
from app.core.config import settings
import httpx

router = APIRouter()
search_history_service = SearchHistoryService()

@router.get("/search-history", response_model=SearchHistoryResponse)
async def get_search_history(
    limit: int = Query(20, ge=1, le=100, description="Number of search entries to return"),
    offset: int = Query(0, ge=0, description="Number of entries to skip"),
    days_back: Optional[int] = Query(None, ge=1, le=365, description="Filter searches within last N days"),
    user=Depends(get_current_user)
):
    """Get user's search history with pagination and optional time filtering."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        return await search_history_service.get_user_search_history(
            user_id=user_id,
            limit=limit,
            offset=offset,
            days_back=days_back
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve search history: {str(e)}")

@router.post("/search-history/record")
async def record_search(
    search_data: SearchHistoryRequest,
    user=Depends(get_current_user)
):
    """Record a new search in user's history."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        search_entry = await search_history_service.record_search(
            user_id=user_id,
            query=search_data.query,
            result_count=search_data.result_count,
            search_type=search_data.search_type,
            session_id=search_data.session_id
        )
        return {
            "message": "Search recorded successfully",
            "search_id": search_entry.search_id,
            "timestamp": search_entry.timestamp
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to record search: {str(e)}")

@router.post("/search-history/{search_id}/click/{movie_id}")
async def record_movie_click(
    search_id: str = Path(..., description="ID of the search entry"),
    movie_id: str = Path(..., description="ID of the movie that was clicked"),
    user=Depends(get_current_user)
):
    """Record when a user clicks on a movie from search results."""
    try:
        success = await search_history_service.record_movie_click(search_id, movie_id)
        if success:
            return {"message": "Movie click recorded successfully"}
        else:
            raise HTTPException(status_code=404, detail="Search entry not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to record movie click: {str(e)}")

@router.delete("/search-history/{search_id}")
async def delete_search_entry(
    search_id: str = Path(..., description="ID of the search entry to delete"),
    user=Depends(get_current_user)
):
    """Delete a specific search entry from user's history."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        success = await search_history_service.delete_search_entry(user_id, search_id)
        if success:
            return {"message": "Search entry deleted successfully"}
        else:
            raise HTTPException(status_code=404, detail="Search entry not found or not owned by user")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete search entry: {str(e)}")

@router.delete("/search-history", status_code=status.HTTP_204_NO_CONTENT)
async def clear_search_history(
    days_back: Optional[int] = Query(None, ge=1, le=365, description="Clear searches within last N days only"),
    user=Depends(get_current_user)
):
    """Clear all or recent search history for the user."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        result = await search_history_service.clear_search_history(user_id, days_back)
        return None  # 204 No Content
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to clear search history: {str(e)}")

@router.get("/search-history/analytics", response_model=SearchAnalytics)
async def get_search_analytics(
    days_back: int = Query(30, ge=1, le=365, description="Number of days to analyze"),
    user=Depends(get_current_user)
):
    """Get analytics data for user's search patterns."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        return await search_history_service.get_search_analytics(user_id, days_back)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve search analytics: {str(e)}")

@router.get("/search-history/recent")
async def get_recent_searches(
    limit: int = Query(10, ge=1, le=50, description="Number of recent searches to return"),
    user=Depends(get_current_user)
):
    """Get user's most recent search queries for autocomplete suggestions."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        recent_searches = await search_history_service.get_recent_searches(user_id, limit)
        return {"recent_searches": recent_searches}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve recent searches: {str(e)}")

@router.get("/search-history/popular")
async def get_popular_searches(
    limit: int = Query(10, ge=1, le=50, description="Number of popular searches to return"),
    user=Depends(get_current_user)
):
    """Get user's most frequently searched terms."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        popular_searches = await search_history_service.get_popular_searches(user_id, limit)
        return {"popular_searches": popular_searches}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to retrieve popular searches: {str(e)}")

@router.get("/search-with-history")
async def search_with_history(
    query: str = Query(..., min_length=1, description="Search query"),
    search_type: str = Query("movie", description="Type of search: movie, tv, person, company, collection, keyword, multi"),
    session_id: Optional[str] = Query(None, description="Session ID for tracking"),
    user=Depends(get_current_user)
):
    """Search content and automatically record the search in history."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # First, perform the actual search using TMDB API
        tmdb_api_key = settings.TMDB_API_KEY
        if not tmdb_api_key:
            raise HTTPException(status_code=500, detail="TMDB_API_KEY not set in environment")
        
        # Handle multi-search differently
        if search_type.lower() == "multi":
            url = f"{TMDB_BASE_URL}/search/multi"
            params = {"api_key": tmdb_api_key, "query": query}
        else:
            # Get the appropriate endpoint for specific search type
            url = get_tmdb_search_endpoint(search_type)
            params = {"api_key": tmdb_api_key, "query": query}
        
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.text)
        
        search_results = resp.json()
        
        # Record the search in history
        result = await search_history_service.search_with_history_tracking(
            user_id=user_id,
            query=query,
            search_results=search_results.get("results", []),
            search_type=search_type,
            session_id=session_id
        )
        
        # Return both search results and history tracking info
        return {
            "search_id": result["search_id"],
            "query": result["query"],
            "timestamp": result["timestamp"],
            "total_results": result["total_results"],
            "results": search_results.get("results", []),
            "page": search_results.get("page", 1),
            "total_pages": search_results.get("total_pages", 1),
            "search_type": search_type
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}") 