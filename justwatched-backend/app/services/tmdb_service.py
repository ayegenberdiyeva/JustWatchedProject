import httpx
from app.core.config import settings

# TMDB API constants
TMDB_BASE_URL = "https://api.themoviedb.org/3"

def get_tmdb_search_endpoint(search_type: str = 'movie') -> str:
    """Get the appropriate TMDB search endpoint based on search type."""
    if search_type == 'movie':
        return f"{TMDB_BASE_URL}/search/movie"
    elif search_type == 'tv':
        return f"{TMDB_BASE_URL}/search/tv"
    elif search_type == 'person':
        return f"{TMDB_BASE_URL}/search/person"
    else:
        return f"{TMDB_BASE_URL}/search/movie"

class TMDBService:
    def __init__(self):
        self.api_key = settings.TMDB_API_KEY

    async def search_movies(self, query: str, search_type: str = 'movie', page: int = 1, **kwargs):
        """Search movies with flexible parameters to handle AI assistant calls."""
        # Ignore unexpected parameters like watched_movie_ids
        url = get_tmdb_search_endpoint(search_type)
        params = {'api_key': self.api_key, 'query': query, 'page': page}
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        return resp.json()

    async def get_movie_details(self, movie_id: int):
        url = f"{TMDB_BASE_URL}/movie/{movie_id}"
        params = {'api_key': self.api_key}
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        return resp.json() 