from app.core.firestore import get_firestore_client

class UserDataService:
    def __init__(self):
        self.db = get_firestore_client()
        self.collection = self.db.collection('watch_history')

    async def get_user_watch_history(self, user_id: str) -> list:
        docs = self.collection.where('user_id', '==', user_id).stream()
        return [doc.to_dict() for doc in docs] 