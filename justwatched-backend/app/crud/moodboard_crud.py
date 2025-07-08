from typing import List, Dict, Any, Optional
from app.core.firestore import get_firestore_client, run_in_threadpool
from datetime import datetime

class MoodboardCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.moodboards_col = self.db.collection("moodboards")

    async def create_moodboard(self, data: Dict[str, Any]) -> str:
        data = dict(data)
        data["createdAt"] = datetime.utcnow().isoformat()
        doc_ref = await run_in_threadpool(lambda: self.moodboards_col.add(data))
        return doc_ref[1].id

    async def get_moodboards_by_user(self, user_id: str) -> List[Dict[str, Any]]:
        def fetch():
            query = self.moodboards_col.where("authorId", "==", user_id).stream()
            return [doc.to_dict() for doc in query if doc.exists]
        return await run_in_threadpool(fetch)

    async def save_moodboard(self, movie_id: int, moodboard_data: Dict[str, Any]) -> bool:
        """Save moodboard data for a specific movie."""
        try:
            data = dict(moodboard_data)
            data["movie_id"] = movie_id
            data["created_at"] = datetime.utcnow().isoformat()
            
            # Use movie_id as document ID for easy retrieval
            await run_in_threadpool(lambda: self.moodboards_col.document(str(movie_id)).set(data))
            return True
        except Exception as e:
            print(f"Error saving moodboard for movie {movie_id}: {e}")
            return False

    async def get_moodboard_by_movie(self, movie_id: int) -> Optional[Dict[str, Any]]:
        """Get moodboard data for a specific movie."""
        try:
            doc = await run_in_threadpool(lambda: self.moodboards_col.document(str(movie_id)).get())
            if doc.exists:
                return doc.to_dict()
            return None
        except Exception as e:
            print(f"Error getting moodboard for movie {movie_id}: {e}")
            return None 