import time
import json
import asyncio
from datetime import datetime
from app.celery_worker import celery_app
from app.core.config import settings
from app.agents.azure_openai_agent import AzureOpenAIAgent

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
    """Generates personal recommendations for a user using AI assistants."""
    try:
        agent = AzureOpenAIAgent()
        
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
        
        # Generate AI-powered recommendations
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            print(f"Generating AI recommendations for user {user_id}")
            recommendations = loop.run_until_complete(
                agent.generate_personal_recommendations(user_id, taste_profile)
            )
            
            # Ensure recommendations have the correct structure
            if not recommendations or not isinstance(recommendations, dict):
                print(f"AI returned invalid recommendations for {user_id}, using fallback")
                recommendations = _create_minimal_fallback_recommendations(user_id)
            
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
        # Emergency fallback
        fallback_recs = _create_minimal_fallback_recommendations(user_id)
        fallback_recs["generation_method"] = "emergency_fallback"
        fallback_recs["error"] = str(e)
        return fallback_recs

def _create_minimal_fallback_recommendations(user_id: str):
    """Minimal fallback when AI completely fails - returns popular/trending movies."""
    return {
        "user_id": user_id,
        "recommendations": [
            {
                "movie_id": "tt0111161",
                "title": "The Shawshank Redemption",
                "poster_path": "/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg",
                "confidence_score": 0.7,
                "reasoning": "Highly rated classic film (emergency fallback recommendation)"
            },
            {
                "movie_id": "tt0068646", 
                "title": "The Godfather",
                "poster_path": "/3bhkrj58Vtu7enYsRolD1fZdja1.jpg",
                "confidence_score": 0.7,
                "reasoning": "Acclaimed masterpiece (emergency fallback recommendation)"
            }
        ],
        "generated_at": datetime.utcnow().isoformat(),
        "generation_method": "minimal_fallback"
    }

@celery_app.task(name="tasks.find_group_recommendations") 
def find_group_recommendations(room_id: str, taste_profiles: list):
    """Generates group recommendations for a room using AI assistants."""
    try:
        agent = AzureOpenAIAgent()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            print(f"Generating AI group recommendations for room {room_id}")
            
            # Use AI to generate group recommendations
            recommendations = loop.run_until_complete(
                agent.generate_group_recommendations(room_id, taste_profiles)
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

@celery_app.task(name="tasks.generate_moodboard_assets")
def generate_moodboard_assets(movie_id: int):
    """Generates moodboard assets for a movie using AI."""
    try:
        agent = AzureOpenAIAgent()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Get movie details first
            from app.services.tmdb_service import TMDBService
            tmdb_service = TMDBService()
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
            
            print(f"AI-powered moodboard for movie {movie_id} successfully generated.")
            return moodboard
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating moodboard for movie {movie_id}: {e}")
        return None

@celery_app.task(name="tasks.refresh_recommendations_for_all_users")
def refresh_recommendations_for_all_users():
    """Refresh AI-powered recommendations for all users (daily task)."""
    try:
        from app.crud.user_crud import UserCRUD
        from app.crud.review_crud import ReviewCRUD
        
        user_crud = UserCRUD()
        review_crud = ReviewCRUD()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Get all users
            users = loop.run_until_complete(user_crud.get_all_users())
            print(f"Starting AI recommendation refresh for {len(users)} users")
            
            for user in users:
                user_id = user.get('user_id')
                if not user_id:
                    continue
                
                try:
                    # Check if user has reviews (for taste profile generation)
                    reviews = loop.run_until_complete(review_crud.get_reviews_by_user(user_id))
                    
                    # Always queue taste profile regeneration (AI will improve over time)
                    generate_taste_profile.delay(user_id)
                    
                    # Queue recommendation generation
                    generate_personal_recommendations.delay(user_id)
                    
                    print(f"Queued AI recommendation refresh for user {user_id}")
                    
                except Exception as e:
                    print(f"Error processing user {user_id}: {e}")
                    continue
                    
        finally:
            loop.close()
            
        print("AI-powered recommendation refresh for all users completed.")
        
    except Exception as e:
        print(f"Error in refresh_recommendations_for_all_users: {e}") 