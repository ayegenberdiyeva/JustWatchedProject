from fastapi import APIRouter, Depends, HTTPException, Path, Query
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from app.crud.user_crud import UserCRUD
from app.crud.friend_crud import FriendCRUD
from app.core.security import get_current_user
from app.schemas.user import UserColor, FriendStatus
from datetime import datetime
from app.core.config import settings
from app.core.redis_client import redis_client
import json

router = APIRouter()
user_crud = UserCRUD()
friend_crud = FriendCRUD()



class UserProfileRequest(BaseModel):
    email: Optional[EmailStr] = None
    display_name: Optional[str] = None
    bio: Optional[str] = None
    color: Optional[UserColor] = None

class UserProfileResponse(BaseModel):
    user_id: str
    email: str
    display_name: str
    bio: Optional[str] = None
    color: str
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

class UserSearchResult(BaseModel):
    user_id: str
    display_name: str
    color: str
    is_friend: bool
    friend_status: Optional[str] = None  # "pending_sent", "pending_received", "friends", or None

class UserSearchResponse(BaseModel):
    users: List[UserSearchResult]

class PublicUserProfileResponse(BaseModel):
    user_id: str
    display_name: str
    color: str
    is_friend: bool
    bio: Optional[str] = None
    email: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

@router.post("", response_model=None)
async def create_user_profile(
    profile_data: UserProfileRequest,
    current_user=Depends(get_current_user)
):
    """Create a user profile for the authenticated user."""
    user_id = current_user["sub"]
    email = current_user.get("email")
    if not email:
        raise HTTPException(status_code=400, detail="Authenticated user email not found.")
    # If email is provided in the request, ensure it matches the authenticated user's email
    if profile_data.email and profile_data.email != email:
        raise HTTPException(status_code=400, detail="Email in request does not match authenticated user.")
    # Validate display_name
    display_name = profile_data.display_name
    if not display_name or not display_name.strip():
        raise HTTPException(status_code=400, detail="Display name is required and cannot be empty.")
    # Set color to red if not provided
    color = profile_data.color.value if profile_data.color else "red"
    # Prepare data
    data = {
        "user_id": user_id,
        "email": email,
        "display_name": display_name.strip(),
        "color": color,
        "bio": profile_data.bio or None,
        "created_at": datetime.utcnow().isoformat(),
    }
    try:
        await user_crud.create_user_profile(user_id, data)
        return {"message": "Profile created successfully"}
    except ValueError as e:
        if "Display name" in str(e) and "already taken" in str(e):
            raise HTTPException(status_code=409, detail=str(e))
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/me", response_model=UserProfileResponse)
async def get_my_profile(current_user=Depends(get_current_user)):
    """Get the current user's profile."""
    user_id = current_user["sub"]
    profile = await user_crud.get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile

@router.patch("/me", response_model=UserProfileResponse)
async def update_my_profile(
    profile_data: UserProfileRequest,
    current_user=Depends(get_current_user)
):
    """Update the current user's profile."""
    user_id = current_user["sub"]
    
    try:
        # Only update the fields that are provided (partial update)
        update_data = profile_data.dict(exclude_unset=True)
        await user_crud.update_user_profile(user_id, update_data)
        updated_profile = await user_crud.get_user_profile(user_id)
        if not updated_profile:
            raise HTTPException(status_code=404, detail="Profile not found")
        return updated_profile
    except ValueError as e:
        if "Display name" in str(e) and "already taken" in str(e):
            raise HTTPException(status_code=409, detail=str(e))
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/me/color")
async def update_my_color(
    color: UserColor,
    current_user=Depends(get_current_user)
):
    """Update the current user's color preference."""
    user_id = current_user["sub"]
    await user_crud.update_user_profile(user_id, {"color": color.value})
    return {"message": "Color updated successfully"}

@router.get("/search", response_model=UserSearchResponse)
async def search_user_by_display_name(
    display_name: str = Query(..., description="Display name to search for"),
    current_user=Depends(get_current_user)
):
    """Search for users by their display name. Returns an array of results."""
    current_user_id = current_user["sub"]
    
    # Get user by display name
    user_profile = await user_crud.get_user_by_display_name(display_name)
    if not user_profile:
        # Return empty array if no user found
        return UserSearchResponse(users=[])
    
    # Don't allow searching for yourself
    if user_profile["user_id"] == current_user_id:
        # Return empty array if searching for yourself
        return UserSearchResponse(users=[])
    
    # Check friend status
    friends = await friend_crud.get_friends_list(current_user_id)
    is_friend = user_profile["user_id"] in friends
    
    # Check if there's a pending friend request
    friend_status = None
    if not is_friend:
        friend_status_obj = await friend_crud.get_friend_status(current_user_id, user_profile["user_id"])
        if friend_status_obj == FriendStatus.PENDING_SENT:
            friend_status = "pending_sent"
        elif friend_status_obj == FriendStatus.PENDING_RECEIVED:
            friend_status = "pending_received"
    
    # Create search result
    search_result = UserSearchResult(
        user_id=user_profile["user_id"],
        display_name=user_profile["display_name"],
        color=user_profile.get("color", "red"),
        is_friend=is_friend,
        friend_status=friend_status
    )
    
    # Return array with single result
    return UserSearchResponse(users=[search_result])

@router.get("/colors")
async def get_available_colors():
    """Get all available user colors."""
    return {
        "colors": [color.value for color in UserColor],
        "default": UserColor.RED.value
    }

@router.get("/{user_id}", response_model=PublicUserProfileResponse)
async def get_user_profile(
    user_id: str = Path(..., description="The ID of the user whose profile to retrieve"),
    current_user=Depends(get_current_user)
):
    """Get another user's public profile details. Always returns display_name and color. Full profile only if friends."""
    current_user_id = current_user["sub"]
    # Can't view your own profile through this endpoint (use /me instead)
    if user_id == current_user_id:
        raise HTTPException(status_code=400, detail="Use /me endpoint to view your own profile")
    # Get the target user's profile
    profile = await user_crud.get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User not found")
    # Check if users are friends
    is_friend = await friend_crud.are_friends(current_user_id, user_id)
    # Always return display_name and color, only return sensitive fields if friends
    response = {
        "user_id": user_id,
        "display_name": profile["display_name"],
        "color": profile.get("color", "red"),
        "is_friend": is_friend
    }
    if is_friend:
        response["bio"] = profile.get("bio")
        response["email"] = profile.get("email")
        response["created_at"] = profile.get("created_at")
        response["updated_at"] = profile.get("updated_at")
    return response

@router.get("/me/recommendations")
async def get_my_recommendations(current_user=Depends(get_current_user)):
    user_id = current_user["sub"]
    cache_key = f"user:{user_id}:recommendations"
    data = redis_client.get(cache_key)
    if not data:
        raise HTTPException(status_code=404, detail="No recommendations found. Please try again later.")
    return json.loads(data) 