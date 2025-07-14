from app.crud.user_crud import UserCRUD
from app.crud.friend_crud import FriendCRUD
from app.crud.review_crud import ReviewCRUD
from app.crud.collection_crud import CollectionCRUD
from app.crud.watchlist_crud import WatchlistCRUD
from app.crud.taste_profile_crud import TasteProfileCRUD
from app.crud.recommendation_crud import RecommendationCRUD
from app.crud.search_history_crud import SearchHistoryCRUD
from app.crud.room_crud import RoomCRUD
from app.crud.moodboard_crud import MoodboardCRUD
from app.core.firestore import get_firestore_client, run_in_threadpool
from app.core.redis_client import redis_client
from typing import Dict, List, Any
import json

class AccountDeletionService:
    """
    Service to handle comprehensive account deletion across all collections.
    """
    
    def __init__(self):
        self.db = get_firestore_client()
        self.user_crud = UserCRUD()
        self.friend_crud = FriendCRUD()
        self.review_crud = ReviewCRUD()
        self.collection_crud = CollectionCRUD()
        self.watchlist_crud = WatchlistCRUD()
        self.taste_profile_crud = TasteProfileCRUD()
        self.recommendation_crud = RecommendationCRUD()
        self.search_history_crud = SearchHistoryCRUD()
        self.room_crud = RoomCRUD()
        self.moodboard_crud = MoodboardCRUD()

    async def delete_user_account(self, user_id: str) -> Dict[str, Any]:
        """
        Delete a user's account and all associated data.
        Returns a summary of what was deleted.
        """
        deletion_summary = {
            "user_id": user_id,
            "deleted_items": {},
            "errors": [],
            "success": True
        }
        
        try:
            # 1. Delete user's reviews
            await self._delete_user_reviews(user_id, deletion_summary)
            
            # 2. Delete user's collections
            await self._delete_user_collections(user_id, deletion_summary)
            
            # 3. Delete user's watchlist
            await self._delete_user_watchlist(user_id, deletion_summary)
            
            # 4. Delete user's taste profile
            await self._delete_user_taste_profile(user_id, deletion_summary)
            
            # 5. Delete user's recommendations
            await self._delete_user_recommendations(user_id, deletion_summary)
            
            # 6. Delete user's search history
            await self._delete_user_search_history(user_id, deletion_summary)
            
            # 7. Delete user's moodboards
            await self._delete_user_moodboards(user_id, deletion_summary)
            
            # 8. Handle room-related data
            await self._handle_room_data(user_id, deletion_summary)
            
            # 9. Handle friend relationships
            await self._handle_friend_relationships(user_id, deletion_summary)
            
            # 10. Clear Redis cache
            await self._clear_user_cache(user_id, deletion_summary)
            
            # 11. Finally, delete the user profile
            await self._delete_user_profile(user_id, deletion_summary)
            
        except Exception as e:
            deletion_summary["success"] = False
            deletion_summary["errors"].append(f"Account deletion failed: {str(e)}")
        
        return deletion_summary

    async def _delete_user_reviews(self, user_id: str, summary: Dict[str, Any]):
        """Delete all reviews by the user."""
        try:
            reviews = await self.review_crud.get_reviews_by_user(user_id)
            deleted_count = 0
            
            for review in reviews:
                try:
                    await self.review_crud.delete_review(review["review_id"])
                    deleted_count += 1
                except Exception as e:
                    summary["errors"].append(f"Failed to delete review {review.get('review_id')}: {str(e)}")
            
            summary["deleted_items"]["reviews"] = deleted_count
        except Exception as e:
            summary["errors"].append(f"Failed to delete user reviews: {str(e)}")

    async def _delete_user_collections(self, user_id: str, summary: Dict[str, Any]):
        """Delete all collections owned by the user."""
        try:
            collections = await self.collection_crud.get_user_collections(user_id)
            deleted_count = 0
            
            for collection in collections:
                try:
                    await self.collection_crud.delete_collection(collection["collection_id"])
                    deleted_count += 1
                except Exception as e:
                    summary["errors"].append(f"Failed to delete collection {collection.get('collection_id')}: {str(e)}")
            
            summary["deleted_items"]["collections"] = deleted_count
        except Exception as e:
            summary["errors"].append(f"Failed to delete user collections: {str(e)}")

    async def _delete_user_watchlist(self, user_id: str, summary: Dict[str, Any]):
        """Delete user's watchlist."""
        try:
            watchlist_items = await self.watchlist_crud.get_user_watchlist(user_id)
            deleted_count = 0
            
            for item in watchlist_items:
                try:
                    await self.watchlist_crud.remove_from_watchlist(item["doc_id"])
                    deleted_count += 1
                except Exception as e:
                    summary["errors"].append(f"Failed to delete watchlist item {item.get('doc_id')}: {str(e)}")
            
            summary["deleted_items"]["watchlist_items"] = deleted_count
        except Exception as e:
            summary["errors"].append(f"Failed to delete user watchlist: {str(e)}")

    async def _delete_user_taste_profile(self, user_id: str, summary: Dict[str, Any]):
        """Delete user's taste profile."""
        try:
            await self.taste_profile_crud.delete_taste_profile(user_id)
            summary["deleted_items"]["taste_profile"] = 1
        except Exception as e:
            summary["errors"].append(f"Failed to delete taste profile: {str(e)}")

    async def _delete_user_recommendations(self, user_id: str, summary: Dict[str, Any]):
        """Delete user's recommendations."""
        try:
            await self.recommendation_crud.delete_user_recommendations(user_id)
            summary["deleted_items"]["recommendations"] = 1
        except Exception as e:
            summary["errors"].append(f"Failed to delete recommendations: {str(e)}")

    async def _delete_user_search_history(self, user_id: str, summary: Dict[str, Any]):
        """Delete user's search history."""
        try:
            await self.search_history_crud.delete_user_search_history(user_id)
            summary["deleted_items"]["search_history"] = 1
        except Exception as e:
            summary["errors"].append(f"Failed to delete search history: {str(e)}")

    async def _delete_user_moodboards(self, user_id: str, summary: Dict[str, Any]):
        """Delete user's moodboards."""
        try:
            moodboards = await self.moodboard_crud.get_user_moodboards(user_id)
            deleted_count = 0
            
            for moodboard in moodboards:
                try:
                    await self.moodboard_crud.delete_moodboard(moodboard["moodboard_id"])
                    deleted_count += 1
                except Exception as e:
                    summary["errors"].append(f"Failed to delete moodboard {moodboard.get('moodboard_id')}: {str(e)}")
            
            summary["deleted_items"]["moodboards"] = deleted_count
        except Exception as e:
            summary["errors"].append(f"Failed to delete user moodboards: {str(e)}")

    async def _handle_room_data(self, user_id: str, summary: Dict[str, Any]):
        """Handle room-related data when user is deleted."""
        try:
            # Get rooms where user is a participant
            user_rooms = await self.room_crud.get_user_rooms(user_id)
            rooms_handled = 0
            
            for room in user_rooms:
                try:
                    room_id = room["room_id"]
                    
                    # If user is the owner, delete the entire room
                    if room["owner_id"] == user_id:
                        await self.room_crud.delete_room(room_id)
                        rooms_handled += 1
                    else:
                        # If user is just a participant, remove them from the room
                        await self.room_crud.remove_participant(room_id, user_id)
                        rooms_handled += 1
                        
                except Exception as e:
                    summary["errors"].append(f"Failed to handle room {room.get('room_id')}: {str(e)}")
            
            summary["deleted_items"]["rooms_handled"] = rooms_handled
            
            # Delete room invitations involving this user
            await self._delete_room_invitations(user_id, summary)
            
        except Exception as e:
            summary["errors"].append(f"Failed to handle room data: {str(e)}")

    async def _delete_room_invitations(self, user_id: str, summary: Dict[str, Any]):
        """Delete room invitations involving the user."""
        try:
            # Delete invitations where user is the sender or receiver
            def delete_invitations():
                invitations = self.db.collection("room_invitations").where("from_user_id", "==", user_id).stream()
                for doc in invitations:
                    doc.reference.delete()
                
                invitations = self.db.collection("room_invitations").where("to_user_id", "==", user_id).stream()
                for doc in invitations:
                    doc.reference.delete()
            
            await run_in_threadpool(delete_invitations)
            summary["deleted_items"]["room_invitations"] = 1
        except Exception as e:
            summary["errors"].append(f"Failed to delete room invitations: {str(e)}")

    async def _handle_friend_relationships(self, user_id: str, summary: Dict[str, Any]):
        """Handle friend relationships when user is deleted."""
        try:
            # Get user's friends
            friends = await self.friend_crud.get_friends_list(user_id)
            friends_handled = 0
            
            # Remove user from all friends' friend lists
            for friend_id in friends:
                try:
                    await self.friend_crud.remove_friend(user_id, friend_id)
                    friends_handled += 1
                except Exception as e:
                    summary["errors"].append(f"Failed to remove friend relationship with {friend_id}: {str(e)}")
            
            # Delete friend requests involving this user
            await self._delete_friend_requests(user_id, summary)
            
            summary["deleted_items"]["friendships_removed"] = friends_handled
            
        except Exception as e:
            summary["errors"].append(f"Failed to handle friend relationships: {str(e)}")

    async def _delete_friend_requests(self, user_id: str, summary: Dict[str, Any]):
        """Delete friend requests involving the user."""
        try:
            def delete_requests():
                requests = self.db.collection("friend_requests").where("from_user_id", "==", user_id).stream()
                for doc in requests:
                    doc.reference.delete()
                
                requests = self.db.collection("friend_requests").where("to_user_id", "==", user_id).stream()
                for doc in requests:
                    doc.reference.delete()
            
            await run_in_threadpool(delete_requests)
            summary["deleted_items"]["friend_requests"] = 1
        except Exception as e:
            summary["errors"].append(f"Failed to delete friend requests: {str(e)}")

    async def _clear_user_cache(self, user_id: str, summary: Dict[str, Any]):
        """Clear user-related cache from Redis."""
        try:
            # Clear recommendation cache
            cache_key = f"user:{user_id}:recommendations"
            redis_client.delete(cache_key)
            
            # Clear any other user-specific cache keys
            pattern = f"user:{user_id}:*"
            keys = redis_client.keys(pattern)
            if keys:
                redis_client.delete(*keys)
            
            summary["deleted_items"]["cache_cleared"] = 1
        except Exception as e:
            summary["errors"].append(f"Failed to clear user cache: {str(e)}")

    async def _delete_user_profile(self, user_id: str, summary: Dict[str, Any]):
        """Delete the user profile document."""
        try:
            def delete_profile():
                self.db.collection("users").document(user_id).delete()
            
            await run_in_threadpool(delete_profile)
            summary["deleted_items"]["user_profile"] = 1
        except Exception as e:
            summary["errors"].append(f"Failed to delete user profile: {str(e)}")
            summary["success"] = False 