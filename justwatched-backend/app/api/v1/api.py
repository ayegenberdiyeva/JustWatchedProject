from fastapi import APIRouter

api_router = APIRouter()

# from .endpoints import films, auth, recommendations
# api_router.include_router(films.router, prefix="/films", tags=["films"])
# api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
# api_router.include_router(recommendations.router, prefix="/recommendations", tags=["recommendations"])

from .endpoints import rooms, users, reviews, collections, friends, movies, auth, search_history, ai
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(rooms.router, prefix="/rooms", tags=["rooms"])
api_router.include_router(reviews.router, prefix="/reviews", tags=["reviews"])
api_router.include_router(collections.router, prefix="/collections", tags=["collections"])
api_router.include_router(friends.router, prefix="/friends", tags=["friends"])
api_router.include_router(movies.router, prefix="/movies", tags=["movies"])
api_router.include_router(search_history.router, prefix="/search-history", tags=["search-history"])
api_router.include_router(ai.router, prefix="", tags=["ai"])