from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from app.crud.user_crud import UserCRUD
from app.crud.review_crud import ReviewCRUD
from app.core.security import get_current_user
from datetime import datetime
from app.api.v1.endpoints.movies import TMDB_BASE_URL
from app.core.config import settings
from app.schemas.movie import Review, MediaType
import httpx

router = APIRouter()
user_crud = UserCRUD()
review_crud = ReviewCRUD()

async def fetch_media_details(media_type: MediaType, media_id: str) -> dict:
    """Fetch media details from TMDB based on media type."""
    tmdb_api_key = settings.TMDB_API_KEY
    if not tmdb_api_key:
        raise HTTPException(status_code=500, detail="TMDB_API_KEY not set in environment")

    url = f"{TMDB_BASE_URL}/{media_type.value}/{media_id}"
    params = {"api_key": tmdb_api_key}
    
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, params=params)
    
    if resp.status_code == 404:
        raise HTTPException(status_code=404, detail=f"{media_type.value.title()} not found")
    elif resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    
    return resp.json()

@router.post("/reviews", response_model=Review)
async def post_review(
    review: Review,
    user=Depends(get_current_user)
):
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        review_data = review.dict()
        review_data["authorId"] = user_id

        # Fetch media details from TMDB
        media_details = await fetch_media_details(review.media_type, review.media_id)
        
        # Set title based on media type (movies use 'title', TV shows use 'name')
        review_data["media_title"] = media_details.get("title" if review.media_type == MediaType.MOVIE else "name")
        review_data["poster_path"] = media_details.get("poster_path")
        
        created_review = await review_crud.create_review(review_data)
        return created_review
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/users/me/reviews", response_model=List[Review])
async def get_my_reviews(user=Depends(get_current_user)):
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        reviews = await review_crud.get_reviews_by_user(user_id)
        # Ensure review_id is present for each review (for old data)
        for r in reviews:
            if "review_id" not in r and "id" in r:
                r["review_id"] = r["id"]
            # Ensure media_type is present for old reviews (default to movie)
            if "media_type" not in r:
                r["media_type"] = MediaType.MOVIE
            # Map old movie_id to media_id if necessary
            if "movie_id" in r and "media_id" not in r:
                r["media_id"] = r.pop("movie_id")
            # Map old movie_title to media_title if necessary
            if "movie_title" in r and "media_title" not in r:
                r["media_title"] = r.pop("movie_title")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return reviews 