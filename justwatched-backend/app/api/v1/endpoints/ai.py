from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import json
from app.agents.azure_openai_agent import AzureOpenAIAgent
from app.services.tmdb_service import TMDBService
from app.services.user_data_service import UserDataService

router = APIRouter()
ai_agent = AzureOpenAIAgent()
tmdb_service = TMDBService()
user_data_service = UserDataService()

# --- Schemas ---
class TasteProfile(BaseModel):
    user_id: str
    favorite_genres: List[str]
    favorite_actors: Optional[List[str]] = None
    favorite_directors: Optional[List[str]] = None
    mood_preferences: Optional[List[str]] = None

class PersonalRecommendRequest(BaseModel):
    taste_profile: Dict[str, Any]
    watched_movie_ids: List[int]

class GroupRecommendRequest(BaseModel):
    taste_profiles: List[Dict[str, Any]]

class MoodboardRequest(BaseModel):
    movie_id: int
    user_notes: Optional[str] = ""

class ReviewForAnalysis(BaseModel):
    movie_id: int
    title: str
    rating: int
    review_text: str
    genres: List[str]
    actors: List[str]
    directors: List[str]
    watched_date: str

class TasteAnalysisRequest(BaseModel):
    reviews: List[ReviewForAnalysis]

# --- Real TMDB-based utilities ---
async def get_movie_details(movie_id: int) -> Dict[str, Any]:
    """Get real movie details from TMDB."""
    try:
        return await tmdb_service.get_movie_details(movie_id)
    except Exception as e:
        print(f"Error fetching movie details for {movie_id}: {e}")
        return {"id": movie_id, "title": "Unknown Movie", "poster_path": None}

async def search_candidate_movies(taste_profile: Dict[str, Any], limit: int = 50) -> List[Dict[str, Any]]:
    """Search for candidate movies based on taste profile using TMDB."""
    return await tmdb_service.search_candidate_movies(taste_profile, limit)

async def get_trending_movies(limit: int = 20) -> List[Dict[str, Any]]:
    """Get trending movies from TMDB as fallback."""
    try:
        return await tmdb_service.get_trending_movies(limit=limit)
    except Exception as e:
        print(f"Error fetching trending movies: {e}")
        return []

# --- Endpoints ---
@router.post("/recommend/personal")
async def recommend_personal(data: PersonalRecommendRequest):
    """Generate personal recommendations using real TMDB data."""
    profile = data.taste_profile
    watched = data.watched_movie_ids
    
    try:
        # Get candidate movies from TMDB based on taste profile
        candidate_movies = await search_candidate_movies(profile, limit=50)
        
        # Filter out already watched movies
        filtered_candidates = [
            movie for movie in candidate_movies 
            if movie["id"] not in watched
        ]
        
        # If no candidates, use trending movies as fallback
        if not filtered_candidates:
            filtered_candidates = await get_trending_movies(20)
            filtered_candidates = [
                movie for movie in filtered_candidates 
                if movie["id"] not in watched
            ]
        
        if not filtered_candidates:
            raise HTTPException(status_code=404, detail="No suitable movies found")
        
        # Prepare candidate movies for AI
        candidate_data = []
        seen_movie_ids = set()  # Track seen movie IDs to avoid duplicates
        
        for movie in filtered_candidates[:30]:  # Limit to top 30 for AI processing
            if movie["id"] not in seen_movie_ids:  # Only add if not already seen
                candidate_data.append({
                    "tmdb_id": movie["id"],
                    "title": movie["title"],
                    "overview": movie.get("overview", ""),
                    "genre_ids": movie.get("genre_ids", []),  # Keep as integer IDs
                    "release_date": movie.get("release_date", ""),
                    "poster_path": movie.get("poster_path"),
                    "vote_average": movie.get("vote_average", 0)
                })
                seen_movie_ids.add(movie["id"])
        
        messages = [
            {"role": "system", "content": (
                "You are a movie recommendation expert. You will receive a list of real movies from TMDB "
                "and a user's taste profile. Your task is to select the best 20 movies from the provided list "
                "that match the user's preferences.\n\n"
                "IMPORTANT RULES:\n"
                "1. Only use movies from the provided candidate list.\n"
                "2. Each movie can appear ONLY ONCE in your recommendations.\n"
                "3. Do not duplicate any movie titles or IDs.\n"
                "4. Select exactly 20 unique movies.\n\n"
                "Return a JSON object with this exact structure:\n"
                "{\n"
                '  "recommendations": [\n'
                '    {\n'
                '      "tmdb_id": "movie_id_from_list",\n'
                '      "title": "movie_title_from_list",\n'
                '      "poster_path": "poster_path_from_list",\n'
                '      "confidence_score": 0.85,\n'
                '      "reasoning": "explanation of why this movie matches the user\'s taste"\n'
                '    }\n'
                '  ],\n'
                '  "generated_at": "timestamp"\n'
                "}\n\n"
                "CRITICAL: Ensure no duplicate tmdb_id values in the recommendations array."
            )},
            {"role": "user", "content": f"User Taste Profile: {json.dumps(profile, ensure_ascii=False)}\n\nCandidate Movies: {json.dumps(candidate_data, ensure_ascii=False)}"}
        ]
        
        result = ai_agent.chat(messages, temperature=0.7, max_tokens=6000)
        
        # Validate and clean the response
        if not isinstance(result, dict) or "recommendations" not in result:
            raise HTTPException(status_code=500, detail="Invalid AI response format")
        
        # Deduplicate recommendations by tmdb_id
        seen_ids = set()
        unique_recommendations = []
        
        for rec in result["recommendations"]:
            if isinstance(rec, dict) and "tmdb_id" in rec:
                movie_id = str(rec["tmdb_id"])
                if movie_id not in seen_ids:
                    seen_ids.add(movie_id)
                    unique_recommendations.append(rec)
        
        # Update the result with deduplicated recommendations
        result["recommendations"] = unique_recommendations
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")

