from typing import List, Optional, Dict, Any
from app.core.firestore import get_firestore_client, run_in_threadpool
from app.schemas.user import FriendRequest, FriendRequestCreate, FriendStatus
from datetime import datetime
import uuid

class FriendCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.friend_requests_col = self.db.collection("friend_requests")
        self.friends_col = self.db.collection("friends")

    async def send_friend_request(self, from_user_id: str, to_user_id: str) -> str:
        """Send a friend request."""
        request_id = str(uuid.uuid4())
        now = datetime.utcnow()
        
        request = FriendRequest(
            request_id=request_id,
            from_user_id=from_user_id,
            to_user_id=to_user_id,
            status=FriendStatus.PENDING_SENT,
            created_at=now,
            responded_at=None
        )
        
        await run_in_threadpool(lambda: self.friend_requests_col.document(request_id).set(request.dict()))
        return request_id

    async def get_pending_requests(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all pending friend requests for a user."""
        def fetch():
            # Get requests sent by user
            sent_requests = self.friend_requests_col.where("from_user_id", "==", user_id).where("status", "==", FriendStatus.PENDING_SENT).stream()
            # Get requests received by user
            received_requests = self.friend_requests_col.where("to_user_id", "==", user_id).where("status", "==", FriendStatus.PENDING_RECEIVED).stream()
            
            requests = []
            for doc in sent_requests:
                if doc.exists:
                    requests.append(doc.to_dict())
            for doc in received_requests:
                if doc.exists:
                    requests.append(doc.to_dict())
            
            return requests
        
        return await run_in_threadpool(fetch)

    async def respond_to_friend_request(self, request_id: str, action: str) -> bool:
        """Accept or decline a friend request."""
        try:
            doc = await run_in_threadpool(lambda: self.friend_requests_col.document(request_id).get())
            if not doc.exists:
                return False
            
            request_data = doc.to_dict()
            now = datetime.utcnow()
            
            if action == "accept":
                # Update request status
                await run_in_threadpool(lambda: self.friend_requests_col.document(request_id).update({
                    "status": FriendStatus.FRIENDS,
                    "responded_at": now
                }))
                
                # Create friendship record
                friendship = {
                    "user1_id": request_data["from_user_id"],
                    "user2_id": request_data["to_user_id"],
                    "created_at": now
                }
                await run_in_threadpool(lambda: self.friends_col.add(friendship))
                
            elif action == "decline":
                await run_in_threadpool(lambda: self.friend_requests_col.document(request_id).update({
                    "status": FriendStatus.NOT_FRIENDS,
                    "responded_at": now
                }))
            
            return True
        except Exception:
            return False

    async def are_friends(self, user1_id: str, user2_id: str) -> bool:
        """Check if two users are friends."""
        def check():
            # Check both directions
            friendship1 = self.friends_col.where("user1_id", "==", user1_id).where("user2_id", "==", user2_id).limit(1).stream()
            friendship2 = self.friends_col.where("user1_id", "==", user2_id).where("user2_id", "==", user1_id).limit(1).stream()
            
            return next(friendship1, None) is not None or next(friendship2, None) is not None
        
        return await run_in_threadpool(check)

    async def get_friends_list(self, user_id: str) -> List[str]:
        """Get list of user IDs who are friends with the given user."""
        def fetch():
            friends = []
            
            # Get friends where user is user1
            friendships1 = self.friends_col.where("user1_id", "==", user_id).stream()
            for doc in friendships1:
                if doc.exists:
                    friends.append(doc.to_dict()["user2_id"])
            
            # Get friends where user is user2
            friendships2 = self.friends_col.where("user2_id", "==", user_id).stream()
            for doc in friendships2:
                if doc.exists:
                    friends.append(doc.to_dict()["user1_id"])
            
            return list(set(friends))  # Remove duplicates
        
        return await run_in_threadpool(fetch)

    async def remove_friend(self, user1_id: str, user2_id: str) -> bool:
        """Remove friendship between two users."""
        try:
            def remove():
                # Remove friendship record
                friendships1 = self.friends_col.where("user1_id", "==", user1_id).where("user2_id", "==", user2_id).stream()
                friendships2 = self.friends_col.where("user1_id", "==", user2_id).where("user2_id", "==", user1_id).stream()
                
                for doc in friendships1:
                    doc.reference.delete()
                for doc in friendships2:
                    doc.reference.delete()
            
            await run_in_threadpool(remove)
            return True
        except Exception:
            return False

    async def get_friend_status(self, from_user_id: str, to_user_id: str) -> FriendStatus:
        """Get the friendship status between two users."""
        def check():
            # Check if they're friends
            friendship1 = self.friends_col.where("user1_id", "==", from_user_id).where("user2_id", "==", to_user_id).limit(1).stream()
            friendship2 = self.friends_col.where("user1_id", "==", to_user_id).where("user2_id", "==", from_user_id).limit(1).stream()
            
            if next(friendship1, None) is not None or next(friendship2, None) is not None:
                return FriendStatus.FRIENDS
            
            # Check pending requests
            sent_request = self.friend_requests_col.where("from_user_id", "==", from_user_id).where("to_user_id", "==", to_user_id).where("status", "in", [FriendStatus.PENDING_SENT, FriendStatus.PENDING_RECEIVED]).limit(1).stream()
            received_request = self.friend_requests_col.where("from_user_id", "==", to_user_id).where("to_user_id", "==", from_user_id).where("status", "in", [FriendStatus.PENDING_SENT, FriendStatus.PENDING_RECEIVED]).limit(1).stream()
            
            if next(sent_request, None) is not None:
                return FriendStatus.PENDING_SENT
            if next(received_request, None) is not None:
                return FriendStatus.PENDING_RECEIVED
            
            return FriendStatus.NOT_FRIENDS
        
        return await run_in_threadpool(check) 