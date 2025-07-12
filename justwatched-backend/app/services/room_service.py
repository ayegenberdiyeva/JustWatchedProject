from app.crud.room_crud import RoomCRUD
from app.crud.taste_profile_crud import TasteProfileCRUD
from app.crud.review_crud import ReviewCRUD
from app.websocket_manager import manager
from app.agents.azure_openai_agent import AzureOpenAIAgent
from app.services.tmdb_service import TMDBService
from typing import List, Dict, Any, Optional
import json

class RoomService:
    def __init__(self):
        self.room_crud = RoomCRUD()
        self.taste_profile_crud = TasteProfileCRUD()
        self.review_crud = ReviewCRUD()
        self.ai_agent = AzureOpenAIAgent()
        self.tmdb_service = TMDBService()

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

    async def ensure_taste_profile_for_user(self, user_id: str) -> dict:
        """Ensure a user has a taste profile by analyzing their reviews if needed."""
        # Check if user already has a taste profile
        existing_profile = await self.taste_profile_crud.get_taste_profile(user_id)
        if existing_profile and existing_profile.get("favorite_genres"):
            return existing_profile
        
        # Get user's reviews for analysis
        reviews = await self.review_crud.get_reviews_by_user(user_id)
        
        if not reviews:
            # Create basic profile for users with no reviews
            basic_profile = {
                "user_id": user_id,
                "favorite_genres": [],
                "favorite_actors": [],
                "favorite_directors": [],
                "mood_preferences": [],
                "analysis_confidence": 0.0
            }
            await self.taste_profile_crud.save_taste_profile(user_id, basic_profile)
            return basic_profile
        
        # Convert reviews to format expected by AI endpoint
        reviews_for_analysis = []
        for review in reviews:
            # Get movie details from TMDB for better analysis
            try:
                movie_details = await self.tmdb_service.get_movie_details(review.get("media_id"))
                reviews_for_analysis.append({
                    "movie_id": review.get("media_id"),
                    "title": review.get("media_title", movie_details.get("title", "Unknown")),
                    "rating": review.get("rating", 5),
                    "review_text": review.get("review_text", ""),
                    "genres": [genre["name"] for genre in movie_details.get("genres", [])],
                    "actors": [cast["name"] for cast in movie_details.get("credits", {}).get("cast", [])[:5]],
                    "directors": [crew["name"] for crew in movie_details.get("credits", {}).get("crew", []) 
                                if crew.get("job") == "Director"][:3],
                    "watched_date": review.get("created_at", "")
                })
            except Exception as e:
                print(f"Error getting movie details for {review.get('media_id')}: {e}")
                # Use basic review data if TMDB fails
                reviews_for_analysis.append({
                    "movie_id": review.get("media_id"),
                    "title": review.get("media_title", "Unknown"),
                    "rating": review.get("rating", 5),
                    "review_text": review.get("review_text", ""),
                    "genres": [],
                    "actors": [],
                    "directors": [],
                    "watched_date": review.get("created_at", "")
                })
        
        # Use AI to analyze taste profile
        try:
            messages = [
                {"role": "system", "content": (
                    "You are a movie taste profile analyzer.\n"
                    "Given a list of user reviews (with genres, actors, directors, ratings, and review text),\n"
                    "analyze and return a strict JSON taste_profile object with these keys: user_id, favorite_genres, favorite_actors, favorite_directors, mood_preferences.\n"
                    "Each value should be a list of strings, except user_id.\n"
                    "Strictly output only JSON, no extra text."
                )},
                {"role": "user", "content": f"Reviews: {json.dumps(reviews_for_analysis)}"}
            ]
            
            taste_profile = self.ai_agent.chat(messages)
            
            # Ensure proper format
            analyzed_profile = {
                "user_id": user_id,
                "favorite_genres": taste_profile.get("favorite_genres", []),
                "favorite_actors": taste_profile.get("favorite_actors", []),
                "favorite_directors": taste_profile.get("favorite_directors", []),
                "mood_preferences": taste_profile.get("mood_preferences", []),
                "analysis_confidence": 0.8
            }
            
            # Save the analyzed profile
            await self.taste_profile_crud.save_taste_profile(user_id, analyzed_profile)
            return analyzed_profile
            
        except Exception as e:
            print(f"Error analyzing taste profile for {user_id}: {e}")
            # Fallback to basic profile
            basic_profile = {
                "user_id": user_id,
                "favorite_genres": [],
                "favorite_actors": [],
                "favorite_directors": [],
                "mood_preferences": [],
                "analysis_confidence": 0.0
            }
            await self.taste_profile_crud.save_taste_profile(user_id, basic_profile)
            return basic_profile

    async def process_room_recommendations(self, room_id: str) -> dict:
        """Process group recommendations for a room using the correct AI flow."""
        try:
            # Update room status to processing
            await self.room_crud.update_room(room_id, {"status": "processing"})
            
            # Get all participant user IDs
            participant_ids = await self.room_crud.get_room_participants(room_id)
            
            if not participant_ids:
                await self.room_crud.update_room(room_id, {"status": "active"})
                return {"error": "No participants found in room"}
            
            # Step 1: Ensure each participant has a taste profile (equivalent to /api/v1/analyze/taste)
            taste_profiles = []
            for user_id in participant_ids:
                profile = await self.ensure_taste_profile_for_user(user_id)
                taste_profiles.append(profile)
            
            if not taste_profiles:
                await self.room_crud.update_room(room_id, {"status": "active"})
                return {"error": "Failed to generate taste profiles for participants"}
            
            # Step 2: Generate group recommendations (equivalent to /api/v1/recommend/group)
            try:
                # Aggregate group preferences
                all_genres = set()
                all_actors = set()
                all_directors = set()
                
                for profile in taste_profiles:
                    all_genres.update(profile.get("favorite_genres", []))
                    all_actors.update(profile.get("favorite_actors", []))
                    all_directors.update(profile.get("favorite_directors", []))
                
                # Create aggregated taste profile
                aggregated_profile = {
                    "favorite_genres": list(all_genres)[:5],  # Top 5 genres
                    "favorite_actors": list(all_actors)[:3],  # Top 3 actors
                    "favorite_directors": list(all_directors)[:3]  # Top 3 directors
                }
                
                # Get candidate movies from TMDB based on aggregated profile
                candidate_movies = await self.tmdb_service.search_candidate_movies(aggregated_profile, limit=40)
                
                # If no candidates, use trending movies as fallback
                if not candidate_movies:
                    candidate_movies = await self.tmdb_service.get_trending_movies(limit=20)
                
                if not candidate_movies:
                    await self.room_crud.update_room(room_id, {"status": "active"})
                    return {"error": "No suitable movies found for group"}
                
                # Prepare candidate movies for AI
                candidate_data = []
                seen_movie_ids = set()
                
                for movie in candidate_movies[:25]:
                    if movie["id"] not in seen_movie_ids:
                        candidate_data.append({
                            "tmdb_id": movie["id"],
                            "title": movie["title"],
                            "overview": movie.get("overview", ""),
                            "genre_ids": movie.get("genre_ids", []),
                            "release_date": movie.get("release_date", ""),
                            "poster_path": movie.get("poster_path"),
                            "vote_average": movie.get("vote_average", 0)
                        })
                        seen_movie_ids.add(movie["id"])
                
                # Generate AI-powered group recommendations
                messages = [
                    {"role": "system", "content": (
                        "You are a group movie recommendation expert. You will receive a list of real movies from TMDB "
                        "and multiple user taste profiles. Your task is to select 7-10 movies from the provided list "
                        "that would appeal to the group.\n\n"
                        "IMPORTANT RULES:\n"
                        "1. Only use movies from the provided candidate list.\n"
                        "2. Each movie can appear ONLY ONCE in your recommendations.\n"
                        "3. Do not duplicate any movie titles or IDs.\n"
                        "4. Select 7-10 unique movies.\n\n"
                        "Return a JSON object with this exact structure:\n"
                        "{\n"
                        '  "recommendations": [\n'
                        '    {\n'
                        '      "tmdb_id": "movie_id_from_list",\n'
                        '      "title": "movie_title_from_list",\n'
                        '      "poster_path": "poster_path_from_list",\n'
                        '      "group_score": 0.85,\n'
                        '      "reasons": ["reason1", "reason2"],\n'
                        '      "participants_who_liked": ["user_id1", "user_id2"]\n'
                        '    }\n'
                        '  ],\n'
                        '  "generated_at": "timestamp"\n'
                        "}\n\n"
                        "CRITICAL: Ensure no duplicate tmdb_id values in the recommendations array."
                    )},
                    {"role": "user", "content": f"Group Taste Profiles: {json.dumps(taste_profiles, ensure_ascii=False)}\n\nCandidate Movies: {json.dumps(candidate_data, ensure_ascii=False)}"}
                ]
                
                result = self.ai_agent.chat(messages, temperature=0.6, max_tokens=6000)
                
                # Validate and clean the response
                if not isinstance(result, dict) or "recommendations" not in result:
                    await self.room_crud.update_room(room_id, {"status": "active"})
                    return {"error": "Invalid AI response format"}
                
                # Deduplicate recommendations
                seen_ids = set()
                unique_recommendations = []
                
                for rec in result["recommendations"]:
                    if isinstance(rec, dict) and "tmdb_id" in rec:
                        movie_id = str(rec["tmdb_id"])
                        if movie_id not in seen_ids:
                            seen_ids.add(movie_id)
                            unique_recommendations.append(rec)
                
                result["recommendations"] = unique_recommendations
                result["room_id"] = room_id
                result["generated_at"] = result.get("generated_at", "")
                result["generation_method"] = "ai_group_corrected_flow"
                
                # Save and deliver recommendations
                success = await self.save_and_deliver_recommendations(room_id, result)
                
                if success:
                    # Update room status
                    await self.room_crud.update_room(room_id, {"status": "active"})
                    
                    return {
                        "status": "success",
                        "message": "Group recommendations generated successfully",
                        "participant_count": len(participant_ids),
                        "recommendation_count": len(unique_recommendations)
                    }
                else:
                    await self.room_crud.update_room(room_id, {"status": "active"})
                    return {"error": "Failed to save recommendations"}
                
            except Exception as e:
                await self.room_crud.update_room(room_id, {"status": "active"})
                return {"error": f"Failed to generate group recommendations: {str(e)}"}
            
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
                await manager.send_group_recommendations(room_id, recommendations)
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