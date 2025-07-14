from typing import List, Optional, Dict, Any
from app.schemas.ai import PersonalRecommendationList, GroupRecommendationList
from app.core.firestore import get_firestore_client, run_in_threadpool

class RecommendationCRUD:
    """
    Data access layer for recommendation-related operations (Firestore integration).
    """
    def __init__(self):
        self.db = get_firestore_client()
        self.personal_col = self.db.collection("personal_recommendations")
        self.group_col = self.db.collection("group_recommendations")

    async def save_personal_recommendations(self, recs: PersonalRecommendationList) -> None:
        """Save personal recommendations for a user."""
        await run_in_threadpool(lambda: self.personal_col.document(recs.user_id).set(recs.dict()))

    async def get_personal_recommendations(self, user_id: str) -> Optional[PersonalRecommendationList]:
        """Fetch personal recommendations for a user."""
        doc = await run_in_threadpool(lambda: self.personal_col.document(user_id).get())
        if doc.exists:
            return PersonalRecommendationList(**doc.to_dict())
        return None

    async def save_group_recommendations(self, recs: GroupRecommendationList) -> None:
        """Save group recommendations for a group."""
        await run_in_threadpool(lambda: self.group_col.document(recs.group_id).set(recs.dict()))

    async def get_group_recommendations(self, group_id: str) -> Optional[GroupRecommendationList]:
        """Fetch group recommendations for a group."""
        doc = await run_in_threadpool(lambda: self.group_col.document(group_id).get())
        if doc.exists:
            return GroupRecommendationList(**doc.to_dict())
        return None

    async def get_user_recommendations(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get personal recommendations for a user."""
        doc = await run_in_threadpool(lambda: self.personal_col.document(user_id).get())
        if doc.exists:
            return doc.to_dict()
        return None

    async def delete_user_recommendations(self, user_id: str) -> bool:
        """Delete personal recommendations for a user."""
        try:
            await run_in_threadpool(lambda: self.personal_col.document(user_id).delete())
            return True
        except Exception:
            return False 