@router.post("/recommend/group")
async def recommend_group(data: GroupRecommendRequest):
    """Generate group recommendations using real TMDB data."""
    profiles = data.taste_profiles
    
    try:
        # Aggregate group preferences
        all_genres = set()
        all_actors = set()
        all_directors = set()
        
        for profile in profiles:
            all_genres.update(profile.get("favorite_genres", []))
            all_actors.update(profile.get("favorite_actors", []))
            all_directors.update(profile.get("favorite_directors", []))
        
        # Create aggregated taste profile
        aggregated_profile = {
            "favorite_genres": list(all_genres)[:5],  # Top 5 genres
            "favorite_actors": list(all_actors)[:3],  # Top 3 actors
            "favorite_directors": list(all_directors)[:3]  # Top 3 directors
        }
        
        # Get candidate movies from TMDB based on aggregated profile
        candidate_movies = await search_candidate_movies(aggregated_profile, limit=40)
        
        # If no candidates, use trending movies as fallback
        if not candidate_movies:
            candidate_movies = await get_trending_movies(20)
        
        if not candidate_movies:
            raise HTTPException(status_code=404, detail="No suitable movies found")
        
        # Prepare candidate movies for AI
        candidate_data = []
        seen_movie_ids = set()  # Track seen movie IDs to avoid duplicates
        
        for movie in candidate_movies[:25]:  # Limit to top 25 for AI processing
            if movie["id"] not in seen_movie_ids:  # Only add if not already seen
                candidate_data.append({
                    "tmdb_id": movie["id"],
                    "title": movie["title"],
                    "overview": movie.get("overview", ""),
                    "genre_ids": movie.get("genre_ids", []),  # Keep as integer IDs
                    "release_date": movie.get("release_date", ""),
                    "poster_path": movie.get("poster_path"),
                    "vote_average": movie.get("vote_average", 0)
                })
                seen_movie_ids.add(movie["id"])
        
        messages = [
            {"role": "system", "content": (
                "You are a group movie recommendation expert. You will receive a list of real movies from TMDB "
                "and multiple user taste profiles. Your task is to select 7-10 movies from the provided list "
                "that would appeal to the group.\n\n"
                "IMPORTANT RULES:\n"
                "1. Only use movies from the provided candidate list.\n"
                "2. Each movie can appear ONLY ONCE in your recommendations.\n"
                "3. Do not duplicate any movie titles or IDs.\n"
                "4. Select 7-10 unique movies.\n\n"
                "Return a JSON object with this exact structure:\n"
                "{\n"
                '  "recommendations": [\n'
                '    {\n'
                '      "tmdb_id": "movie_id_from_list",\n'
                '      "title": "movie_title_from_list",\n'
                '      "poster_path": "poster_path_from_list",\n'
                '      "group_score": 0.85,\n'
                '      "reasons": ["reason1", "reason2"],\n'
                '      "participants_who_liked": ["user_id1", "user_id2"]\n'
                '    }\n'
                '  ],\n'
                '  "generated_at": "timestamp"\n'
                "}\n\n"
                "CRITICAL: Ensure no duplicate tmdb_id values in the recommendations array."
            )},
            {"role": "user", "content": f"Group Taste Profiles: {json.dumps(profiles, ensure_ascii=False)}\n\nCandidate Movies: {json.dumps(candidate_data, ensure_ascii=False)}"}
        ]
        
        result = ai_agent.chat(messages, temperature=0.6, max_tokens=6000)
        
        # Validate and clean the response
        if not isinstance(result, dict) or "recommendations" not in result:
            raise HTTPException(status_code=500, detail="Invalid AI response format")
        
        # Deduplicate recommendations by tmdb_id
        seen_ids = set()
        unique_recommendations = []
        
        for rec in result["recommendations"]:
            if isinstance(rec, dict) and "tmdb_id" in rec:
                movie_id = str(rec["tmdb_id"])
                if movie_id not in seen_ids:
                    seen_ids.add(movie_id)
                    unique_recommendations.append(rec)
        
        # Update the result with deduplicated recommendations
        result["recommendations"] = unique_recommendations
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")

