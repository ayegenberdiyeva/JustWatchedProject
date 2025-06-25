from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from typing import Optional
from app.crud.user_crud import UserCRUD
from app.core.security import get_current_user
from datetime import datetime

router = APIRouter()
user_crud = UserCRUD()

class UserProfileRequest(BaseModel):
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None

class UserProfileResponse(BaseModel):
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    created_at: Optional[str] = None
    personal_recommendations: Optional[list] = None

@router.post("/users", response_model=None)
async def create_user_profile(
    profile: UserProfileRequest,
    user=Depends(get_current_user)
):
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        await user_crud.create_user_profile(user_id, profile.dict())
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"status": "created"}

@router.get("/users/me", response_model=UserProfileResponse)
async def get_my_profile(user=Depends(get_current_user)):
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    profile = await user_crud.get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile

@router.patch("/users/me", response_model=UserProfileResponse)
async def update_my_profile(
    profile: UserProfileRequest,
    user=Depends(get_current_user)
):
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    try:
        await user_crud.update_user_profile(user_id, profile.dict(exclude_unset=True))
        updated_profile = await user_crud.get_user_profile(user_id)
        if not updated_profile:
            raise HTTPException(status_code=404, detail="Profile not found after update")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return updated_profile 