# Tools for Azure OpenAI agent
# Using local imports to avoid circular dependencies

def get_available_tools():
    """Get available tools for Azure OpenAI agent."""
    from app.services.user_data_service import UserDataService
    from app.services.tmdb_service import TMDBService
    from app.services.creative_service import CreativeService
    
    # Instantiate service classes
    user_data_service = UserDataService()
    tmdb_service = TMDBService()
    creative_service = CreativeService()
    
    # Centralized registry mapping function names to real Python functions
    return {
        "get_user_watch_history": user_data_service.get_user_watch_history,
        "search_movies": tmdb_service.search_movies,
        "get_movie_details": tmdb_service.get_movie_details,
        "discover_movies": tmdb_service.discover_movies,
        "get_trending_movies": tmdb_service.get_trending_movies,
        "get_popular_movies": tmdb_service.get_popular_movies,
        "get_movies_by_genre": tmdb_service.get_movies_by_genre,
        "get_movies_by_actor": tmdb_service.get_movies_by_actor,
        "search_person": tmdb_service.search_person,
        "search_candidate_movies": tmdb_service.search_candidate_movies,
        "find_atmospheric_images": creative_service.find_atmospheric_images,
        "find_music_tracks": creative_service.find_music_tracks,
    } 