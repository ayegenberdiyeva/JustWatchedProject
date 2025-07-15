from fastapi import APIRouter, Depends, HTTPException, Path
from typing import List, Optional
from app.crud.collection_crud import CollectionCRUD
from app.crud.review_crud import ReviewCRUD
from app.core.security import get_current_user
from app.schemas.user import CollectionCreate, CollectionUpdate, CollectionVisibility
from pydantic import BaseModel

router = APIRouter()
collection_crud = CollectionCRUD()
review_crud = ReviewCRUD()

class CollectionResponse(BaseModel):
    collection_id: str
    user_id: str
    name: str
    description: Optional[str] = None
    visibility: str
    created_at: str
    updated_at: str
    review_count: int
    auto_select: bool = False  # Flag for frontend to auto-select newly created collections

class CollectionListResponse(BaseModel):
    collections: List[CollectionResponse]
    total_count: int

class UserCollectionReview(BaseModel):
    review_id: str
    media_id: str
    media_title: str
    media_type: str
    poster_path: Optional[str] = None
    rating: Optional[int] = None
    review_text: Optional[str] = None
    watched_date: Optional[str] = None
    status: str
    created_at: str
    updated_at: str

class UserCollectionWithReviews(BaseModel):
    collection_id: str
    name: str
    description: Optional[str] = None
    visibility: str
    review_count: int
    reviews: List[UserCollectionReview]

class UserCollectionsReviewsResponse(BaseModel):
    collections: List[UserCollectionWithReviews]
    total_collections: int
    total_reviews: int

