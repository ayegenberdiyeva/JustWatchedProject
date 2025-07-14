from app.core.firestore import get_firestore_client, run_in_threadpool
from datetime import datetime
import uuid
from typing import List, Dict, Any, Optional
from app.schemas.room import RoomStatus, InvitationStatus

class RoomCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.rooms_collection = self.db.collection('rooms')
        self.participants_collection = self.db.collection('room_participants')
        self.recommendations_collection = self.db.collection('room_recommendations')
        self.room_invitations_col = self.db.collection("room_invitations")

    async def create_room(self, room_data: dict, owner_id: str) -> dict:
        """Create a new room."""
        room_id = str(uuid.uuid4())
        room_data.update({
            "room_id": room_id,
            "owner_id": owner_id,
            "status": "active",
            "current_participants": 1,
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        })
        
        # Create room document
        self.rooms_collection.document(room_id).set(room_data)
        
        # Add owner as first participant
        participant_data = {
            "room_id": room_id,
            "user_id": owner_id,
            "joined_at": datetime.utcnow().isoformat(),
            "is_owner": True
        }
        self.participants_collection.document(f"{room_id}_{owner_id}").set(participant_data)
        
        return room_data

    async def get_room(self, room_id: str) -> Optional[dict]:
        """Get room details."""
        doc = self.rooms_collection.document(room_id).get()
        if doc.exists:
            return doc.to_dict()
        return None

    async def get_room_with_participants(self, room_id: str) -> Optional[dict]:
        """Get room with all participants."""
        room = await self.get_room(room_id)
        if not room:
            return None
        
        # Get participants
        participants_docs = self.participants_collection.where("room_id", "==", room_id).stream()
        participants = []
        
        # Import user_crud here to avoid circular imports
        from app.crud.user_crud import UserCRUD
        user_crud = UserCRUD()
        
        for doc in participants_docs:
            participant = doc.to_dict()
            
            # Get user profile to get display_name
            user_profile = await user_crud.get_user_profile(participant["user_id"])
            if user_profile:
                participant["display_name"] = user_profile.get("display_name")
            else:
                participant["display_name"] = None
            
            participants.append(participant)
        
        room["participants"] = participants
        return room

    async def update_room(self, room_id: str, update_data: dict) -> Optional[dict]:
        """Update room details."""
        update_data["updated_at"] = datetime.utcnow().isoformat()
        doc_ref = self.rooms_collection.document(room_id)
        doc_ref.update(update_data)
        return await self.get_room(room_id)

    async def delete_room(self, room_id: str) -> bool:
        """Delete a room and all its data."""
        try:
            # Delete participants
            participants_docs = self.participants_collection.where("room_id", "==", room_id).stream()
            for doc in participants_docs:
                doc.reference.delete()
            
            # Delete recommendations
            recommendations_docs = self.recommendations_collection.where("room_id", "==", room_id).stream()
            for doc in recommendations_docs:
                doc.reference.delete()
            
            # Delete room
            self.rooms_collection.document(room_id).delete()
            return True
        except Exception:
            return False

    async def add_participant(self, room_id: str, user_id: str, display_name: str = None) -> bool:
        """Add a participant to a room."""
        try:
            # Check if room exists and has space
            room = await self.get_room(room_id)
            if not room or room["current_participants"] >= room["max_participants"]:
                return False
            
            # Check if user is already a participant
            existing = self.participants_collection.document(f"{room_id}_{user_id}").get()
            if existing.exists:
                return True  # Already a participant
            
            # Add participant
            participant_data = {
                "room_id": room_id,
                "user_id": user_id,
                "display_name": display_name,
                "joined_at": datetime.utcnow().isoformat(),
                "is_owner": False
            }
            self.participants_collection.document(f"{room_id}_{user_id}").set(participant_data)
            
            # Update room participant count
            self.rooms_collection.document(room_id).update({
                "current_participants": room["current_participants"] + 1,
                "updated_at": datetime.utcnow().isoformat()
            })
            
            return True
        except Exception:
            return False

    async def remove_participant(self, room_id: str, user_id: str) -> bool:
        """Remove a participant from a room."""
        try:
            # Check if user is owner
            room = await self.get_room(room_id)
            if room and room["owner_id"] == user_id:
                return False  # Cannot remove owner
            
            # Remove participant
            participant_doc = self.participants_collection.document(f"{room_id}_{user_id}")
            if participant_doc.get().exists:
                participant_doc.delete()
                
                # Update room participant count
                if room:
                    self.rooms_collection.document(room_id).update({
                        "current_participants": room["current_participants"] - 1,
                        "updated_at": datetime.utcnow().isoformat()
                    })
                
                return True
            return False
        except Exception:
            return False

    async def get_user_rooms(self, user_id: str) -> List[dict]:
        """Get all rooms where user is a participant."""
        participant_docs = self.participants_collection.where("user_id", "==", user_id).stream()
        room_ids = [doc.to_dict()["room_id"] for doc in participant_docs]
        
        rooms = []
        for room_id in room_ids:
            room = await self.get_room_with_participants(room_id)
            if room:
                rooms.append(room)
        
        return rooms

    async def get_room_participants(self, room_id: str) -> List[str]:
        """Get list of user IDs who are participants in a room."""
        participant_docs = self.participants_collection.where("room_id", "==", room_id).stream()
        return [doc.to_dict()["user_id"] for doc in participant_docs]

    async def save_room_recommendations(self, room_id: str, recommendations: List[dict]) -> bool:
        """Save recommendations for a room."""
        try:
            # Ensure recommendations is a list
            if isinstance(recommendations, dict) and "recommendations" in recommendations:
                # If it's the full result object, extract just the recommendations
                recommendations_list = recommendations["recommendations"]
                generated_at = recommendations.get("generated_at", datetime.utcnow().isoformat())
            else:
                # If it's already a list
                recommendations_list = recommendations
                generated_at = datetime.utcnow().isoformat()
            
            recommendation_data = {
                "room_id": room_id,
                "recommendations": recommendations_list,
                "generated_at": generated_at
            }
            
            # Create document with room_id as the document ID for easier retrieval
            doc_id = f"{room_id}_latest"
            self.recommendations_collection.document(doc_id).set(recommendation_data)
            
            # Also save with timestamp for history
            timestamp_doc_id = f"{room_id}_{datetime.utcnow().isoformat()}"
            self.recommendations_collection.document(timestamp_doc_id).set(recommendation_data)
            
            # Update room status
            self.rooms_collection.document(room_id).update({
                "status": "active",
                "updated_at": datetime.utcnow().isoformat()
            })
            
            print(f"Successfully saved {len(recommendations_list)} recommendations for room {room_id}")
            return True
        except Exception as e:
            print(f"Error saving recommendations for room {room_id}: {e}")
            return False

    async def get_room_recommendations(self, room_id: str) -> Optional[dict]:
        """Get the latest recommendations for a room."""
        try:
            # First try to get the latest document
            latest_doc = self.recommendations_collection.document(f"{room_id}_latest").get()
            if latest_doc.exists:
                return latest_doc.to_dict()
            
            # Fallback to query by room_id field
            recommendations_docs = self.recommendations_collection.where("room_id", "==", room_id).order_by("generated_at", direction="DESCENDING").limit(1).stream()
            for doc in recommendations_docs:
                return doc.to_dict()
            
            print(f"No recommendations found for room {room_id}")
            return None
        except Exception as e:
            print(f"Error getting recommendations for room {room_id}: {e}")
            return None 

    async def create_room_invitation(self, room_id: str, from_user_id: str, to_user_id: str) -> str:
        """Create a room invitation."""
        invitation_id = str(uuid.uuid4())
        now = datetime.utcnow()
        
        invitation = {
            "invitation_id": invitation_id,
            "room_id": room_id,
            "from_user_id": from_user_id,
            "to_user_id": to_user_id,
            "status": InvitationStatus.PENDING,
            "created_at": now,
            "responded_at": None
        }
        
        await run_in_threadpool(lambda: self.room_invitations_col.document(invitation_id).set(invitation))
        return invitation_id

    async def get_user_invitations(self, user_id: str) -> List[Dict[str, Any]]:
        """Get all invitations for a user."""
        def fetch():
            invitations = self.room_invitations_col.where("to_user_id", "==", user_id).stream()
            result = []
            for doc in invitations:
                if doc.exists:
                    inv = doc.to_dict()
                    # Convert datetime fields to ISO strings
                    if "created_at" in inv and hasattr(inv["created_at"], "isoformat"):
                        inv["created_at"] = inv["created_at"].isoformat()
                    if "responded_at" in inv and inv["responded_at"] and hasattr(inv["responded_at"], "isoformat"):
                        inv["responded_at"] = inv["responded_at"].isoformat()
                    result.append(inv)
            return result
        
        return await run_in_threadpool(fetch)

    async def get_room_invitations(self, room_id: str) -> List[Dict[str, Any]]:
        """Get all invitations for a specific room."""
        def fetch():
            invitations = self.room_invitations_col.where("room_id", "==", room_id).stream()
            result = []
            for doc in invitations:
                if doc.exists:
                    inv = doc.to_dict()
                    # Convert datetime fields to ISO strings
                    if "created_at" in inv and hasattr(inv["created_at"], "isoformat"):
                        inv["created_at"] = inv["created_at"].isoformat()
                    if "responded_at" in inv and inv["responded_at"] and hasattr(inv["responded_at"], "isoformat"):
                        inv["responded_at"] = inv["responded_at"].isoformat()
                    result.append(inv)
            return result
        
        return await run_in_threadpool(fetch)

    async def respond_to_invitation(self, invitation_id: str, action: str) -> bool:
        """Accept or decline a room invitation."""
        try:
            # Get the invitation
            doc = await run_in_threadpool(lambda: self.room_invitations_col.document(invitation_id).get())
            if not doc.exists:
                return False
            
            invitation = doc.to_dict()
            now = datetime.utcnow()
            
            if action == "accept":
                # Update invitation status
                await run_in_threadpool(lambda: self.room_invitations_col.document(invitation_id).update({
                    "status": InvitationStatus.ACCEPTED,
                    "responded_at": now
                }))
                
                # Add user to room participants
                await self.add_participant(invitation["room_id"], invitation["to_user_id"])
                
            elif action == "decline":
                # Update invitation status
                await run_in_threadpool(lambda: self.room_invitations_col.document(invitation_id).update({
                    "status": InvitationStatus.DECLINED,
                    "responded_at": now
                }))
            
            return True
        except Exception:
            return False

    async def remove_room_member(self, room_id: str, user_id: str, owner_id: str) -> bool:
        """Remove a member from a room (only owner can do this)."""
        try:
            # Check if user is owner
            room = await self.get_room(room_id)
            if not room or room["owner_id"] != owner_id:
                return False
            
            # Remove from participants
            success = await self.remove_participant(room_id, user_id)
            if success:
                # Update any pending invitations for this user to declined
                def update_invitations():
                    invitations = self.room_invitations_col.where("room_id", "==", room_id).where("to_user_id", "==", user_id).where("status", "==", InvitationStatus.PENDING).stream()
                    for doc in invitations:
                        doc.reference.update({
                            "status": InvitationStatus.DECLINED,
                            "responded_at": datetime.utcnow()
                        })
                
                await run_in_threadpool(update_invitations)
            
            return success
        except Exception:
            return False

    async def check_invitation_exists(self, room_id: str, from_user_id: str, to_user_id: str) -> bool:
        """Check if an invitation already exists between users for a room."""
        def check():
            invitations = self.room_invitations_col.where("room_id", "==", room_id).where("from_user_id", "==", from_user_id).where("to_user_id", "==", to_user_id).limit(1).stream()
            return next(invitations, None) is not None
        
        return await run_in_threadpool(check) 