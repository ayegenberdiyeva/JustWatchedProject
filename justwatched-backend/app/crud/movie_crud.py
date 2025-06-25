from typing import Optional, List
from app.schemas.movie import Movie
from app.core.firestore import get_firestore_client, run_in_threadpool
import uuid

class MovieCRUD:
    """
    Data access layer for movie-related operations (Firestore integration).
    """
    def __init__(self):
        self.db = get_firestore_client()
        self.movies_col = self.db.collection("movies")

    async def get_movie_by_id(self, movie_id: str) -> Optional[Movie]:
        """Fetch a movie by its ID."""
        doc = await run_in_threadpool(lambda: self.movies_col.document(movie_id).get())
        if doc.exists:
            return Movie(**doc.to_dict())
        return None

    async def create_movie(self, movie: Movie) -> Movie:
        """Add a new movie to Firestore."""
        movie_id = movie.movie_id or str(uuid.uuid4())
        movie_data = movie.dict()
        movie_data["movie_id"] = movie_id
        await run_in_threadpool(lambda: self.movies_col.document(movie_id).set(movie_data))
        return Movie(**movie_data)

    async def list_movies(self, skip: int = 0, limit: int = 20) -> List[Movie]:
        """List movies with pagination."""
        def fetch():
            docs = self.movies_col.offset(skip).limit(limit).stream()
            return [Movie(**doc.to_dict()) for doc in docs if doc.exists]
        return await run_in_threadpool(fetch) 