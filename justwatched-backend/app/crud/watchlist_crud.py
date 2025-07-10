from typing import List, Optional
from app.core.firestore import get_firestore_client, run_in_threadpool
from app.schemas.watchlist import WatchlistItem, WatchlistItemCreate
from app.schemas.movie import MediaType
from datetime import datetime

class WatchlistCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.collection = self.db.collection('watchlist')

    async def add_to_watchlist(self, user_id: str, item_data: WatchlistItemCreate) -> WatchlistItem:
        """Add a media item to user's watchlist."""
        now = datetime.utcnow()
        
        # Check if item already exists in watchlist
        existing = await self.is_in_watchlist(user_id, item_data.media_id)
        if existing:
            raise ValueError(f"Item {item_data.media_id} is already in watchlist")
        
        watchlist_item = WatchlistItem(
            user_id=user_id,
            media_id=item_data.media_id,
            media_type=item_data.media_type,
            media_title=item_data.media_title,
            poster_path=item_data.poster_path,
            added_at=now
        )
        
        # Create document ID using user_id and media_id for uniqueness
        doc_id = f"{user_id}_{item_data.media_id}"
        await run_in_threadpool(lambda: self.collection.document(doc_id).set(watchlist_item.dict()))
        
        return watchlist_item

    async def get_user_watchlist(self, user_id: str) -> List[WatchlistItem]:
        """Get all items in user's watchlist."""
        def fetch():
            docs = self.collection.where("user_id", "==", user_id).order_by("added_at", direction="DESCENDING").stream()
            items = []
            for doc in docs:
                if doc.exists:
                    item_data = doc.to_dict()
                    items.append(WatchlistItem(**item_data))
            return items
        
        return await run_in_threadpool(fetch)

    async def remove_from_watchlist(self, user_id: str, media_id: str) -> bool:
        """Remove a media item from user's watchlist."""
        try:
            doc_id = f"{user_id}_{media_id}"
            doc = await run_in_threadpool(lambda: self.collection.document(doc_id).get())
            
            if not doc.exists:
                return False
            
            # Verify ownership
            item_data = doc.to_dict()
            if item_data.get("user_id") != user_id:
                return False
            
            await run_in_threadpool(lambda: self.collection.document(doc_id).delete())
            return True
        except Exception:
            return False

    async def is_in_watchlist(self, user_id: str, media_id: str) -> bool:
        """Check if a media item is in user's watchlist."""
        try:
            doc_id = f"{user_id}_{media_id}"
            doc = await run_in_threadpool(lambda: self.collection.document(doc_id).get())
            return doc.exists
        except Exception:
            return False

    async def get_watchlist_count(self, user_id: str) -> int:
        """Get the total count of items in user's watchlist."""
        def count():
            docs = self.collection.where("user_id", "==", user_id).stream()
            return len(list(docs))
        
        return await run_in_threadpool(count) 