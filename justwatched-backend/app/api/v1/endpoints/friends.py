from fastapi import APIRouter, Depends, HTTPException, Path
from typing import List, Optional
from app.crud.friend_crud import FriendCRUD
from app.crud.user_crud import UserCRUD
from app.core.security import get_current_user
from app.schemas.user import FriendRequestCreate, FriendRequestResponse, FriendStatus
from pydantic import BaseModel

router = APIRouter()
friend_crud = FriendCRUD()
user_crud = UserCRUD()

class FriendRequestDetailResponse(BaseModel):
    request_id: str
    from_user_id: str
    to_user_id: str
    status: str
    created_at: str
    responded_at: Optional[str] = None

class FriendRequestListResponse(BaseModel):
    requests: List[FriendRequestDetailResponse]
    total_count: int

class FriendResponse(BaseModel):
    user_id: str
    display_name: Optional[str] = None
    color: Optional[str] = None

class FriendListResponse(BaseModel):
    friends: List[FriendResponse]
    total_count: int

class FriendStatusResponse(BaseModel):
    user_id: str
    status: str

@router.post("/requests", response_model=FriendRequestDetailResponse)
async def send_friend_request(
    request_data: FriendRequestCreate,
    user=Depends(get_current_user)
):
    """Send a friend request to another user."""
    from_user_id = user["sub"] if isinstance(user, dict) else user.sub
    to_user_id = request_data.to_user_id
    
    try:
        # Check if target user exists
        target_user = await user_crud.get_user_profile(to_user_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Check if trying to send request to self
        if from_user_id == to_user_id:
            raise HTTPException(status_code=400, detail="Cannot send friend request to yourself")
        
        # Check current friend status
        current_status = await friend_crud.get_friend_status(from_user_id, to_user_id)
        if current_status == FriendStatus.FRIENDS:
            raise HTTPException(status_code=400, detail="Already friends")
        elif current_status in [FriendStatus.PENDING_SENT, FriendStatus.PENDING_RECEIVED]:
            raise HTTPException(status_code=400, detail="Friend request already exists")
        
        # Send the request
        request_id = await friend_crud.send_friend_request(from_user_id, to_user_id)
        
        # Get the created request
        requests = await friend_crud.get_pending_requests(from_user_id)
        for req in requests:
            if req["request_id"] == request_id:
                return FriendRequestDetailResponse(**req)
        
        raise HTTPException(status_code=500, detail="Failed to create friend request")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to send friend request: {str(e)}")

@router.get("/requests", response_model=FriendRequestListResponse)
async def get_pending_requests(
    user=Depends(get_current_user)
):
    """Get all pending friend requests for the current user."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        requests = await friend_crud.get_pending_requests(user_id)
        
        request_responses = [
            FriendRequestDetailResponse(**req) for req in requests
        ]
        
        return FriendRequestListResponse(
            requests=request_responses,
            total_count=len(request_responses)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get friend requests: {str(e)}")

@router.put("/requests/{request_id}")
async def respond_to_friend_request(
    request_id: str = Path(..., description="ID of the friend request"),
    response: FriendRequestResponse = None,
    user=Depends(get_current_user)
):
    """Accept or decline a friend request."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Get the request to verify it's for the current user
        requests = await friend_crud.get_pending_requests(user_id)
        target_request = None
        
        for req in requests:
            if req["request_id"] == request_id:
                target_request = req
                break
        
        if not target_request:
            raise HTTPException(status_code=404, detail="Friend request not found")
        
        # Verify the request is for the current user
        if target_request["to_user_id"] != user_id:
            raise HTTPException(status_code=403, detail="You can only respond to requests sent to you")
        
        # Respond to the request
        success = await friend_crud.respond_to_friend_request(request_id, response.action)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to respond to friend request")
        
        action_text = "accepted" if response.action == "accept" else "declined"
        return {"message": f"Friend request {action_text} successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to respond to friend request: {str(e)}")

@router.delete("/requests/{request_id}")
async def cancel_friend_request(
    request_id: str = Path(..., description="ID of the friend request to cancel"),
    user=Depends(get_current_user)
):
    """Cancel/withdraw a friend request (only the sender can cancel)."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Cancel the request
        success = await friend_crud.cancel_friend_request(request_id, user_id)
        if not success:
            raise HTTPException(status_code=404, detail="Friend request not found or you don't have permission to cancel it")
        
        return {"message": "Friend request cancelled successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to cancel friend request: {str(e)}")

@router.get("/", response_model=FriendListResponse)
async def get_friends_list(
    user=Depends(get_current_user)
):
    """Get the current user's friends list."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        friend_ids = await friend_crud.get_friends_list(user_id)
        
        # Get friend details
        friends = []
        for friend_id in friend_ids:
            friend_profile = await user_crud.get_user_profile(friend_id)
            if friend_profile:
                friends.append(FriendResponse(
                    user_id=friend_id,
                    display_name=friend_profile.get("display_name"),
                    color=friend_profile.get("color")
                ))
        
        return FriendListResponse(
            friends=friends,
            total_count=len(friends)
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get friends list: {str(e)}")

@router.delete("/{friend_user_id}")
async def remove_friend(
    friend_user_id: str = Path(..., description="ID of the friend to remove"),
    user=Depends(get_current_user)
):
    """Remove a friend."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        # Check if they are actually friends
        are_friends = await friend_crud.are_friends(user_id, friend_user_id)
        if not are_friends:
            raise HTTPException(status_code=400, detail="Not friends with this user")
        
        # Remove the friendship
        success = await friend_crud.remove_friend(user_id, friend_user_id)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to remove friend")
        
        return {"message": "Friend removed successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to remove friend: {str(e)}")

@router.get("/status/{user_id}", response_model=FriendStatusResponse)
async def get_friend_status(
    user_id: str = Path(..., description="ID of the user to check friendship status with"),
    current_user=Depends(get_current_user)
):
    """Get the friendship status with another user."""
    current_user_id = current_user["sub"] if isinstance(current_user, dict) else current_user.sub
    
    try:
        # Check if target user exists
        target_user = await user_crud.get_user_profile(user_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get friendship status
        status = await friend_crud.get_friend_status(current_user_id, user_id)
        
        return FriendStatusResponse(
            user_id=user_id,
            status=status.value
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get friend status: {str(e)}")

@router.get("/users/{user_id}/friends", response_model=FriendListResponse)
async def get_user_friends(
    user_id: str = Path(..., description="ID of the user to get friends for"),
    current_user=Depends(get_current_user)
):
    """Get friends list of another user (only if you're friends with them)."""
    current_user_id = current_user["sub"] if isinstance(current_user, dict) else current_user.sub
    
    try:
        # Check if target user exists
        target_user = await user_crud.get_user_profile(user_id)
        if not target_user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Check if current user is friends with target user
        are_friends = await friend_crud.are_friends(current_user_id, user_id)
        if not are_friends:
            raise HTTPException(status_code=403, detail="You can only view friends of users you're friends with")
        
        # Get target user's friends
        friend_ids = await friend_crud.get_friends_list(user_id)
        
        # Get friend details
        friends = []
        for friend_id in friend_ids:
            friend_profile = await user_crud.get_user_profile(friend_id)
            if friend_profile:
                friends.append(FriendResponse(
                    user_id=friend_id,
                    display_name=friend_profile.get("display_name"),
                    color=friend_profile.get("color")
                ))
        
        return FriendListResponse(
            friends=friends,
            total_count=len(friends)
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get user friends: {str(e)}") 