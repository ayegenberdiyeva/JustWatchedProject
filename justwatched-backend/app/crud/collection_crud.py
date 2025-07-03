from typing import List, Optional, Dict, Any
from app.core.firestore import get_firestore_client, run_in_threadpool
from app.schemas.user import Collection, CollectionCreate, CollectionUpdate, CollectionVisibility
from datetime import datetime
import uuid

class CollectionCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.collections_col = self.db.collection("collections")
        self.review_collections_col = self.db.collection("review_collections")

    def _convert_datetime_fields(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Convert Firestore datetime objects to ISO strings."""
        if "created_at" in data:
            if hasattr(data["created_at"], 'isoformat'):
                data["created_at"] = data["created_at"].isoformat()
            elif not isinstance(data["created_at"], str):
                data["created_at"] = str(data["created_at"])
        
        if "updated_at" in data:
            if hasattr(data["updated_at"], 'isoformat'):
                data["updated_at"] = data["updated_at"].isoformat()
            elif not isinstance(data["updated_at"], str):
                data["updated_at"] = str(data["updated_at"])
        
        return data

    async def create_collection(self, user_id: str, collection_data: CollectionCreate) -> str:
        """Create a new collection for a user."""
        collection_id = str(uuid.uuid4())
        now = datetime.utcnow()
        
        collection = Collection(
            collection_id=collection_id,
            user_id=user_id,
            name=collection_data.name,
            description=collection_data.description,
            visibility=collection_data.visibility,
            created_at=now,
            updated_at=now,
            review_count=0
        )
        
        # Convert datetime to ISO string for Firestore
        collection_dict = collection.dict()
        collection_dict["created_at"] = now.isoformat()
        collection_dict["updated_at"] = now.isoformat()
        
        await run_in_threadpool(lambda: self.collections_col.document(collection_id).set(collection_dict))
        return collection_id

    async def get_user_collections(self, user_id: str, include_private: bool = True) -> List[Dict[str, Any]]:
        """Get all collections for a user."""
        def fetch():
            query = self.collections_col.where("user_id", "==", user_id)
            if not include_private:
                query = query.where("visibility", "!=", CollectionVisibility.PRIVATE)
            docs = query.stream()
            collections = []
            for doc in docs:
                if doc.exists:
                    collection_data = doc.to_dict()
                    collections.append(self._convert_datetime_fields(collection_data))
            return collections
        
        return await run_in_threadpool(fetch)

    async def get_collection_by_id(self, collection_id: str) -> Optional[Dict[str, Any]]:
        """Get a specific collection by ID."""
        doc = await run_in_threadpool(lambda: self.collections_col.document(collection_id).get())
        if doc.exists:
            collection_data = doc.to_dict()
            return self._convert_datetime_fields(collection_data)
        return None

    async def update_collection(self, collection_id: str, update_data: CollectionUpdate) -> bool:
        """Update a collection."""
        try:
            update_dict = update_data.dict(exclude_unset=True)
            update_dict["updated_at"] = datetime.utcnow()
            
            await run_in_threadpool(lambda: self.collections_col.document(collection_id).update(update_dict))
            return True
        except Exception:
            return False

    async def delete_collection(self, collection_id: str) -> bool:
        """Delete a collection and all its review associations."""
        try:
            # Delete all review associations first
            def delete_associations():
                associations = self.review_collections_col.where("collection_id", "==", collection_id).stream()
                for doc in associations:
                    doc.reference.delete()
            
            await run_in_threadpool(delete_associations)
            
            # Delete the collection
            await run_in_threadpool(lambda: self.collections_col.document(collection_id).delete())
            return True
        except Exception:
            return False

    async def add_review_to_collection(self, review_id: str, collection_id: str) -> bool:
        """Add a review to a collection."""
        try:
            now = datetime.utcnow()
            association = {
                "review_id": review_id,
                "collection_id": collection_id,
                "added_at": now
            }
            
            # Add the association
            await run_in_threadpool(lambda: self.review_collections_col.add(association))
            
            # Update collection review count
            await run_in_threadpool(lambda: self.collections_col.document(collection_id).update({
                "review_count": self.db.collection("review_collections").where("collection_id", "==", collection_id).count().get()[0][0],
                "updated_at": now
            }))
            
            return True
        except Exception:
            return False

    async def remove_review_from_collection(self, review_id: str, collection_id: str) -> bool:
        """Remove a review from a collection."""
        try:
            # Find and delete the association
            def delete_association():
                associations = self.review_collections_col.where("review_id", "==", review_id).where("collection_id", "==", collection_id).stream()
                for doc in associations:
                    doc.reference.delete()
                    break
            
            await run_in_threadpool(delete_association)
            
            # Update collection review count
            await run_in_threadpool(lambda: self.collections_col.document(collection_id).update({
                "review_count": self.db.collection("review_collections").where("collection_id", "==", collection_id).count().get()[0][0],
                "updated_at": datetime.utcnow()
            }))
            
            return True
        except Exception:
            return False

    async def get_collection_reviews(self, collection_id: str) -> List[str]:
        """Get all review IDs in a collection."""
        def fetch():
            associations = self.review_collections_col.where("collection_id", "==", collection_id).stream()
            return [doc.to_dict()["review_id"] for doc in associations if doc.exists]
        
        return await run_in_threadpool(fetch)

    async def get_review_collections(self, review_id: str) -> List[str]:
        """Get all collection IDs that contain a specific review."""
        def fetch():
            associations = self.review_collections_col.where("review_id", "==", review_id).stream()
            return [doc.to_dict()["collection_id"] for doc in associations if doc.exists]
        
        return await run_in_threadpool(fetch) 