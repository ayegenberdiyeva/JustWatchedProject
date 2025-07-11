import time
import json
import asyncio
from datetime import datetime
from app.celery_worker import celery_app
from app.core.config import settings
from app.agents.azure_openai_agent import AzureOpenAIAgent
from app.services.tmdb_service import TMDBService

@celery_app.task(name="tasks.generate_taste_profile")
def generate_taste_profile(user_id: str):
    """Asynchronously generates and saves user taste profile using AI analysis."""
    try:
        agent = AzureOpenAIAgent()
        
        # Get user reviews to analyze
        from app.crud.review_crud import ReviewCRUD
        review_crud = ReviewCRUD()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            reviews = loop.run_until_complete(review_crud.get_reviews_by_user(user_id))
            
            if not reviews:
                print(f"No reviews found for user {user_id}")
                # Create a basic taste profile for new users
                taste_profile = {
                    "user_id": user_id,
                    "favorite_genres": [],
                    "favorite_actors": [],
                    "favorite_directors": [],
                    "mood_preferences": [],
                    "preferred_era": "modern",
                    "preferred_language": "english",
                    "analysis_confidence": 0.0,
                    "created_at": datetime.utcnow().isoformat()
                }
            else:
                # Use AI to analyze taste profile
                taste_profile = loop.run_until_complete(
                    agent.analyze_taste_profile(user_id, reviews)
                )
                taste_profile["created_at"] = datetime.utcnow().isoformat()
            
            # Save taste profile
            from app.crud.taste_profile_crud import TasteProfileCRUD
            taste_crud = TasteProfileCRUD()
            loop.run_until_complete(taste_crud.save_taste_profile(user_id, taste_profile))
            
            print(f"Taste profile for {user_id} successfully created using AI analysis.")
            return taste_profile
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating taste profile for {user_id}: {e}")
        return None

@celery_app.task(name="tasks.generate_personal_recommendations")
def generate_personal_recommendations(user_id: str, taste_profile: dict = None):
    """Generates personal recommendations for a user using AI assistants with real TMDB data."""
    try:
        agent = AzureOpenAIAgent()
        tmdb_service = TMDBService()
        
        # Get taste profile if not provided
        if not taste_profile:
            from app.crud.taste_profile_crud import TasteProfileCRUD
            taste_crud = TasteProfileCRUD()
            
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                taste_profile = loop.run_until_complete(taste_crud.get_taste_profile(user_id))
                if not taste_profile:
                    print(f"No taste profile found for user {user_id}. Generating one first.")
                    # Trigger taste profile generation
                    generate_taste_profile.delay(user_id)
                    return None
            finally:
                loop.close()
        
        # Get user's watched movies to filter out
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            from app.crud.review_crud import ReviewCRUD
            review_crud = ReviewCRUD()
            user_reviews = loop.run_until_complete(review_crud.get_reviews_by_user(user_id))
            watched_movie_ids = [review.get("media_id") for review in user_reviews if review.get("media_id")]
            
            print(f"Generating AI recommendations for user {user_id}")
            
            # Get candidate movies from TMDB based on taste profile
            candidate_movies = loop.run_until_complete(
                tmdb_service.search_candidate_movies(taste_profile, limit=50)
            )
            
            # Filter out already watched movies
            filtered_candidates = [
                movie for movie in candidate_movies 
                if movie["id"] not in watched_movie_ids
            ]
            
            # If no candidates, use trending movies as fallback
            if not filtered_candidates:
                filtered_candidates = loop.run_until_complete(
                    tmdb_service.get_trending_movies(limit=20)
                )
                filtered_candidates = [
                    movie for movie in filtered_candidates 
                    if movie["id"] not in watched_movie_ids
                ]
            
            if not filtered_candidates:
                print(f"No suitable movies found for user {user_id}, using minimal fallback")
                recommendations = _create_tmdb_fallback_recommendations(user_id, tmdb_service, loop)
            else:
                # Prepare candidate movies for AI
                candidate_data = []
                seen_movie_ids = set()  # Track seen movie IDs to avoid duplicates
                
                for movie in filtered_candidates[:30]:  # Limit to top 30 for AI processing
                    if movie["id"] not in seen_movie_ids:  # Only add if not already seen
                        candidate_data.append({
                            "tmdb_id": movie["id"],
                            "title": movie["title"],
                            "overview": movie.get("overview", ""),
                            "genre_ids": movie.get("genre_ids", []),  # Keep as integer IDs
                            "release_date": movie.get("release_date", ""),
                            "poster_path": movie.get("poster_path"),
                            "vote_average": movie.get("vote_average", 0)
                        })
                        seen_movie_ids.add(movie["id"])
                
                # Generate AI-powered recommendations from real movie data
                recommendations = loop.run_until_complete(
                    _generate_ai_recommendations_from_candidates(agent, user_id, taste_profile, candidate_data)
                )
            
            # Ensure recommendations have the correct structure
            if not recommendations or not isinstance(recommendations, dict):
                print(f"AI returned invalid recommendations for {user_id}, using fallback")
                recommendations = _create_tmdb_fallback_recommendations(user_id, tmdb_service, loop)
            
            # Deduplicate recommendations by tmdb_id
            if "recommendations" in recommendations and isinstance(recommendations["recommendations"], list):
                seen_ids = set()
                unique_recommendations = []
                
                for rec in recommendations["recommendations"]:
                    if isinstance(rec, dict) and "tmdb_id" in rec:
                        movie_id = str(rec["tmdb_id"])
                        if movie_id not in seen_ids:
                            seen_ids.add(movie_id)
                            unique_recommendations.append(rec)
                
                recommendations["recommendations"] = unique_recommendations
                print(f"Deduplicated recommendations for {user_id}: {len(unique_recommendations)} unique movies")
            
            # Add metadata
            recommendations["user_id"] = user_id
            recommendations["generated_at"] = datetime.utcnow().isoformat()
            recommendations["generation_method"] = "ai_primary"
            
            # Cache recommendations in Redis
            from app.core.redis_client import redis_client
            redis_client.setex(
                f"user:{user_id}:recommendations",
                86400,  # 24 hours
                json.dumps(recommendations)
            )
            
            print(f"AI-powered personal recommendations for {user_id} successfully generated.")
            return recommendations
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating personal recommendations for {user_id}: {e}")
        # Emergency fallback with TMDB data
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                tmdb_service = TMDBService()
                fallback_recs = _create_tmdb_fallback_recommendations(user_id, tmdb_service, loop)
                fallback_recs["generation_method"] = "emergency_fallback"
                fallback_recs["error"] = str(e)
                return fallback_recs
            finally:
                loop.close()
        except Exception as fallback_error:
            print(f"Even fallback failed for {user_id}: {fallback_error}")
            return _create_minimal_fallback_recommendations(user_id)

