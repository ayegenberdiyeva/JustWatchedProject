from typing import List, Dict, Any, Optional
from app.core.firestore import get_firestore_client, run_in_threadpool
from app.schemas.movie import Review, ReviewCreate, ReviewUpdate
from app.schemas.user import ReviewStatus
from app.crud.collection_crud import CollectionCRUD
from datetime import datetime
import uuid

class ReviewCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.collection = self.db.collection('reviews')
        self.collection_crud = CollectionCRUD()

    async def create_review(self, user_id: str, review_data: ReviewCreate) -> dict:
        """Create a new review with optional collection associations."""
        review_id = str(uuid.uuid4())
        now = datetime.utcnow()
        
        review = Review(
            review_id=review_id,
            user_id=user_id,
            media_id=review_data.media_id,
            media_type=review_data.media_type,
            status=review_data.status,
            rating=review_data.rating,
            review_text=review_data.review_text,
            watched_date=review_data.watched_date,
            media_title=review_data.media_title,
            poster_path=review_data.poster_path,
            created_at=now,
            updated_at=now
        )
        
        # Save the review
        await run_in_threadpool(lambda: self.collection.document(review_id).set(review.dict()))
        
        # Handle collection associations if provided
        if review_data.collections:
            for collection_id in review_data.collections:
                # Verify collection ownership
                collection = await self.collection_crud.get_collection_by_id(collection_id)
                if collection and collection["user_id"] == user_id:
                    await self.collection_crud.add_review_to_collection(review_id, collection_id)
        
        return review.dict()

    async def get_reviews_by_user(self, user_id: str, viewer_id: Optional[str] = None) -> list:
        """Get all reviews by a specific user, respecting privacy settings."""
        def fetch():
            docs = self.collection.where("user_id", "==", user_id).stream()
            reviews = []
            for doc in docs:
                if doc.exists:
                    review = doc.to_dict()
                    # Ensure review_id is set
                    if "review_id" not in review:
                        review["review_id"] = doc.id
                    reviews.append(review)
            return reviews
        
        reviews = await run_in_threadpool(fetch)
        
        # If viewer is not the author, we need to check privacy settings
        if viewer_id and viewer_id != user_id:
            # TODO: Implement privacy filtering based on friend status and collection visibility
            # For now, return all reviews (this should be enhanced with privacy logic)
            pass
        
        return reviews

    async def get_review(self, review_id: str) -> Optional[dict]:
        """Get a specific review by ID."""
        doc = await run_in_threadpool(lambda: self.collection.document(review_id).get())
        if doc.exists:
            review = doc.to_dict()
            review["review_id"] = doc.id
            return review
        return None

    async def update_review(self, review_id: str, user_id: str, review_data: ReviewUpdate) -> Optional[dict]:
        """Update a review."""
        try:
            # Verify ownership
            doc = await run_in_threadpool(lambda: self.collection.document(review_id).get())
            if not doc.exists:
                return None
            
            existing_review = doc.to_dict()
            if existing_review.get("user_id") != user_id:
                return None
            
            # Update fields
            update_dict = review_data.dict(exclude_unset=True)
            update_dict["updated_at"] = datetime.utcnow()
            
            await run_in_threadpool(lambda: self.collection.document(review_id).update(update_dict))
            
            # Return updated review
            return await self.get_review(review_id)
        except Exception:
            return None

    async def delete_review(self, review_id: str, user_id: str) -> bool:
        """Delete a review."""
        try:
            # Verify ownership
            doc = await run_in_threadpool(lambda: self.collection.document(review_id).get())
            if not doc.exists:
                return False
            
            existing_review = doc.to_dict()
            if existing_review.get("user_id") != user_id:
                return False
            
            await run_in_threadpool(lambda: self.collection.document(review_id).delete())
            return True
        except Exception:
            return False

    async def get_reviews_by_media(self, media_id: str, media_type: str, viewer_id: Optional[str] = None) -> list:
        """Get all reviews for a specific media item, respecting privacy settings."""
        def fetch():
            docs = self.collection.where("media_id", "==", media_id).where("media_type", "==", media_type).stream()
            reviews = [doc.to_dict() for doc in docs if doc.exists]
            
            # If no results and media_type is movie, try old schema (backward compatibility)
            if not reviews and media_type == "movie":
                docs = self.collection.where("movie_id", "==", media_id).stream()
                reviews = []
                for doc in docs:
                    if doc.exists:
                        review = doc.to_dict()
                        # Convert old schema to new schema
                        if "movie_id" in review:
                            review["media_id"] = review.pop("movie_id")
                        if "movie_title" in review:
                            review["media_title"] = review.pop("movie_title")
                        review["media_type"] = "movie"
                        reviews.append(review)
            
            return reviews
        
        reviews = await run_in_threadpool(fetch)
        
        # TODO: Implement privacy filtering based on friend status and collection visibility
        # For now, return all reviews (this should be enhanced with privacy logic)
        
        return reviews

    async def get_reviews_by_status(self, user_id: str, status: ReviewStatus) -> list:
        """Get all reviews by a user with a specific status (watched/watchlist)."""
        def fetch():
            docs = self.collection.where("user_id", "==", user_id).where("status", "==", status.value).stream()
            reviews = []
            for doc in docs:
                if doc.exists:
                    review = doc.to_dict()
                    if "review_id" not in review:
                        review["review_id"] = doc.id
                    reviews.append(review)
            return reviews
        
        return await run_in_threadpool(fetch)

    async def get_reviews_by_movie_and_authors(self, movie_id: int, author_ids: List[str]) -> List[Dict[str, Any]]:
        def fetch():
            docs = self.collection.where("movie_id", "==", movie_id).where("user_id", "in", author_ids).stream()
            reviews = []
            for doc in docs:
                if doc.exists:
                    review = doc.to_dict()
                    review["review_id"] = doc.id
                    if "createdAt" in review and "created_at" not in review:
                        review["created_at"] = review["createdAt"]
                    reviews.append(review)
            return reviews
        return await run_in_threadpool(fetch) 