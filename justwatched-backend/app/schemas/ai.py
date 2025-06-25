from pydantic import BaseModel
from typing import List, Optional

class TasteProfile(BaseModel):
    user_id: str
    favorite_genres: List[str]
    favorite_actors: Optional[List[str]] = None
    favorite_directors: Optional[List[str]] = None
    mood_preferences: Optional[List[str]] = None

class RecommendationResult(BaseModel):
    movie_id: str
    title: str
    reason: Optional[str] = None
    score: Optional[float] = None

class PersonalRecommendationList(BaseModel):
    user_id: str
    recommendations: List[RecommendationResult]

class GroupRecommendationResult(BaseModel):
    group_id: str
    movie_id: str
    title: str
    group_score: float
    reasons: Optional[List[str]] = None

class GroupRecommendationList(BaseModel):
    group_id: str
    recommendations: List[GroupRecommendationResult]

class MusicTrack(BaseModel):
    track_id: str
    title: str
    artist: str
    album: Optional[str] = None
    preview_url: Optional[str] = None

class MoodboardAssets(BaseModel):
    user_id: str
    images: List[str]
    music_tracks: List[MusicTrack] 