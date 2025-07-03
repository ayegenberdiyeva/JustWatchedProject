from fastapi import APIRouter, Depends, HTTPException, status, Path, Query
from typing import List, Optional
from app.crud.user_crud import UserCRUD
from app.crud.review_crud import ReviewCRUD
from app.crud.friend_crud import FriendCRUD
from app.core.security import get_current_user
from datetime import datetime
from app.api.v1.endpoints.movies import TMDB_BASE_URL
from app.core.config import settings
from app.schemas.movie import Review, ReviewCreate, ReviewUpdate, MediaType
from app.schemas.user import ReviewStatus
import httpx

router = APIRouter()
user_crud = UserCRUD()
review_crud = ReviewCRUD()
friend_crud = FriendCRUD()

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

@router.post("/", response_model=Review)
async def post_review(
    review: ReviewCreate,
    user=Depends(get_current_user)
):
    """Create a new review."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        # Fetch media details from TMDB
        media_details = await fetch_media_details(review.media_type, review.media_id)
        
        # Set title based on media type (movies use 'title', TV shows use 'name')
        media_title = media_details.get("title" if review.media_type == MediaType.MOVIE else "name")
        poster_path = media_details.get("poster_path")
        
        # Create review with fetched details and collections
        review_data = ReviewCreate(
            media_id=review.media_id,
            media_type=review.media_type,
            status=review.status,
            rating=review.rating,
            review_text=review.review_text,
            watched_date=review.watched_date,
            media_title=media_title,
            poster_path=poster_path,
            collections=review.collections  # Pass through collections
        )
        
        created_review = await review_crud.create_review(user_id, review_data)
        return Review(**created_review)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create review: {str(e)}")

@router.get("/users/me/reviews", response_model=List[Review])
async def get_my_reviews(
    status_filter: Optional[ReviewStatus] = Query(None, description="Filter by review status"),
    user=Depends(get_current_user)
):
    """Get current user's reviews with optional status filtering."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        if status_filter:
            reviews = await review_crud.get_reviews_by_status(user_id, status_filter)
        else:
            reviews = await review_crud.get_reviews_by_user(user_id)
        
        # Convert to Review objects
        return [Review(**review) for review in reviews]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get reviews: {str(e)}")

@router.get("/users/{user_id}/reviews", response_model=List[Review])
async def get_user_reviews(
    user_id: str = Path(..., description="ID of the user to get reviews for"),
    status_filter: Optional[ReviewStatus] = Query(None, description="Filter by review status"),
    current_user=Depends(get_current_user)
):
    """Get reviews by another user (respecting privacy settings)."""
    current_user_id = current_user["sub"] if isinstance(current_user, dict) else current_user.sub
    
    try:
        # Check if target user exists
        target_user = await user_crud.get_user_profile(user_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Check if current user can view target user's reviews
        if current_user_id != user_id:
            # Check if they are friends
            are_friends = await friend_crud.are_friends(current_user_id, user_id)
            if not are_friends:
                raise HTTPException(status_code=403, detail="You can only view reviews of users you're friends with")
        
        # Get reviews with privacy filtering
        if status_filter:
            reviews = await review_crud.get_reviews_by_status(user_id, status_filter)
        else:
            reviews = await review_crud.get_reviews_by_user(user_id, current_user_id)
        
        # Convert to Review objects
        return [Review(**review) for review in reviews]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get user reviews: {str(e)}")

@router.get("/{review_id}", response_model=Review)
async def get_review(
    review_id: str = Path(..., description="ID of the review"),
    current_user=Depends(get_current_user)
):
    """Get a specific review by ID."""
    current_user_id = current_user["sub"] if isinstance(current_user, dict) else current_user.sub
    
    try:
        review = await review_crud.get_review(review_id)
        if not review:
            raise HTTPException(status_code=404, detail="Review not found")
        
        # Check if current user can view this review
        if review["user_id"] != current_user_id:
            # Check if they are friends
            are_friends = await friend_crud.are_friends(current_user_id, review["user_id"])
            if not are_friends:
                raise HTTPException(status_code=403, detail="You can only view reviews of users you're friends with")
        
        return Review(**review)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get review: {str(e)}")

@router.put("/{review_id}", response_model=Review)
async def update_review(
    review_id: str = Path(..., description="ID of the review"),
    update_data: ReviewUpdate = None,
    user=Depends(get_current_user)
):
    """Update a review."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        updated_review = await review_crud.update_review(review_id, user_id, update_data)
        if not updated_review:
            raise HTTPException(status_code=404, detail="Review not found or access denied")
        
        return Review(**updated_review)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update review: {str(e)}")

@router.delete("/{review_id}")
async def delete_review(
    review_id: str = Path(..., description="ID of the review"),
    user=Depends(get_current_user)
):
    """Delete a review."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        success = await review_crud.delete_review(review_id, user_id)
        if not success:
            raise HTTPException(status_code=404, detail="Review not found or access denied")
        
        return {"message": "Review deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete review: {str(e)}")

@router.get("/media/{media_type}/{media_id}/reviews", response_model=List[Review])
async def get_media_reviews(
    media_type: MediaType = Path(..., description="Type of media"),
    media_id: str = Path(..., description="ID of the media"),
    current_user=Depends(get_current_user)
):
    """Get all reviews for a specific media item (respecting privacy settings)."""
    current_user_id = current_user["sub"] if isinstance(current_user, dict) else current_user.sub
    
    try:
        reviews = await review_crud.get_reviews_by_media(media_id, media_type.value, current_user_id)
        
        # Convert to Review objects
        return [Review(**review) for review in reviews]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get media reviews: {str(e)}") 