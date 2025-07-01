from fastapi import APIRouter, HTTPException, Query, Path, Depends
import os
import httpx
from app.core.config import settings
from app.core.security import get_current_user
from app.services.search_history_service import SearchHistoryService
from typing import Optional

router = APIRouter()
search_history_service = SearchHistoryService()

TMDB_API_KEY = os.getenv("TMDB_API_KEY")
TMDB_BASE_URL = "https://api.themoviedb.org/3"

def get_tmdb_search_endpoint(search_type: str) -> str:
    """Get the appropriate TMDB search endpoint based on search type."""
    search_type = search_type.lower()
    if search_type in ["movie", "movies"]:
        return f"{TMDB_BASE_URL}/search/movie"
    elif search_type in ["tv", "tvshow", "tvshows", "series"]:
        return f"{TMDB_BASE_URL}/search/tv"
    elif search_type in ["person", "people", "actor", "actors", "director", "directors"]:
        return f"{TMDB_BASE_URL}/search/person"
    elif search_type in ["company", "companies"]:
        return f"{TMDB_BASE_URL}/search/company"
    elif search_type in ["collection", "collections"]:
        return f"{TMDB_BASE_URL}/search/collection"
    elif search_type in ["keyword", "keywords"]:
        return f"{TMDB_BASE_URL}/search/keyword"
    else:
        # Default to movie search
        return f"{TMDB_BASE_URL}/search/movie"

@router.get("/search")
async def search_movies(
    query: str = Query(..., min_length=1),
    search_type: str = Query("movie", description="Type of search: movie, tv, person, company, collection, keyword"),
    session_id: Optional[str] = Query(None, description="Session ID for tracking"),
    user=Depends(get_current_user)
):
    """Search movies, TV shows, people, or other content and record in search history."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    tmdb_api_key = settings.TMDB_API_KEY
    if not tmdb_api_key:
        raise HTTPException(status_code=500, detail="TMDB_API_KEY not set in environment")
    
    # Get the appropriate TMDB endpoint based on search type
    url = get_tmdb_search_endpoint(search_type)
    params = {"api_key": tmdb_api_key, "query": query}
    
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.text)
        
        search_results = resp.json()
        
        # Record the search in history
        await search_history_service.record_search(
            user_id=user_id,
            query=query,
            result_count=len(search_results.get("results", [])),
            search_type=search_type,
            session_id=session_id
        )
        
        return search_results
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@router.get("/search-anonymous")
async def search_movies_anonymous(
    query: str = Query(..., min_length=1),
    search_type: str = Query("movie", description="Type of search: movie, tv, person, company, collection, keyword")
):
    """Search content without recording in history (for anonymous users)."""
    tmdb_api_key = settings.TMDB_API_KEY
    if not tmdb_api_key:
        raise HTTPException(status_code=500, detail="TMDB_API_KEY not set in environment")
    
    # Get the appropriate TMDB endpoint based on search type
    url = get_tmdb_search_endpoint(search_type)
    params = {"api_key": tmdb_api_key, "query": query}
    
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, params=params)
    
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    
    return resp.json()

@router.get("/search-multi")
async def search_multi(
    query: str = Query(..., min_length=1),
    include_adult: bool = Query(False, description="Include adult content"),
    user=Depends(get_current_user)
):
    """Search across movies, TV shows, and people in a single request."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    tmdb_api_key = settings.TMDB_API_KEY
    if not tmdb_api_key:
        raise HTTPException(status_code=500, detail="TMDB_API_KEY not set in environment")
    
    url = f"{TMDB_BASE_URL}/search/multi"
    params = {
        "api_key": tmdb_api_key, 
        "query": query,
        "include_adult": include_adult
    }
    
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail=resp.text)
        
        search_results = resp.json()
        
        # Record the search in history as multi-search
        await search_history_service.record_search(
            user_id=user_id,
            query=query,
            result_count=len(search_results.get("results", [])),
            search_type="multi",
            session_id=None
        )
        
        return search_results
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Multi-search failed: {str(e)}")

@router.get("/{movie_id}")
async def get_movie_details(movie_id: int = Path(...)):
    if not TMDB_API_KEY:
        raise HTTPException(status_code=500, detail="TMDB_API_KEY not set in environment")
    url = f"{TMDB_BASE_URL}/movie/{movie_id}"
    params = {"api_key": TMDB_API_KEY}
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, params=params)
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    return resp.json()

@router.get("/healthcheck/tmdb")
async def tmdb_healthcheck():
    url = "https://api.themoviedb.org/3/configuration"
    headers = {"Authorization": f"Bearer {settings.TMDB_API_KEY}"}
    async with httpx.AsyncClient() as client:
        response = await client.get(url, headers=headers)
    if response.status_code == 200:
        return {"tmdb": "connected"}
    else:
        return {"tmdb": "error", "status_code": response.status_code, "detail": response.text}