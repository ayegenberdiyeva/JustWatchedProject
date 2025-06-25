from typing import Dict, Any, Optional
from app.core.firestore import get_firestore_client, run_in_threadpool

class RoomCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.rooms_col = self.db.collection("rooms")

    async def create_room(self, room_id: str, data: Dict[str, Any]) -> None:
        await run_in_threadpool(lambda: self.rooms_col.document(room_id).set(data))

    async def update_room(self, room_id: str, data: Dict[str, Any]) -> None:
        await run_in_threadpool(lambda: self.rooms_col.document(room_id).update(data))

    async def get_room(self, room_id: str) -> Optional[Dict[str, Any]]:
        doc = await run_in_threadpool(lambda: self.rooms_col.document(room_id).get())
        if doc.exists:
            return doc.to_dict()
        return None 