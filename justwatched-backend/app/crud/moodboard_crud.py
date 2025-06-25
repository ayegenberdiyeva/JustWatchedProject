from typing import List, Dict, Any
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