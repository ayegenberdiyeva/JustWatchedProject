from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import List, Optional
from app.crud.user_crud import UserCRUD
from app.crud.review_crud import ReviewCRUD
from app.core.security import get_current_user
from datetime import datetime
from app.api.v1.endpoints.movies import TMDB_BASE_URL
from app.core.config import settings
import httpx

router = APIRouter()
user_crud = UserCRUD()
review_crud = ReviewCRUD()

class ReviewRequest(BaseModel):
    movie_id: str
    rating: float = Field(..., ge=0, le=5)
    review_text: Optional[str] = None
    watched_date: Optional[datetime] = None
    movie_title: Optional[str] = None
    poster_path: Optional[str] = None

class ReviewResponse(BaseModel):
    review_id: str
    movie_id: str
    rating: float
    review_text: Optional[str] = None
    watched_date: Optional[datetime] = None
    authorId: str
    created_at: Optional[str] = None
    movie_title: Optional[str] = None
    poster_path: Optional[str] = None

@router.post("/reviews", response_model=ReviewResponse)
async def post_review(
    review: ReviewRequest,
    user=Depends(get_current_user)
):
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        review_data = review.dict()
        review_data["authorId"] = user_id
        # Fetch movie details from TMDB
        tmdb_api_key = settings.TMDB_API_KEY
        url = f"{TMDB_BASE_URL}/movie/{review.movie_id}"
        params = {"api_key": tmdb_api_key}
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        if resp.status_code == 200:
            movie = resp.json()
            review_data["movie_title"] = movie.get("title")
            review_data["poster_path"] = movie.get("poster_path")
        created_review = await review_crud.create_review(review_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return created_review

@router.get("/users/me/reviews", response_model=List[ReviewResponse])
async def get_my_reviews(user=Depends(get_current_user)):
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        reviews = await review_crud.get_reviews_by_user(user_id)
        # Ensure review_id is present for each review (for old data)
        for r in reviews:
            if "review_id" not in r and "id" in r:
                r["review_id"] = r["id"]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return reviews 