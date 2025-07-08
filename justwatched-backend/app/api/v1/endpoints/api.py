from fastapi import APIRouter
from app.api.v1.endpoints import users, collections, friends, reviews, rooms, search_history
from app.api.v1.endpoints import ai

api_router = APIRouter()

api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(collections.router, prefix="/collections", tags=["collections"])
api_router.include_router(friends.router, prefix="/friends", tags=["friends"])
api_router.include_router(reviews.router, prefix="/reviews", tags=["reviews"])
api_router.include_router(rooms.router, prefix="/rooms", tags=["rooms"])
api_router.include_router(search_history.router, prefix="/search-history", tags=["search-history"])
api_router.include_router(ai.router, prefix="", tags=["ai"]) 