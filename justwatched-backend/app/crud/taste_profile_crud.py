from typing import Dict, Any, Optional
from app.core.firestore import get_firestore_client, run_in_threadpool
from datetime import datetime

class TasteProfileCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.taste_profiles_col = self.db.collection("tasteProfiles")

    async def save_taste_profile(self, user_id: str, data: Dict[str, Any]) -> None:
        data = dict(data)
        data["lastUpdatedAt"] = datetime.utcnow().isoformat()
        await run_in_threadpool(lambda: self.taste_profiles_col.document(user_id).set(data))

    async def get_taste_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get taste profile for a user."""
        doc = await run_in_threadpool(lambda: self.taste_profiles_col.document(user_id).get())
        if doc.exists:
            return doc.to_dict()
        return None

    async def delete_taste_profile(self, user_id: str) -> bool:
        """Delete taste profile for a user."""
        try:
            await run_in_threadpool(lambda: self.taste_profiles_col.document(user_id).delete())
            return True
        except Exception:
            return False 