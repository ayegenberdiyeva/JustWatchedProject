import json
import asyncio
from typing import Dict, Set, List, Optional
from fastapi import WebSocket, WebSocketDisconnect
from app.core.redis_client import redis_client
import logging

logger = logging.getLogger(__name__)

class ConnectionManager:
    def __init__(self):
        # Store active connections: {user_id: WebSocket}
        self.active_connections: Dict[str, WebSocket] = {}
        # Store room participants: {room_id: Set[user_id]}
        self.room_participants: Dict[str, Set[str]] = {}
        # Store voting state: {room_id: {movie_id: {user_id: vote}}}
        self.voting_state: Dict[str, Dict[str, Dict[str, str]]] = {}
        # Store current movie index: {room_id: int}
        self.current_movie_index: Dict[str, int] = {}
        # Store room recommendations: {room_id: List[movie]}
        self.room_recommendations: Dict[str, List[dict]] = {}

    async def connect(self, websocket: WebSocket, user_id: str):
        """Connect a user to the WebSocket."""
        await websocket.accept()
        self.active_connections[user_id] = websocket
        logger.info(f"User {user_id} connected to WebSocket")

    def disconnect(self, user_id: str):
        """Disconnect a user from the WebSocket."""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
            # Remove from all rooms
            for room_id in list(self.room_participants.keys()):
                if user_id in self.room_participants[room_id]:
                    self.room_participants[room_id].remove(user_id)
                    if not self.room_participants[room_id]:
                        del self.room_participants[room_id]
            logger.info(f"User {user_id} disconnected from WebSocket")

    async def join_room(self, user_id: str, room_id: str):
        """Add user to a room's WebSocket group."""
        if room_id not in self.room_participants:
            self.room_participants[room_id] = set()
        self.room_participants[room_id].add(user_id)
        
        # Send join confirmation
        await self.send_personal_message(user_id, {
            "type": "room_joined",
            "room_id": room_id,
            "message": "Successfully joined room"
        })
        
        # Notify other participants
        await self.broadcast_to_room(room_id, {
            "type": "user_joined",
            "user_id": user_id,
            "room_id": room_id,
            "participant_count": len(self.room_participants[room_id])
        }, exclude_user=user_id)
        
        logger.info(f"User {user_id} joined room {room_id}")

    async def leave_room(self, user_id: str, room_id: str):
        """Remove user from a room's WebSocket group."""
        if room_id in self.room_participants and user_id in self.room_participants[room_id]:
            self.room_participants[room_id].remove(user_id)
            
            # Notify other participants
            await self.broadcast_to_room(room_id, {
                "type": "user_left",
                "user_id": user_id,
                "room_id": room_id,
                "participant_count": len(self.room_participants[room_id])
            })
            
            # Clean up empty rooms
            if not self.room_participants[room_id]:
                del self.room_participants[room_id]
                if room_id in self.voting_state:
                    del self.voting_state[room_id]
                if room_id in self.current_movie_index:
                    del self.current_movie_index[room_id]
                if room_id in self.room_recommendations:
                    del self.room_recommendations[room_id]
            
            logger.info(f"User {user_id} left room {room_id}")

    async def send_personal_message(self, user_id: str, message: dict):
        """Send a message to a specific user."""
        if user_id in self.active_connections:
            try:
                await self.active_connections[user_id].send_text(json.dumps(message))
            except Exception as e:
                logger.error(f"Failed to send message to user {user_id}: {e}")
                self.disconnect(user_id)

    async def broadcast_to_room(self, room_id: str, message: dict, exclude_user: str = None):
        """Send a message to all users in a room."""
        if room_id not in self.room_participants:
            return
        
        disconnected_users = []
        for user_id in self.room_participants[room_id]:
            if user_id != exclude_user and user_id in self.active_connections:
                try:
                    await self.active_connections[user_id].send_text(json.dumps(message))
                except Exception as e:
                    logger.error(f"Failed to send message to user {user_id}: {e}")
                    disconnected_users.append(user_id)
        
        # Clean up disconnected users
        for user_id in disconnected_users:
            self.disconnect(user_id)

    async def start_voting_session(self, room_id: str, recommendations: List[dict]):
        """Start a voting session for a room."""
        self.room_recommendations[room_id] = recommendations
        self.current_movie_index[room_id] = 0
        self.voting_state[room_id] = {}
        
        # Initialize voting state for each movie
        for movie in recommendations:
            self.voting_state[room_id][movie["movie_id"]] = {}
        
        # Send first movie to all participants
        await self.send_current_movie(room_id)
        
        logger.info(f"Started voting session for room {room_id} with {len(recommendations)} movies")

    async def send_current_movie(self, room_id: str):
        """Send the current movie to all participants in the room."""
        if room_id not in self.room_recommendations or room_id not in self.current_movie_index:
            return
        
        current_index = self.current_movie_index[room_id]
        recommendations = self.room_recommendations[room_id]
        
        if current_index >= len(recommendations):
            # All movies have been voted on
            await self.calculate_final_result(room_id)
            return
        
        current_movie = recommendations[current_index]
        
        await self.broadcast_to_room(room_id, {
            "type": "current_movie",
            "room_id": room_id,
            "movie": current_movie,
            "movie_index": current_index + 1,
            "total_movies": len(recommendations),
            "voting_deadline": None  # Could add timeout logic here
        })

    async def record_vote(self, room_id: str, user_id: str, movie_id: str, vote: str):
        """Record a user's vote for a movie."""
        if room_id not in self.voting_state or movie_id not in self.voting_state[room_id]:
            return False
        
        # Record the vote
        self.voting_state[room_id][movie_id][user_id] = vote
        
        # Notify other participants about the vote
        await self.broadcast_to_room(room_id, {
            "type": "vote_recorded",
            "room_id": room_id,
            "user_id": user_id,
            "movie_id": movie_id,
            "vote": vote
        }, exclude_user=user_id)
        
        # Check if all participants have voted on current movie
        current_index = self.current_movie_index[room_id]
        current_movie_id = self.room_recommendations[room_id][current_index]["movie_id"]
        participant_count = len(self.room_participants[room_id])
        votes_count = len(self.voting_state[room_id][current_movie_id])
        
        if votes_count >= participant_count:
            # All participants have voted, move to next movie
            await self.move_to_next_movie(room_id)
        
        return True

    async def move_to_next_movie(self, room_id: str):
        """Move to the next movie in the voting session."""
        self.current_movie_index[room_id] += 1
        
        # Send next movie or finish session
        await self.send_current_movie(room_id)

    async def calculate_final_result(self, room_id: str):
        """Calculate the final result based on all votes."""
        if room_id not in self.voting_state or room_id not in self.room_recommendations:
            return
        
        # Calculate scores for each movie
        movie_scores = {}
        for movie_id, votes in self.voting_state[room_id].items():
            likes = sum(1 for vote in votes.values() if vote == "like")
            total_votes = len(votes)
            if total_votes > 0:
                movie_scores[movie_id] = likes / total_votes
            else:
                movie_scores[movie_id] = 0
        
        # Find the movie with the highest score
        best_movie_id = max(movie_scores.keys(), key=lambda k: movie_scores[k])
        best_score = movie_scores[best_movie_id]
        
        # Find the movie details
        best_movie = None
        for movie in self.room_recommendations[room_id]:
            if movie["movie_id"] == best_movie_id:
                best_movie = movie
                break
        
        if best_movie:
            result = {
                "type": "voting_result",
                "room_id": room_id,
                "winner": best_movie,
                "score": best_score,
                "all_scores": movie_scores,
                "total_participants": len(self.room_participants[room_id])
            }
            
            # Broadcast result to all participants
            await self.broadcast_to_room(room_id, result)
            
            # Clean up voting state
            if room_id in self.voting_state:
                del self.voting_state[room_id]
            if room_id in self.current_movie_index:
                del self.current_movie_index[room_id]
            if room_id in self.room_recommendations:
                del self.room_recommendations[room_id]
            
            logger.info(f"Voting completed for room {room_id}. Winner: {best_movie['title']}")

    async def send_group_recommendations(self, room_id: str, recommendations: List[dict]):
        """Send group recommendations to all participants in a room."""
        await self.broadcast_to_room(room_id, {
            "type": "group_recommendations",
            "room_id": room_id,
            "recommendations": recommendations,
            "participant_count": len(self.room_participants.get(room_id, set()))
        })

# Global connection manager instance
manager = ConnectionManager()

# Legacy function for backward compatibility
def send_group_recommendations(room_id, group_recommendations):
    """Legacy function - now uses async WebSocket manager."""
    asyncio.create_task(manager.send_group_recommendations(room_id, group_recommendations)) 