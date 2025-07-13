from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from typing import List, Optional
from app.services.room_service import RoomService
from app.schemas.room import (
    RoomCreate, RoomUpdate, RoomResponse, RoomListResponse, 
    RoomRecommendationResponse, RoomParticipant
)
from app.core.security import get_current_user

router = APIRouter()
room_service = RoomService()

@router.post("/", response_model=RoomResponse)
async def create_room(
    room_data: RoomCreate,
    user=Depends(get_current_user)
):
    """Create a new room."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        room = await room_service.create_room(room_data.dict(), user_id)
        # Get complete room details including participants
        complete_room = await room_service.get_room_details(room["room_id"])
        return complete_room
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create room: {str(e)}")

@router.get("/", response_model=RoomListResponse)
async def get_user_rooms(
    user=Depends(get_current_user)
):
    """Get all rooms where the user is a participant."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        rooms = await room_service.get_user_rooms(user_id)
        return {
            "rooms": rooms,
            "total_count": len(rooms),
            "has_more": False
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get user rooms: {str(e)}")

@router.get("/{room_id}", response_model=RoomResponse)
async def get_room(
    room_id: str = Path(..., description="ID of the room"),
    user=Depends(get_current_user)
):
    """Get room details."""
    try:
        room = await room_service.get_room_details(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        return room
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get room: {str(e)}")

@router.put("/{room_id}", response_model=RoomResponse)
async def update_room(
    room_id: str = Path(..., description="ID of the room"),
    room_data: RoomUpdate = None,
    user=Depends(get_current_user)
):
    """Update room details (only owner can update)."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        room = await room_service.get_room_details(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        if room["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only room owner can update room")
        
        await room_service.room_crud.update_room(room_id, room_data.dict(exclude_unset=True))
        # Get updated room details
        updated_room = await room_service.get_room_details(room_id)
        return updated_room
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update room: {str(e)}")

@router.delete("/{room_id}")
async def delete_room(
    room_id: str = Path(..., description="ID of the room"),
    user=Depends(get_current_user)
):
    """Delete a room (only owner can delete)."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        success = await room_service.delete_room(room_id, user_id)
        if not success:
            raise HTTPException(status_code=403, detail="Only room owner can delete room")
        return {"message": "Room deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete room: {str(e)}")

@router.post("/{room_id}/join")
async def join_room(
    room_id: str = Path(..., description="ID of the room"),
    user=Depends(get_current_user)
):
    """Join a room."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        success = await room_service.join_room(room_id, user_id)
        if not success:
            raise HTTPException(status_code=400, detail="Failed to join room (room full or already a participant)")
        return {"message": "Successfully joined room"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to join room: {str(e)}")

@router.post("/{room_id}/leave")
async def leave_room(
    room_id: str = Path(..., description="ID of the room"),
    user=Depends(get_current_user)
):
    """Leave a room."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        success = await room_service.leave_room(room_id, user_id)
        if not success:
            raise HTTPException(status_code=400, detail="Failed to leave room")
        return {"message": "Successfully left room"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to leave room: {str(e)}")

@router.post("/{room_id}/process")
async def process_room_recommendations(
    room_id: str = Path(..., description="ID of the room"),
    user=Depends(get_current_user)
):
    """Process group recommendations for a room."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        # Verify user is in the room
        room = await room_service.get_room_details(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        participant_ids = [p["user_id"] for p in room["participants"]]
        if user_id not in participant_ids:
            raise HTTPException(status_code=403, detail="You must be a participant to process recommendations")
        
        result = await room_service.process_room_recommendations(room_id)
        if "error" in result:
            raise HTTPException(status_code=400, detail=result["error"])
        
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process recommendations: {str(e)}")

@router.get("/{room_id}/recommendations", response_model=RoomRecommendationResponse)
async def get_room_recommendations(
    room_id: str = Path(..., description="ID of the room"),
    user=Depends(get_current_user)
):
    """Get the latest recommendations for a room."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        # Verify user is in the room
        room = await room_service.get_room_details(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        participant_ids = [p["user_id"] for p in room["participants"]]
        if user_id not in participant_ids:
            raise HTTPException(status_code=403, detail="You must be a participant to view recommendations")
        
        recommendations = await room_service.get_room_recommendations(room_id)
        if not recommendations:
            raise HTTPException(status_code=404, detail="No recommendations found for this room")
        
        # Transform the stored recommendations to match the expected format
        stored_recs = recommendations.get("recommendations", [])
        transformed_recs = []
        
        for rec in stored_recs:
            if isinstance(rec, dict):
                # Handle the new TMDB-based AI assistant response format
                if "tmdb_id" in rec:
                    # New TMDB-based format
                    transformed_recs.append({
                        "movie_id": str(rec.get("tmdb_id", "")),
                        "title": rec.get("title", "Unknown"),
                        "poster_path": rec.get("poster_path"),
                        "group_score": rec.get("group_score", 0.8),
                        "reasons": rec.get("reasons", ["Recommended by AI"]),
                        "participants_who_liked": rec.get("participants_who_liked", [])
                    })
                elif "movie" in rec:
                    # Old AI assistant format (legacy)
                    movie_data = rec["movie"]
                    transformed_recs.append({
                        "movie_id": str(hash(movie_data.get("title", ""))),  # Generate ID from title
                        "title": movie_data.get("title", "Unknown"),
                        "poster_path": None,
                        "group_score": 0.8,
                        "reasons": [rec.get("justification", "Recommended by AI")],
                        "participants_who_liked": []
                    })
                else:
                    # Fallback format
                    transformed_recs.append(rec)
        
        return {
            "room_id": room_id,
            "recommendations": transformed_recs,
            "generated_at": recommendations["generated_at"],
            "participant_count": len(participant_ids)
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get recommendations: {str(e)}")

@router.post("/{room_id}/start-voting")
async def start_voting_session(room_id: str, user=Depends(get_current_user)):
    """API endpoint to start a voting session for a room."""
    try:
        # Verify user is room owner
        user_id = user["sub"] if isinstance(user, dict) else user.sub
        
        room = await room_service.get_room_details(room_id)
        if not room:
            raise HTTPException(status_code=404, detail="Room not found")
        
        if room["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Only room owner can start voting")
        
        # Get recommendations
        recommendations_data = await room_service.get_room_recommendations(room_id)
        if not recommendations_data:
            raise HTTPException(status_code=404, detail="No recommendations available")
        
        recommendations = recommendations_data.get("recommendations", [])
        if not recommendations:
            raise HTTPException(status_code=404, detail="No recommendations available")
        
        # Transform recommendations to match WebSocket manager expectations
        transformed_recommendations = []
        for rec in recommendations:
            if isinstance(rec, dict):
                # Convert tmdb_id to movie_id for WebSocket compatibility
                transformed_rec = {
                    "movie_id": str(rec.get("tmdb_id", rec.get("movie_id", ""))),
                    "title": rec.get("title", "Unknown"),
                    "poster_path": rec.get("poster_path"),
                    "group_score": rec.get("group_score", 0.8),
                    "reasons": rec.get("reasons", ["Recommended by AI"]),
                    "participants_who_liked": rec.get("participants_who_liked", [])
                }
                transformed_recommendations.append(transformed_rec)
        
        # Start voting session via WebSocket
        from app.websocket_manager import manager
        await manager.start_voting_session(room_id, transformed_recommendations)
        
        return {
            "status": "success",
            "message": "Voting session started",
            "movie_count": len(recommendations)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to start voting session")
