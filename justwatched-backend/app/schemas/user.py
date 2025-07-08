from pydantic import BaseModel, EmailStr, validator
from typing import Optional, List
from enum import Enum
from datetime import datetime

class UserColor(str, Enum):
    RED = "red"
    YELLOW = "yellow"
    GREEN = "green"
    BLUE = "blue"
    PINK = "pink"

class ReviewStatus(str, Enum):
    WATCHED = "watched"
    WATCHLIST = "watchlist"

class CollectionVisibility(str, Enum):
    PRIVATE = "private"
    FRIENDS = "friends"
    # PUBLIC = "public" 

class FriendStatus(str, Enum):
    PENDING_SENT = "pending_sent"
    PENDING_RECEIVED = "pending_received"
    FRIENDS = "friends"
    NOT_FRIENDS = "not_friends"

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    display_name: str  # Now required and unique

    @validator('display_name')
    def validate_display_name(cls, v):
        if not v or not v.strip():
            raise ValueError('Display name cannot be empty')
        if len(v.strip()) < 3:
            raise ValueError('Display name must be at least 3 characters long')
        if len(v.strip()) > 30:
            raise ValueError('Display name must be at most 30 characters long')
        # Only allow alphanumeric characters, underscores, and hyphens
        if not v.replace('_', '').replace('-', '').replace(' ', '').isalnum():
            raise ValueError('Display name can only contain letters, numbers, spaces, underscores, and hyphens')
        return v.strip()

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserProfile(BaseModel):
    user_id: str
    email: EmailStr
    display_name: str  # Now required
    color: UserColor = UserColor.RED  # default to red

class Collection(BaseModel):
    collection_id: str
    user_id: str
    name: str
    description: Optional[str] = None
    visibility: CollectionVisibility = CollectionVisibility.PRIVATE
    created_at: datetime
    updated_at: datetime
    review_count: int = 0

class CollectionCreate(BaseModel):
    name: str
    description: Optional[str] = None
    visibility: CollectionVisibility = CollectionVisibility.PRIVATE

class CollectionUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    visibility: Optional[CollectionVisibility] = None

class ReviewCollection(BaseModel):
    review_id: str
    collection_id: str
    added_at: datetime

class FriendRequest(BaseModel):
    request_id: str
    from_user_id: str
    to_user_id: str
    status: FriendStatus
    created_at: datetime
    responded_at: Optional[datetime] = None

class FriendRequestCreate(BaseModel):
    to_user_id: str

class FriendRequestResponse(BaseModel):
    request_id: str
    action: str  # "accept" or "decline" 