async def _generate_ai_recommendations_from_candidates(agent, user_id: str, taste_profile: dict, candidate_data: list) -> dict:
    """Generate AI recommendations from a list of real movie candidates."""
    import json
    
    messages = [
        {"role": "system", "content": (
            "You are a movie recommendation expert. You will receive a list of real movies from TMDB "
            "and a user's taste profile. Your task is to select the best 20 movies from the provided list "
            "that match the user's preferences.\n\n"
            "IMPORTANT RULES:\n"
            "1. Only use movies from the provided candidate list.\n"
            "2. Each movie can appear ONLY ONCE in your recommendations.\n"
            "3. Do not duplicate any movie titles or IDs.\n"
            "4. Select exactly 20 unique movies.\n\n"
            "Return a JSON object with this exact structure:\n"
            "{\n"
            '  "recommendations": [\n'
            '    {\n'
            '      "tmdb_id": "movie_id_from_list",\n'
            '      "title": "movie_title_from_list",\n'
            '      "poster_path": "poster_path_from_list",\n'
            '      "confidence_score": 0.85,\n'
            '      "reasoning": "explanation of why this movie matches the user\'s taste"\n'
            '    }\n'
            '  ],\n'
            '  "generated_at": "timestamp"\n'
            "}\n\n"
            "CRITICAL: Ensure no duplicate tmdb_id values in the recommendations array."
        )},
        {"role": "user", "content": f"User Taste Profile: {json.dumps(taste_profile, ensure_ascii=False)}\n\nCandidate Movies: {json.dumps(candidate_data, ensure_ascii=False)}"}
    ]
    
    return agent.chat(messages, temperature=0.7, max_tokens=6000)

def _create_tmdb_fallback_recommendations(user_id: str, tmdb_service: TMDBService, loop) -> dict:
    """Create fallback recommendations using real TMDB trending/popular movies."""
    try:
        # Get trending movies from TMDB
        trending_movies = loop.run_until_complete(tmdb_service.get_trending_movies(limit=10))
        
        recommendations = []
        for movie in trending_movies:
            recommendations.append({
                "tmdb_id": str(movie["id"]),
                "title": movie["title"],
                "poster_path": movie.get("poster_path"),
                "confidence_score": 0.7,
                "reasoning": f"Trending movie: {movie.get('overview', 'Popular film')[:100]}..."
            })
        
        return {
            "user_id": user_id,
            "recommendations": recommendations,
            "generated_at": datetime.utcnow().isoformat(),
            "generation_method": "tmdb_fallback"
        }
    except Exception as e:
        print(f"TMDB fallback failed: {e}")
        return _create_minimal_fallback_recommendations(user_id)

