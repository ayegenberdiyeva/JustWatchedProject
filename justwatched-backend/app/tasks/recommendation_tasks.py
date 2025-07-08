import time
import json
import asyncio
from app.celery_worker import celery_app
from app.core.config import settings
from app.agents.azure_openai_agent import AzureOpenAIAgent

@celery_app.task(name="tasks.generate_taste_profile")
def generate_taste_profile(user_id: str):
    """Asynchronously generates and saves user taste profile."""
    try:
        agent = AzureOpenAIAgent()
        
        # Get user reviews to analyze
        from app.crud.review_crud import ReviewCRUD
        review_crud = ReviewCRUD()
        
        # This would need to be run in an async context
        # For now, we'll use a synchronous approach
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            reviews = loop.run_until_complete(review_crud.get_reviews_by_user(user_id))
            
            if not reviews:
                print(f"No reviews found for user {user_id}")
                return None
            
            # Analyze taste profile using Azure OpenAI
            taste_profile = loop.run_until_complete(
                agent.analyze_taste_profile(user_id, reviews)
            )
            
            # Save taste profile
            from app.crud.taste_profile_crud import TasteProfileCRUD
            taste_crud = TasteProfileCRUD()
            loop.run_until_complete(taste_crud.save_taste_profile(user_id, taste_profile))
            
            print(f"Taste profile for {user_id} successfully created.")
            return taste_profile
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating taste profile for {user_id}: {e}")
        return None

@celery_app.task(name="tasks.generate_personal_recommendations")
def generate_personal_recommendations(user_id: str, taste_profile: dict = None):
    """Generates personal recommendations for a user."""
    try:
        agent = AzureOpenAIAgent()
        
        # If no taste profile provided, get it from database
        if not taste_profile:
            from app.crud.taste_profile_crud import TasteProfileCRUD
            taste_crud = TasteProfileCRUD()
            
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                taste_profile = loop.run_until_complete(taste_crud.get_taste_profile(user_id))
                if not taste_profile:
                    print(f"No taste profile found for user {user_id}")
                    return None
            finally:
                loop.close()
        
        # Generate recommendations
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            recommendations = loop.run_until_complete(
                agent.generate_personal_recommendations(user_id, taste_profile)
            )
            
            # Cache recommendations in Redis
            from app.core.redis_client import redis_client
            import json
            redis_client.setex(
                f"user:{user_id}:recommendations",
                86400,  # 24 hours
                json.dumps(recommendations)
            )
            
            print(f"Personal recommendations for {user_id} successfully generated.")
            return recommendations
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating personal recommendations for {user_id}: {e}")
        return None

@celery_app.task(name="tasks.find_group_recommendations")
def find_group_recommendations(room_id: str, taste_profiles: list):
    """Generates group recommendations for a room."""
    try:
        agent = AzureOpenAIAgent()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Generate group recommendations
            recommendations = loop.run_until_complete(
                agent.generate_group_recommendations(room_id, taste_profiles)
            )
            
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
            
            print(f"Group recommendations for room {room_id} successfully generated.")
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
    """Generates moodboard assets for a movie."""
    try:
        agent = AzureOpenAIAgent()
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        try:
            # Get movie details first
            from app.services.tmdb_service import TMDBService
            tmdb_service = TMDBService()
            movie_details = loop.run_until_complete(tmdb_service.get_movie_details(movie_id))
            
            # Generate moodboard
            moodboard = loop.run_until_complete(
                agent.generate_moodboard(movie_id, movie_details)
            )
            
            # Save moodboard to database
            from app.crud.moodboard_crud import MoodboardCRUD
            moodboard_crud = MoodboardCRUD()
            loop.run_until_complete(
                moodboard_crud.save_moodboard(movie_id, moodboard)
            )
            
            print(f"Moodboard for movie {movie_id} successfully generated.")
            return moodboard
            
        finally:
            loop.close()
            
    except Exception as e:
        print(f"Error generating moodboard for movie {movie_id}: {e}")
        return None

@celery_app.task(name="tasks.refresh_recommendations_for_all_users")
def refresh_recommendations_for_all_users():
    """Refresh recommendations for all users (daily task)."""
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
            
            for user in users:
                user_id = user.get('user_id')
                if not user_id:
                    continue
                
                try:
                    # Get user reviews
                    reviews = loop.run_until_complete(review_crud.get_reviews_by_user(user_id))
                    
                    if reviews:
                        # Analyze taste profile
                        generate_taste_profile.delay(user_id)
                        
                        # Generate recommendations
                        generate_personal_recommendations.delay(user_id)
                        
                        print(f"Queued recommendation refresh for user {user_id}")
                    
                except Exception as e:
                    print(f"Error processing user {user_id}: {e}")
                    continue
                    
        finally:
            loop.close()
            
        print("Recommendation refresh for all users completed.")
        
    except Exception as e:
        print(f"Error in refresh_recommendations_for_all_users: {e}") 