from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum

class RoomStatus(str, Enum):
    ACTIVE = "active"
    PROCESSING = "processing"
    COMPLETED = "completed"
    INACTIVE = "inactive"

class InvitationStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    DECLINED = "declined"

class RoomCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = None
    max_participants: int = Field(default=10, ge=2, le=50)

class RoomUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = None
    max_participants: Optional[int] = Field(None, ge=2, le=50)

class RoomInvitationCreate(BaseModel):
    friend_ids: List[str] = Field(..., min_items=1, max_items=20)

class RoomInvitationResponse(BaseModel):
    action: str = Field(..., pattern="^(accept|decline)$")

class RoomInvitation(BaseModel):
    invitation_id: str
    room_id: str
    room_name: str
    room_description: Optional[str] = None
    from_user_id: str
    from_user_name: str
    to_user_id: str
    status: InvitationStatus
    created_at: datetime
    responded_at: Optional[datetime] = None

class RoomInvitationListResponse(BaseModel):
    invitations: List[RoomInvitation]
    total_count: int

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