def _create_minimal_fallback_recommendations(user_id: str):
    """Minimal fallback when everything fails - returns popular/trending movies from TMDB."""
    return {
        "user_id": user_id,
        "recommendations": [
            {
                "tmdb_id": "550",
                "title": "Fight Club",
                "poster_path": "/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg",
                "confidence_score": 0.7,
                "reasoning": "Highly rated classic film (emergency fallback recommendation)"
            },
            {
                "tmdb_id": "13", 
                "title": "Forrest Gump",
                "poster_path": "/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg",
                "confidence_score": 0.7,
                "reasoning": "Acclaimed masterpiece (emergency fallback recommendation)"
            }
        ],
        "generated_at": datetime.utcnow().isoformat(),
        "generation_method": "minimal_fallback"
    }

@celery_app.task(name="tasks.find_group_recommendations") 
def find_group_recommendations(room_id: str, taste_profiles: list):
    """Generates group recommendations for a room using AI assistants with real TMDB data."""
    try:
        agent = AzureOpenAIAgent()
        tmdb_service = TMDBService()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            print(f"Generating AI group recommendations for room {room_id}")
            
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
            candidate_movies = loop.run_until_complete(
                tmdb_service.search_candidate_movies(aggregated_profile, limit=40)
            )
            
            # If no candidates, use trending movies as fallback
            if not candidate_movies:
                candidate_movies = loop.run_until_complete(
                    tmdb_service.get_trending_movies(limit=20)
                )
            
            if not candidate_movies:
                print(f"No suitable movies found for room {room_id}")
                recommendations = {
                    "room_id": room_id,
                    "recommendations": [],
                    "generated_at": datetime.utcnow().isoformat(),
                    "generation_method": "no_candidates"
                }
            else:
                # Prepare candidate movies for AI
                candidate_data = []
                seen_movie_ids = set()  # Track seen movie IDs to avoid duplicates
                
                for movie in candidate_movies[:25]:  # Limit to top 25 for AI processing
                    if movie["id"] not in seen_movie_ids:  # Only add if not already seen
                        candidate_data.append({
                            "tmdb_id": movie["id"],
                            "title": movie["title"],
                            "overview": movie.get("overview", ""),
                            "genre_ids": movie.get("genre_ids", []),  # Keep as integer IDs
                            "release_date": movie.get("release_date", ""),
                            "poster_path": movie.get("poster_path"),
                            "vote_average": movie.get("vote_average", 0)
                        })
                        seen_movie_ids.add(movie["id"])
                
                # Generate AI-powered group recommendations from real movie data
                recommendations = loop.run_until_complete(
                    _generate_ai_group_recommendations_from_candidates(agent, room_id, taste_profiles, candidate_data)
                )
            
            # Ensure valid structure
            if not recommendations or not isinstance(recommendations, dict):
                print(f"AI returned invalid group recommendations for room {room_id}")
                recommendations = {
                    "room_id": room_id,
                    "recommendations": [],
                    "generated_at": datetime.utcnow().isoformat(),
                    "generation_method": "ai_failed"
                }
            
            # Deduplicate recommendations by tmdb_id
            if "recommendations" in recommendations and isinstance(recommendations["recommendations"], list):
                seen_ids = set()
                unique_recommendations = []
                
                for rec in recommendations["recommendations"]:
                    if isinstance(rec, dict) and "tmdb_id" in rec:
                        movie_id = str(rec["tmdb_id"])
                        if movie_id not in seen_ids:
                            seen_ids.add(movie_id)
                            unique_recommendations.append(rec)
                
                recommendations["recommendations"] = unique_recommendations
                print(f"Deduplicated group recommendations for room {room_id}: {len(unique_recommendations)} unique movies")
            
            # Add metadata
            recommendations["room_id"] = room_id
            recommendations["generated_at"] = datetime.utcnow().isoformat()
            recommendations["generation_method"] = "ai_group"
            
            # Save and deliver recommendations
            from app.services.room_service import RoomService
            room_service = RoomService()
            loop.run_until_complete(
                room_service.save_and_deliver_recommendations(room_id, recommendations)
            )
            
            # Update room status
            from app.crud.room_crud import RoomCRUD
            room_crud = RoomCRUD()
            loop.run_until_complete(
                room_crud.update_room(room_id, {"status": "active"})
            )
            
            print(f"AI-powered group recommendations for room {room_id} successfully generated.")
            return recommendations
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating group recommendations for room {room_id}: {e}")
        # Update room status to active even if failed
        try:
            from app.crud.room_crud import RoomCRUD
            room_crud = RoomCRUD()
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                loop.run_until_complete(
                    room_crud.update_room(room_id, {"status": "active"})
                )
            finally:
                loop.close()
        except:
            pass
        return None