@router.post("/generate/moodboard")
async def generate_moodboard(data: MoodboardRequest):
    """Generate moodboard using real TMDB movie data."""
    movie_id = data.movie_id
    notes = data.user_notes or ""
    
    try:
        # Get real movie details from TMDB
        movie_details = await get_movie_details(movie_id)
        
        messages = [
            {"role": "system", "content": (
                "You're a creative moodboard assistant. Using the movie metadata and user notes, generate a list of:\n"
                "- 3–4 image URLs (frames/posters)\n"
                "- 2–3 soundtrack tracks\n"
                "- 5 hex color codes\n"
                "Return a JSON object: images, music, colors. No other text."
            )},
            {"role": "user", "content": f"Movie info: {json.dumps(movie_details, ensure_ascii=False)}, Notes: {notes}"}
        ]
        
        gpt_data = ai_agent.chat(messages)
        
        # Return AI-generated moodboard data
        return {
            "movie_id": movie_id,
            "movie_title": movie_details.get("title", "Unknown"),
            "poster_path": movie_details.get("poster_path"),
            **gpt_data
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")

@router.post("/analyze/taste")
async def analyze_taste(data: TasteAnalysisRequest):
    """Analyze taste profile from reviews."""
    reviews = [review.model_dump() for review in data.reviews]
    user_id = reviews[0]["user_id"] if "user_id" in reviews[0] else "user"
    watched_movie_ids = [review["movie_id"] for review in reviews]
    
    messages = [
        {"role": "system", "content": (
            "You are a movie taste profile analyzer.\n"
            "Given a list of user reviews (with genres, actors, directors, ratings, and review text),\n"
            "analyze and return a strict JSON taste_profile object with these keys: user_id, favorite_genres, favorite_actors, favorite_directors, mood_preferences.\n"
            "Each value should be a list of strings, except user_id.\n"
            "Strictly output only JSON, no extra text."
        )},
        {"role": "user", "content": f"Reviews: {json.dumps(reviews)}"}
    ]
    
    try:
        taste_profile = ai_agent.chat(messages)
        # Ensure strict output format
        return {
            "taste_profile": {
                "user_id": user_id,
                "favorite_genres": taste_profile.get("favorite_genres", []),
                "favorite_actors": taste_profile.get("favorite_actors", []),
                "favorite_directors": taste_profile.get("favorite_directors", []),
                "mood_preferences": taste_profile.get("mood_preferences", [])
            },
            "watched_movie_ids": watched_movie_ids
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}") 