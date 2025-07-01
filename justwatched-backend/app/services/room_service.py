from app.crud.room_crud import RoomCRUD
from app.crud.taste_profile_crud import TasteProfileCRUD
from app.agents.tasks import find_group_recommendations
from app.websocket_manager import send_group_recommendations
from typing import List, Dict, Any, Optional

class RoomService:
    def __init__(self):
        self.room_crud = RoomCRUD()
        self.taste_profile_crud = TasteProfileCRUD()

    async def create_room(self, room_data: dict, owner_id: str) -> dict:
        """Create a new room with the owner as the first participant."""
        return await self.room_crud.create_room(room_data, owner_id)

    async def get_room_details(self, room_id: str) -> Optional[dict]:
        """Get complete room details including participants."""
        return await self.room_crud.get_room_with_participants(room_id)

    async def join_room(self, room_id: str, user_id: str, display_name: str = None) -> bool:
        """Add a user to a room."""
        return await self.room_crud.add_participant(room_id, user_id, display_name)

    async def leave_room(self, room_id: str, user_id: str) -> bool:
        """Remove a user from a room."""
        return await self.room_crud.remove_participant(room_id, user_id)

    async def get_user_rooms(self, user_id: str) -> List[dict]:
        """Get all rooms where the user is a participant."""
        return await self.room_crud.get_user_rooms(user_id)

    async def collect_participant_taste_profiles(self, room_id: str) -> List[dict]:
        """Collect taste profiles for all participants in a room."""
        # Get all participant user IDs
        participant_ids = await self.room_crud.get_room_participants(room_id)
        
        # Collect taste profiles for each participant
        taste_profiles = []
        for user_id in participant_ids:
            profile = await self.taste_profile_crud.get_taste_profile(user_id)
            if profile:
                taste_profiles.append(profile)
            else:
                # If no profile exists, create a basic one
                basic_profile = {
                    "user_id": user_id,
                    "favorite_genres": [],
                    "favorite_actors": [],
                    "favorite_directors": [],
                    "mood_preferences": []
                }
                taste_profiles.append(basic_profile)
        
        return taste_profiles

    async def process_room_recommendations(self, room_id: str) -> dict:
        """Process group recommendations for a room."""
        try:
            # Update room status to processing
            await self.room_crud.update_room(room_id, {"status": "processing"})
            
            # Collect taste profiles
            taste_profiles = await self.collect_participant_taste_profiles(room_id)
            
            if not taste_profiles:
                await self.room_crud.update_room(room_id, {"status": "active"})
                return {"error": "No participants with taste profiles found"}
            
            # Launch AI task asynchronously
            find_group_recommendations.delay(room_id, taste_profiles)
            
            return {
                "status": "processing",
                "message": "Recommendations are being generated.",
                "participant_count": len(taste_profiles)
            }
            
        except Exception as e:
            await self.room_crud.update_room(room_id, {"status": "active"})
            return {"error": f"Failed to process recommendations: {str(e)}"}

    async def save_and_deliver_recommendations(self, room_id: str, recommendations: List[dict]) -> bool:
        """Save recommendations and deliver them to room participants via WebSocket."""
        try:
            # Save to database
            success = await self.room_crud.save_room_recommendations(room_id, recommendations)
            
            if success:
                # Send via WebSocket
                send_group_recommendations(room_id, recommendations)
                return True
            
            return False
        except Exception:
            return False

    async def get_room_recommendations(self, room_id: str) -> Optional[dict]:
        """Get the latest recommendations for a room."""
        return await self.room_crud.get_room_recommendations(room_id)

    async def delete_room(self, room_id: str, user_id: str) -> bool:
        """Delete a room (only owner can delete)."""
        room = await self.room_crud.get_room(room_id)
        if room and room["owner_id"] == user_id:
            return await self.room_crud.delete_room(room_id)
        return False 