async def _generate_ai_group_recommendations_from_candidates(agent, room_id: str, taste_profiles: list, candidate_data: list) -> dict:
    """Generate AI group recommendations from a list of real movie candidates."""
    import json
    
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
    
    return agent.chat(messages, temperature=0.6, max_tokens=6000)

@celery_app.task(name="tasks.generate_moodboard_assets")
def generate_moodboard_assets(movie_id: int):
    """Generates moodboard assets for a movie using AI with real TMDB data."""
    try:
        agent = AzureOpenAIAgent()
        tmdb_service = TMDBService()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Get movie details first from TMDB
            movie_details = loop.run_until_complete(tmdb_service.get_movie_details(movie_id))
            
            print(f"Generating AI moodboard for movie {movie_id}")
            
            # Generate moodboard using AI
            moodboard = loop.run_until_complete(
                agent.generate_moodboard(movie_id, movie_details)
            )
            
            # Add metadata
            if moodboard:
                moodboard["movie_id"] = movie_id
                moodboard["generated_at"] = datetime.utcnow().isoformat()
                moodboard["generation_method"] = "ai_creative"
            
            # Save moodboard to database
            from app.crud.moodboard_crud import MoodboardCRUD
            moodboard_crud = MoodboardCRUD()
            loop.run_until_complete(
                moodboard_crud.save_moodboard(movie_id, moodboard)
            )
            
            print(f"AI moodboard for movie {movie_id} successfully generated.")
            return moodboard
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating moodboard for movie {movie_id}: {e}")
        return None

@celery_app.task(name="tasks.refresh_recommendations_for_all_users")
def refresh_recommendations_for_all_users():
    """Refresh AI-powered recommendations for all users (scheduled task)."""
    try:
        from app.crud.user_crud import UserCRUD
        from app.crud.review_crud import ReviewCRUD
        from app.core.redis_client import redis_client
        
        user_crud = UserCRUD()
        review_crud = ReviewCRUD()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Get all users
            users = loop.run_until_complete(user_crud.get_all_users())
            print(f"Starting AI recommendation refresh for {len(users)} users")
            
            processed_count = 0
            skipped_count = 0
            
            for user in users:
                user_id = user.get('user_id')
                if not user_id:
                    continue
                
                try:
                    # Check if user has reviews (for taste profile generation)
                    reviews = loop.run_until_complete(review_crud.get_reviews_by_user(user_id))
                    
                    # Check if recommendations already exist and are recent (within 12 hours)
                    cache_key = f"user:{user_id}:recommendations"
                    existing_data = redis_client.get(cache_key)
                    
                    if existing_data:
                        # Parse existing recommendations to check timestamp
                        try:
                            existing_recs = json.loads(existing_data)
                            generated_at = existing_recs.get("generated_at")
                            if generated_at:
                                from datetime import datetime, timezone
                                generated_time = datetime.fromisoformat(generated_at.replace('Z', '+00:00'))
                                current_time = datetime.now(timezone.utc)
                                hours_diff = (current_time - generated_time).total_seconds() / 3600
                                
                                # Skip if recommendations are less than 12 hours old
                                if hours_diff < 12:
                                    print(f"Skipping user {user_id} - recommendations are {hours_diff:.1f} hours old")
                                    skipped_count += 1
                                    continue
                        except Exception:
                            # If parsing fails, regenerate anyway
                            pass
                    
                    # Only process users with reviews or if no recent recommendations exist
                    if reviews:
                        # User has reviews - regenerate taste profile and recommendations
                        generate_taste_profile.delay(user_id)
                        generate_personal_recommendations.delay(user_id)
                        print(f"Queued AI recommendation refresh for user {user_id} (has {len(reviews)} reviews)")
                    else:
                        # User has no reviews - just generate trending fallback
                        # This will be handled by the API endpoint when user requests recommendations
                        print(f"Skipping user {user_id} - no reviews yet")
                        skipped_count += 1
                        continue
                    
                    processed_count += 1
                    
                except Exception as e:
                    print(f"Error processing user {user_id}: {e}")
                    continue
                    
        finally:
            loop.close()
            
        print(f"AI-powered recommendation refresh completed. Processed: {processed_count}, Skipped: {skipped_count}")
        
    except Exception as e:
        print(f"Error in refresh_recommendations_for_all_users: {e}") 