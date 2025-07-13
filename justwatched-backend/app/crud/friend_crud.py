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
        
        # Create request record for sender
        sender_request = FriendRequest(
            request_id=request_id,
            from_user_id=from_user_id,
            to_user_id=to_user_id,
            status=FriendStatus.PENDING_SENT,
            created_at=now,
            responded_at=None
        )
        
        # Create request record for receiver
        receiver_request = FriendRequest(
            request_id=request_id,
            from_user_id=from_user_id,
            to_user_id=to_user_id,
            status=FriendStatus.PENDING_RECEIVED,
            created_at=now,
            responded_at=None
        )
        
        # Save both records
        await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_sender").set(sender_request.dict()))
        await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_receiver").set(receiver_request.dict()))
        
        return request_id

    async def check_existing_request(self, from_user_id: str, to_user_id: str) -> bool:
        """Check if a friend request already exists between two users."""
        def check():
            # Check if there's already a pending request in either direction
            existing_sent = self.friend_requests_col.where("from_user_id", "==", from_user_id).where("to_user_id", "==", to_user_id).where("status", "in", [FriendStatus.PENDING_SENT, FriendStatus.PENDING_RECEIVED]).limit(1).stream()
            existing_received = self.friend_requests_col.where("from_user_id", "==", to_user_id).where("to_user_id", "==", from_user_id).where("status", "in", [FriendStatus.PENDING_SENT, FriendStatus.PENDING_RECEIVED]).limit(1).stream()
            
            return next(existing_sent, None) is not None or next(existing_received, None) is not None
        
        return await run_in_threadpool(check)

    async def cancel_friend_request(self, request_id: str, user_id: str) -> bool:
        """Cancel/withdraw a friend request (only the sender can cancel)."""
        try:
            # Get the sender document to verify the user is the sender
            doc = await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_sender").get())
            if not doc.exists:
                return False
            
            request_data = doc.to_dict()
            if request_data["from_user_id"] != user_id:
                return False  # Only the sender can cancel
            
            # Update both documents to cancelled status
            now = datetime.utcnow()
            await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_sender").update({
                "status": FriendStatus.NOT_FRIENDS,
                "responded_at": now
            }))
            await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_receiver").update({
                "status": FriendStatus.NOT_FRIENDS,
                "responded_at": now
            }))
            
            return True
        except Exception:
            return False

    async def get_pending_requests(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all pending friend requests for a user."""
        def fetch():
            requests = []
            
            # Get requests sent by user (documents ending with _sender)
            sent_requests = self.friend_requests_col.where("from_user_id", "==", user_id).where("status", "==", FriendStatus.PENDING_SENT).stream()
            for doc in sent_requests:
                if doc.exists:
                    req = doc.to_dict()
                    # Convert datetime fields to ISO strings
                    if "created_at" in req and hasattr(req["created_at"], "isoformat"):
                        req["created_at"] = req["created_at"].isoformat()
                    if "responded_at" in req and req["responded_at"] and hasattr(req["responded_at"], "isoformat"):
                        req["responded_at"] = req["responded_at"].isoformat()
                    requests.append(req)
            
            # Get requests received by user (documents ending with _receiver)
            received_requests = self.friend_requests_col.where("to_user_id", "==", user_id).where("status", "==", FriendStatus.PENDING_RECEIVED).stream()
            for doc in received_requests:
                if doc.exists:
                    req = doc.to_dict()
                    # Convert datetime fields to ISO strings
                    if "created_at" in req and hasattr(req["created_at"], "isoformat"):
                        req["created_at"] = req["created_at"].isoformat()
                    if "responded_at" in req and req["responded_at"] and hasattr(req["responded_at"], "isoformat"):
                        req["responded_at"] = req["responded_at"].isoformat()
                    requests.append(req)
            
            return requests
        
        return await run_in_threadpool(fetch)

    async def respond_to_friend_request(self, request_id: str, action: str) -> bool:
        """Accept or decline a friend request."""
        try:
            # Get the receiver document
            doc = await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_receiver").get())
            if not doc.exists:
                return False
            
            request_data = doc.to_dict()
            now = datetime.utcnow()
            
            if action == "accept":
                # Update both sender and receiver documents
                await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_sender").update({
                    "status": FriendStatus.FRIENDS,
                    "responded_at": now
                }))
                await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_receiver").update({
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
                # Update both sender and receiver documents
                await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_sender").update({
                    "status": FriendStatus.NOT_FRIENDS,
                    "responded_at": now
                }))
                await run_in_threadpool(lambda: self.friend_requests_col.document(f"{request_id}_receiver").update({
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
            
            # Check pending requests - look for sender document first
            sent_request = self.friend_requests_col.where("from_user_id", "==", from_user_id).where("to_user_id", "==", to_user_id).where("status", "==", FriendStatus.PENDING_SENT).limit(1).stream()
            if next(sent_request, None) is not None:
                return FriendStatus.PENDING_SENT
            
            # Check for received request
            received_request = self.friend_requests_col.where("from_user_id", "==", to_user_id).where("to_user_id", "==", from_user_id).where("status", "==", FriendStatus.PENDING_RECEIVED).limit(1).stream()
            if next(received_request, None) is not None:
                return FriendStatus.PENDING_RECEIVED
            
            return FriendStatus.NOT_FRIENDS
        
        return await run_in_threadpool(check) 