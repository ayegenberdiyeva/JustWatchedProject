from fastapi import FastAPI
from app.api.v1.endpoints import auth, movies, reviews, users, search_history, rooms

app = FastAPI()

app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(movies.router, prefix="/api/v1/movies", tags=["movies"])
app.include_router(reviews.router, prefix="/api/v1", tags=["reviews"])
app.include_router(users.router, prefix="/api/v1", tags=["users"])
app.include_router(search_history.router, prefix="/api/v1", tags=["search-history"])
app.include_router(rooms.router, prefix="/api/v1/rooms", tags=["rooms"])

@app.get("/healthcheck")
async def healthcheck():
    return {"status": "healthy", "database": "connected"}
