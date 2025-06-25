from fastapi import APIRouter, HTTPException, Query, Path
import os
import httpx
from app.core.config import settings

router = APIRouter()

TMDB_API_KEY = os.getenv("TMDB_API_KEY")
TMDB_BASE_URL = "https://api.themoviedb.org/3"

@router.get("/search")
async def search_movies(query: str = Query(..., min_length=1)):
    tmdb_api_key = settings.TMDB_API_KEY
    if not tmdb_api_key:
        raise HTTPException(status_code=500, detail="TMDB_API_KEY not set in environment")
    url = f"{TMDB_BASE_URL}/search/movie"
    params = {"api_key": tmdb_api_key, "query": query}
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, params=params)
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    return resp.json()

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