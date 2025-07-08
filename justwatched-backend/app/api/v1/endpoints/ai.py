from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import json
from app.agents.azure_openai_agent import AzureOpenAIAgent

router = APIRouter()
ai_agent = AzureOpenAIAgent()

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

# --- Utilities (stubs, replace with real logic as needed) ---
def get_movie_details(movie_id: int) -> Dict[str, Any]:
    # TODO: Replace with real TMDB lookup
    return {"movie_id": movie_id, "title": "Stub Movie", "poster_url": "https://example.com/poster.jpg"}

def find_atmospheric_images(movie_id: int) -> List[str]:
    # TODO: Replace with real image search
    return [f"https://example.com/image_{movie_id}_1.jpg", f"https://example.com/image_{movie_id}_2.jpg"]

def find_music_tracks(movie_id: int) -> List[str]:
    # TODO: Replace with real music search
    return [f"track_{movie_id}_1", f"track_{movie_id}_2"]

def extract_palette(poster_url: str) -> List[str]:
    # TODO: Replace with real color extraction
    return ["#1f1f1f", "#c0c0c0", "#3a3a3a", "#808080", "#fafafa"]

# --- Endpoints ---
@router.post("/recommend/personal")
def recommend_personal(data: PersonalRecommendRequest):
    profile = data.taste_profile
    watched = data.watched_movie_ids
    messages = [
        {"role": "system", "content": (
            "You are a movie recommendation engine.\n"
            "Return exactly 20 movies in JSON (key: tmdb_id, title, justification).\n"
            "Use the given taste profile and avoid watched_movie_ids.\n"
            "Strictly output only JSON, no extra text."
        )},
        {"role": "user", "content": f"TasteProfile: {json.dumps(profile)}\nWatched: {watched}"}
    ]
    try:
        return ai_agent.chat(messages)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")

@router.post("/recommend/group")
def recommend_group(data: GroupRecommendRequest):
    profiles = data.taste_profiles
    messages = [
        {"role": "system", "content": (
            "You are a group movie selector AI.\n"
            "Take the list of user taste profiles and suggest 7-10 movies.\n"
            "Output JSON list with: tmdb_id, title, justification.\n"
            "Mention which preferences were covered. No text outside JSON."
        )},
        {"role": "user", "content": f"TasteProfiles: {json.dumps(profiles)}"}
    ]
    try:
        return ai_agent.chat(messages)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")

@router.post("/generate/moodboard")
def generate_moodboard(data: MoodboardRequest):
    movie_id = data.movie_id
    notes = data.user_notes or ""
    movie_details = get_movie_details(movie_id)
    images = find_atmospheric_images(movie_id)
    soundtrack = find_music_tracks(movie_id)
    poster_url = movie_details.get("poster_url", "")
    hex_colors = extract_palette(poster_url)
    messages = [
        {"role": "system", "content": (
            "You're a creative moodboard assistant.\n"
            "Using the movie metadata and user notes, generate a list of:\n"
            "- 3–4 image URLs (frames/posters)\n"
            "- 2–3 soundtrack tracks\n"
            "- 5 hex color codes\n"
            "Return a JSON object: images, music, colors. No other text."
        )},
        {"role": "user", "content": f"Movie info: {movie_details}, Notes: {notes}"}
    ]
    try:
        gpt_data = ai_agent.chat(messages)
        # Merge external (stubbed) and AI data, AI data takes precedence
        return {
            "images": images,
            "music": soundtrack,
            "colors": hex_colors,
            **gpt_data
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI error: {e}")

@router.post("/analyze/taste")
def analyze_taste(data: TasteAnalysisRequest):
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