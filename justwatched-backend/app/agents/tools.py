from app.services.user_data_service import UserDataService
from app.services.tmdb_service import TMDBService
from app.services.creative_service import CreativeService

# Instantiate service classes
user_data_service = UserDataService()
tmdb_service = TMDBService()
creative_service = CreativeService()

# Centralized registry mapping OpenAI function names to real Python functions
AVAILABLE_TOOLS = {
    "get_user_watch_history": user_data_service.get_user_watch_history,
    "search_movies": tmdb_service.search_movies,
    "get_movie_details": tmdb_service.get_movie_details,
    "find_atmospheric_images": creative_service.find_atmospheric_images,
    "find_music_tracks": creative_service.find_music_tracks,
} 