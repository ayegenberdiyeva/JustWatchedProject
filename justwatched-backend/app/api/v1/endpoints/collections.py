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