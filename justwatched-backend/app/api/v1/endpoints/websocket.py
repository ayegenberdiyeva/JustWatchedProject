from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, HTTPException
from fastapi.security import HTTPBearer
from app.core.security import verify_jwt_token
from app.websocket_manager import manager
from app.services.room_service import RoomService
import json
import logging

logger = logging.getLogger(__name__)
router = APIRouter()
room_service = RoomService()

security = HTTPBearer()

@router.websocket("/ws/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: str):
    """WebSocket endpoint for room-based movie voting."""
    try:
        # Accept the WebSocket connection
        await websocket.accept()
        
        # Get authentication token from query parameters
        token = websocket.query_params.get("token")
        if not token:
            await websocket.close(code=4001, reason="Authentication required")
            return
        
        # Verify JWT token
        try:
            user_data = verify_jwt_token(token)
            user_id = user_data["sub"]
        except Exception as e:
            logger.error(f"Invalid token in WebSocket connection: {e}")
            await websocket.close(code=4001, reason="Invalid authentication")
            return
        
        # Verify user is a participant in the room
        room = await room_service.get_room_details(room_id)
        if not room:
            await websocket.close(code=4004, reason="Room not found")
            return
        
        participant_ids = [p["user_id"] for p in room["participants"]]
        if user_id not in participant_ids:
            await websocket.close(code=4003, reason="Not a room participant")
            return
        
        # Connect user to WebSocket manager
        await manager.connect(websocket, user_id)
        
        # Join the room
        await manager.join_room(user_id, room_id)
        
        # Send current room state
        await manager.send_personal_message(user_id, {
            "type": "room_state",
            "room_id": room_id,
            "participants": room["participants"],
            "status": room["status"]
        })
        
        # Handle incoming messages
        try:
            while True:
                data = await websocket.receive_text()
                message = json.loads(data)
                
                await handle_websocket_message(user_id, room_id, message)
                
        except WebSocketDisconnect:
            logger.info(f"WebSocket disconnected for user {user_id}")
        except Exception as e:
            logger.error(f"Error in WebSocket connection for user {user_id}: {e}")
        finally:
            # Clean up connection
            manager.disconnect(user_id)
            await manager.leave_room(user_id, room_id)
            
    except Exception as e:
        logger.error(f"WebSocket connection error: {e}")
        try:
            await websocket.close(code=1011, reason="Internal server error")
        except:
            pass

async def handle_websocket_message(user_id: str, room_id: str, message: dict):
    """Handle incoming WebSocket messages."""
    message_type = message.get("type")
    
    try:
        if message_type == "vote":
            # Handle movie voting
            movie_id = message.get("movie_id")
            vote = message.get("vote")  # "like" or "dislike"
            
            if not movie_id or vote not in ["like", "dislike"]:
                await manager.send_personal_message(user_id, {
                    "type": "error",
                    "message": "Invalid vote data"
                })
                return
            
            success = await manager.record_vote(room_id, user_id, movie_id, vote)
            if not success:
                await manager.send_personal_message(user_id, {
                    "type": "error",
                    "message": "Failed to record vote"
                })
            else:
                await manager.send_personal_message(user_id, {
                    "type": "vote_confirmed",
                    "movie_id": movie_id,
                    "vote": vote
                })
        
        elif message_type == "start_voting":
            # Start voting session (only room owner can do this)
            room = await room_service.get_room_details(room_id)
            if room["owner_id"] != user_id:
                await manager.send_personal_message(user_id, {
                    "type": "error",
                    "message": "Only room owner can start voting"
                })
                return
            
            # Get room recommendations
            recommendations_data = await room_service.get_room_recommendations(room_id)
            if not recommendations_data:
                await manager.send_personal_message(user_id, {
                    "type": "error",
                    "message": "No recommendations available. Generate recommendations first."
                })
                return
            
            recommendations = recommendations_data.get("recommendations", [])
            if not recommendations:
                await manager.send_personal_message(user_id, {
                    "type": "error",
                    "message": "No recommendations available"
                })
                return
            
            # Start voting session
            await manager.start_voting_session(room_id, recommendations)
        
        elif message_type == "get_room_status":
            # Send current room status
            room = await room_service.get_room_details(room_id)
            await manager.send_personal_message(user_id, {
                "type": "room_status",
                "room_id": room_id,
                "participants": room["participants"],
                "status": room["status"],
                "current_participants": room["current_participants"],
                "max_participants": room["max_participants"]
            })
        
        elif message_type == "ping":
            # Respond to ping with pong
            await manager.send_personal_message(user_id, {
                "type": "pong",
                "timestamp": message.get("timestamp")
            })
        
        else:
            await manager.send_personal_message(user_id, {
                "type": "error",
                "message": f"Unknown message type: {message_type}"
            })
    
    except Exception as e:
        logger.error(f"Error handling WebSocket message: {e}")
        await manager.send_personal_message(user_id, {
            "type": "error",
            "message": "Internal server error"
        })

@router.post("/{room_id}/start-voting")
async def start_voting_session(room_id: str, user=Depends(security)):
    """API endpoint to start a voting session for a room."""
    try:
        # Verify user is room owner
        user_data = verify_jwt_token(user.credentials)
        user_id = user_data["sub"]
        
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
        
        # Start voting session via WebSocket
        await manager.start_voting_session(room_id, recommendations)
        
        return {
            "status": "success",
            "message": "Voting session started",
            "movie_count": len(recommendations)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error starting voting session: {e}")
        raise HTTPException(status_code=500, detail="Failed to start voting session") 