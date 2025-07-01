from pydantic import BaseModel, EmailStr
from typing import Optional
from enum import Enum

class UserColor(str, Enum):
    RED = "red"
    YELLOW = "yellow"
    GREEN = "green"
    BLUE = "blue"
    PINK = "pink"

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    display_name: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserProfile(BaseModel):
    user_id: str
    email: EmailStr
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    color: UserColor = UserColor.RED  # default to red 