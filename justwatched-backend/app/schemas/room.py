from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum

class RoomStatus(str, Enum):
    ACTIVE = "active"
    PROCESSING = "processing"
    COMPLETED = "completed"
    INACTIVE = "inactive"

class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    max_participants: int = Field(default=10, ge=2, le=50)

class RoomUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    max_participants: Optional[int] = Field(None, ge=2, le=50)

class RoomParticipant(BaseModel):
    user_id: str
    display_name: Optional[str] = None
    joined_at: datetime
    is_owner: bool = False

class RoomRecommendation(BaseModel):
    movie_id: str
    title: str
    poster_path: Optional[str] = None
    group_score: float
    reasons: List[str]
    participants_who_liked: List[str]

class RoomResponse(BaseModel):
    room_id: str
    name: str
    description: Optional[str] = None
    status: RoomStatus
    max_participants: int
    current_participants: int
    created_at: datetime
    updated_at: datetime
    owner_id: str
    participants: List[RoomParticipant]
    current_recommendations: Optional[List[RoomRecommendation]] = None

class RoomListResponse(BaseModel):
    rooms: List[RoomResponse]
    total_count: int
    has_more: bool = False

class RoomRecommendationResponse(BaseModel):
    room_id: str
    recommendations: List[RoomRecommendation]
    generated_at: datetime
    participant_count: int 