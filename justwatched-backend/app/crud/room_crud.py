from app.core.firestore import get_firestore_client
from datetime import datetime
import uuid
from typing import List, Dict, Any, Optional

class RoomCRUD:
    def __init__(self):
        self.db = get_firestore_client()
        self.rooms_collection = self.db.collection('rooms')
        self.participants_collection = self.db.collection('room_participants')
        self.recommendations_collection = self.db.collection('room_recommendations')

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
        for doc in participants_docs:
            participant = doc.to_dict()
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