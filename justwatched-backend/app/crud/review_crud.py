from typing import List, Dict, Any
from app.core.firestore import get_firestore_client, run_in_threadpool
from datetime import datetime
import uuid

class ReviewCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.collection = self.db.collection('reviews')

    async def create_review(self, review_data: dict) -> dict:
        """Create a new review."""
        review_id = str(uuid.uuid4())
        review_data["review_id"] = review_id
        review_data["created_at"] = datetime.utcnow().isoformat()
        
        # Convert media_type enum to string if present
        if "media_type" in review_data and hasattr(review_data["media_type"], "value"):
            review_data["media_type"] = review_data["media_type"].value

        doc_ref = self.collection.document(review_id)
        doc_ref.set(review_data)
        return review_data

    async def get_reviews_by_user(self, user_id: str) -> list:
        """Get all reviews by a specific user."""
        docs = self.collection.where("authorId", "==", user_id).stream()
        reviews = []
        for doc in docs:
            review = doc.to_dict()
            # Ensure review_id is set
            if "review_id" not in review:
                review["review_id"] = doc.id
            reviews.append(review)
        return reviews

    async def get_review(self, review_id: str) -> dict:
        """Get a specific review by ID."""
        doc_ref = self.collection.document(review_id)
        doc = doc_ref.get()
        if doc.exists:
            review = doc.to_dict()
            review["review_id"] = doc.id
            return review
        return None

    async def update_review(self, review_id: str, review_data: dict) -> dict:
        """Update a review."""
        # Convert media_type enum to string if present
        if "media_type" in review_data and hasattr(review_data["media_type"], "value"):
            review_data["media_type"] = review_data["media_type"].value
            
        doc_ref = self.collection.document(review_id)
        doc_ref.update(review_data)
        updated = await self.get_review(review_id)
        return updated

    async def delete_review(self, review_id: str) -> bool:
        """Delete a review."""
        doc_ref = self.collection.document(review_id)
        doc = doc_ref.get()
        if doc.exists:
            doc_ref.delete()
            return True
        return False

    async def get_reviews_by_media(self, media_id: str, media_type: str) -> list:
        """Get all reviews for a specific media item."""
        # Try new schema first
        docs = self.collection.where("media_id", "==", media_id).where("media_type", "==", media_type).stream()
        reviews = [doc.to_dict() for doc in docs]
        
        # If no results and media_type is movie, try old schema (backward compatibility)
        if not reviews and media_type == "movie":
            docs = self.collection.where("movie_id", "==", media_id).stream()
            reviews = []
            for doc in docs:
                review = doc.to_dict()
                # Convert old schema to new schema
                if "movie_id" in review:
                    review["media_id"] = review.pop("movie_id")
                if "movie_title" in review:
                    review["media_title"] = review.pop("movie_title")
                review["media_type"] = "movie"
                reviews.append(review)
        
        return reviews

    async def get_reviews_by_movie_and_authors(self, movie_id: int, author_ids: List[str]) -> List[Dict[str, Any]]:
        def fetch():
            docs = self.collection.where("movie_id", "==", movie_id).where("authorId", "in", author_ids).stream()
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