@router.post("/", response_model=CollectionResponse)
async def create_collection(
    collection_data: CollectionCreate,
    user=Depends(get_current_user)
):
    """Create a new collection for the current user."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        collection_id = await collection_crud.create_collection(user_id, collection_data)
        collection = await collection_crud.get_collection_by_id(collection_id)
        
        if not collection:
            raise HTTPException(status_code=500, detail="Failed to create collection")
        
        # Add auto_select flag for frontend
        collection["auto_select"] = True
        
        return CollectionResponse(**collection)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create collection: {str(e)}")

@router.get("/", response_model=CollectionListResponse)
async def get_my_collections(
    include_private: bool = True,
    user=Depends(get_current_user)
):
    """Get all collections for the current user."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        collections = await collection_crud.get_user_collections(user_id, include_private)
        
        collection_responses = [
            CollectionResponse(**collection) for collection in collections
        ]
        
        return CollectionListResponse(
            collections=collection_responses,
            total_count=len(collection_responses)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get collections: {str(e)}")

@router.get("/me/reviews", response_model=UserCollectionsReviewsResponse)
async def get_my_reviews_by_collections(
    include_private: bool = True,
    user=Depends(get_current_user)
):
    """Get the authenticated user's reviews organized by their collections."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Get user's collections
        collections = await collection_crud.get_user_collections(user_id, include_private=include_private)
        
        collections_with_reviews = []
        total_reviews = 0
        
        for collection in collections:
            # Get review IDs in this collection
            review_ids = await collection_crud.get_collection_reviews(collection["collection_id"])
            
            # Get full review details
            reviews = []
            for review_id in review_ids:
                review = await review_crud.get_review(review_id)
                if review:
                    # Convert datetime fields
                    if "created_at" in review and hasattr(review["created_at"], "isoformat"):
                        review["created_at"] = review["created_at"].isoformat()
                    if "updated_at" in review and hasattr(review["updated_at"], "isoformat"):
                        review["updated_at"] = review["updated_at"].isoformat()
                    
                    reviews.append(UserCollectionReview(**review))
            
            collections_with_reviews.append(UserCollectionWithReviews(
                collection_id=collection["collection_id"],
                name=collection["name"],
                description=collection.get("description"),
                visibility=collection["visibility"],
                review_count=len(reviews),
                reviews=reviews
            ))
            
            total_reviews += len(reviews)
        
        return UserCollectionsReviewsResponse(
            collections=collections_with_reviews,
            total_collections=len(collections_with_reviews),
            total_reviews=total_reviews
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get user's reviews by collections: {str(e)}")

@router.get("/{collection_id}", response_model=CollectionResponse)
async def get_collection(
    collection_id: str = Path(..., description="ID of the collection"),
    user=Depends(get_current_user)
):
    """Get a specific collection by ID."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        collection = await collection_crud.get_collection_by_id(collection_id)
        
        if not collection:
            raise HTTPException(status_code=404, detail="Collection not found")
        
        # Check if user owns the collection or if it's visible to them
        if collection["user_id"] != user_id and collection["visibility"] == CollectionVisibility.PRIVATE:
            raise HTTPException(status_code=403, detail="Access denied")
        
        return CollectionResponse(**collection)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get collection: {str(e)}")

@router.put("/{collection_id}", response_model=CollectionResponse)
async def update_collection(
    collection_id: str = Path(..., description="ID of the collection"),
    update_data: CollectionUpdate = None,
    user=Depends(get_current_user)
):
    """Update a collection."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Check ownership
        collection = await collection_crud.get_collection_by_id(collection_id)
        if not collection:
            raise HTTPException(status_code=404, detail="Collection not found")
        
        if collection["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="You can only update your own collections")
        
        success = await collection_crud.update_collection(collection_id, update_data)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to update collection")
        
        updated_collection = await collection_crud.get_collection_by_id(collection_id)
        return CollectionResponse(**updated_collection)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update collection: {str(e)}")

@router.delete("/{collection_id}")
async def delete_collection(
    collection_id: str = Path(..., description="ID of the collection"),
    user=Depends(get_current_user)
):
    """Delete a collection."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Check ownership
        collection = await collection_crud.get_collection_by_id(collection_id)
        if not collection:
            raise HTTPException(status_code=404, detail="Collection not found")
        
        if collection["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="You can only delete your own collections")
        
        success = await collection_crud.delete_collection(collection_id)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to delete collection")
        
        return {"message": "Collection deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete collection: {str(e)}")

@router.post("/{collection_id}/reviews/{review_id}")
async def add_review_to_collection(
    collection_id: str = Path(..., description="ID of the collection"),
    review_id: str = Path(..., description="ID of the review"),
    user=Depends(get_current_user)
):
    """Add a review to a collection."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Check collection ownership
        collection = await collection_crud.get_collection_by_id(collection_id)
        if not collection:
            raise HTTPException(status_code=404, detail="Collection not found")
        
        if collection["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="You can only add reviews to your own collections")
        
        # Check if review exists and belongs to user
        review = await review_crud.get_review(review_id)
        if not review:
            raise HTTPException(status_code=404, detail="Review not found")
        
        if review["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="You can only add your own reviews to collections")
        
        success = await collection_crud.add_review_to_collection(review_id, collection_id)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to add review to collection")
        
        return {"message": "Review added to collection successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to add review to collection: {str(e)}")

@router.delete("/{collection_id}/reviews/{review_id}")
async def remove_review_from_collection(
    collection_id: str = Path(..., description="ID of the collection"),
    review_id: str = Path(..., description="ID of the review"),
    user=Depends(get_current_user)
):
    """Remove a review from a collection."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Check collection ownership
        collection = await collection_crud.get_collection_by_id(collection_id)
        if not collection:
            raise HTTPException(status_code=404, detail="Collection not found")
        
        if collection["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="You can only remove reviews from your own collections")
        
        success = await collection_crud.remove_review_from_collection(review_id, collection_id)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to remove review from collection")
        
        return {"message": "Review removed from collection successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to remove review from collection: {str(e)}")

@router.get("/{collection_id}/reviews")
async def get_collection_reviews(
    collection_id: str = Path(..., description="ID of the collection"),
    user=Depends(get_current_user)
):
    """Get all reviews in a collection."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Check collection access
        collection = await collection_crud.get_collection_by_id(collection_id)
        if not collection:
            raise HTTPException(status_code=404, detail="Collection not found")
        
        # Check if user can access the collection
        if collection["user_id"] != user_id and collection["visibility"] == CollectionVisibility.PRIVATE:
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Get review IDs in collection
        review_ids = await collection_crud.get_collection_reviews(collection_id)
        
        # Get full review details
        reviews = []
        for review_id in review_ids:
            review = await review_crud.get_review(review_id)
            if review:
                reviews.append(review)
        
        return {
            "collection_id": collection_id,
            "collection_name": collection["name"],
            "reviews": reviews,
            "total_count": len(reviews)
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get collection reviews: {str(e)}") 