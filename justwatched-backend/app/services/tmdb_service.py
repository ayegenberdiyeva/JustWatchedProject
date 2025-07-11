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

    async def discover_movies(self, **params):
        """Discover movies with various filters."""
        url = f"{TMDB_BASE_URL}/discover/movie"
        params['api_key'] = self.api_key
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        return resp.json()

    async def get_trending_movies(self, time_window: str = 'week', limit: int = 20):
        """Get trending movies."""
        url = f"{TMDB_BASE_URL}/trending/movie/{time_window}"
        params = {'api_key': self.api_key}
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()
        return data.get("results", [])[:limit]

    async def get_popular_movies(self, page: int = 1, limit: int = 20):
        """Get popular movies."""
        url = f"{TMDB_BASE_URL}/movie/popular"
        params = {'api_key': self.api_key, 'page': page}
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()
        return data.get("results", [])[:limit]

    async def get_movies_by_genre(self, genre_id: str, page: int = 1, limit: int = 20):
        """Get movies by genre ID."""
        url = f"{TMDB_BASE_URL}/discover/movie"
        params = {
            'api_key': self.api_key,
            'with_genres': genre_id,
            'sort_by': 'popularity.desc',
            'page': page,
            'include_adult': False
        }
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()
        return data.get("results", [])[:limit]

    async def get_movies_by_actor(self, actor_id: int, page: int = 1, limit: int = 20):
        """Get movies by actor ID."""
        url = f"{TMDB_BASE_URL}/discover/movie"
        params = {
            'api_key': self.api_key,
            'with_cast': actor_id,
            'sort_by': 'popularity.desc',
            'page': page,
            'include_adult': False
        }
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        data = resp.json()
        return data.get("results", [])[:limit]

    async def search_person(self, query: str, page: int = 1):
        """Search for a person (actor/director)."""
        url = f"{TMDB_BASE_URL}/search/person"
        params = {'api_key': self.api_key, 'query': query, 'page': page}
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, params=params)
        resp.raise_for_status()
        return resp.json()

    async def get_genre_id(self, genre_name: str) -> str:
        """Get TMDB genre ID from genre name."""
        # Common genre mappings
        genre_map = {
            "action": "28", "adventure": "12", "animation": "16", "comedy": "35",
            "crime": "80", "documentary": "99", "drama": "18", "family": "10751",
            "fantasy": "14", "history": "36", "horror": "27", "music": "10402",
            "mystery": "9648", "romance": "10749", "science fiction": "878",
            "tv movie": "10770", "thriller": "53", "war": "10752", "western": "37"
        }
        return genre_map.get(genre_name.lower(), "18")  # Default to drama

    async def search_candidate_movies(self, taste_profile: dict, limit: int = 50) -> list:
        """Search for candidate movies based on taste profile."""
        candidates = []
        
        # Search by favorite genres
        for genre in taste_profile.get("favorite_genres", [])[:3]:  # Limit to top 3 genres
            try:
                genre_id = await self.get_genre_id(genre)
                movies = await self.get_movies_by_genre(genre_id, limit=10)
                candidates.extend(movies)
            except Exception as e:
                print(f"Error searching for genre {genre}: {e}")
        
        # Search by favorite actors
        for actor in taste_profile.get("favorite_actors", [])[:2]:  # Limit to top 2 actors
            try:
                # First find actor ID
                actor_search = await self.search_person(actor)
                if actor_search.get("results"):
                    actor_id = actor_search["results"][0]["id"]
                    # Then find movies by actor
                    movies = await self.get_movies_by_actor(actor_id, limit=10)
                    candidates.extend(movies)
            except Exception as e:
                print(f"Error searching for actor {actor}: {e}")
        
        # Remove duplicates and limit results
        seen_ids = set()
        unique_candidates = []
        for movie in candidates:
            if movie["id"] not in seen_ids and len(unique_candidates) < limit:
                seen_ids.add(movie["id"])
                unique_candidates.append(movie)
        
        return unique_candidates 