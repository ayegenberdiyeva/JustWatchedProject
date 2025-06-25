from typing import List, Dict, Any
from app.core.firestore import get_firestore_client, run_in_threadpool
from datetime import datetime

class ReviewCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.reviews_col = self.db.collection("reviews")

    async def create_review(self, data: Dict[str, Any]) -> Dict[str, Any]:
        data = dict(data)
        data["created_at"] = datetime.utcnow().isoformat()
        # Temporarily add a placeholder for review_id
        data["review_id"] = "temp"
        doc_ref = await run_in_threadpool(lambda: self.reviews_col.add(data))
        review_id = doc_ref[1].id
        # Update the document to set the correct review_id
        await run_in_threadpool(lambda: self.reviews_col.document(review_id).update({"review_id": review_id}))
        data["review_id"] = review_id
        return data

    async def get_review_by_id(self, review_id: str) -> Dict[str, Any]:
        doc = await run_in_threadpool(lambda: self.reviews_col.document(review_id).get())
        if doc.exists:
            review = doc.to_dict()
            review["review_id"] = review_id
            if "createdAt" in review and "created_at" not in review:
                review["created_at"] = review["createdAt"]
            return review
        return None

    async def get_reviews_by_user(self, user_id: str) -> List[Dict[str, Any]]:
        def fetch():
            query = self.reviews_col.where("authorId", "==", user_id).stream()
            reviews = []
            for doc in query:
                if doc.exists:
                    review = doc.to_dict()
                    review["review_id"] = doc.id
                    if "createdAt" in review and "created_at" not in review:
                        review["created_at"] = review["createdAt"]
                    reviews.append(review)
            return reviews
        return await run_in_threadpool(fetch)

    async def get_reviews_by_movie_and_authors(self, movie_id: int, author_ids: List[str]) -> List[Dict[str, Any]]:
        def fetch():
            query = self.reviews_col.where("movieId", "==", movie_id).where("authorId", "in", author_ids).stream()
            reviews = []
            for doc in query:
                if doc.exists:
                    review = doc.to_dict()
                    review["review_id"] = doc.id
                    if "createdAt" in review and "created_at" not in review:
                        review["created_at"] = review["createdAt"]
                    reviews.append(review)
            return reviews
        return await run_in_threadpool(fetch) 