from fastapi import APIRouter, Depends, HTTPException, Path, status
from typing import List
from app.crud.watchlist_crud import WatchlistCRUD
from app.schemas.watchlist import WatchlistItem, WatchlistItemCreate, WatchlistResponse, WatchlistCheckResponse
from app.core.security import get_current_user

router = APIRouter()
watchlist_crud = WatchlistCRUD()

@router.get("/", response_model=WatchlistResponse)
async def get_watchlist(user=Depends(get_current_user)):
    """Get current user's watchlist."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        items = await watchlist_crud.get_user_watchlist(user_id)
        total_count = await watchlist_crud.get_watchlist_count(user_id)
        
        return WatchlistResponse(
            items=items,
            total_count=total_count
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get watchlist: {str(e)}")

@router.post("/", response_model=WatchlistItem)
async def add_to_watchlist(
    item: WatchlistItemCreate,
    user=Depends(get_current_user)
):
    """Add a media item to current user's watchlist."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        watchlist_item = await watchlist_crud.add_to_watchlist(user_id, item)
        return watchlist_item
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to add to watchlist: {str(e)}")

@router.delete("/{media_id}")
async def remove_from_watchlist(
    media_id: str = Path(..., description="ID of the media to remove from watchlist"),
    user=Depends(get_current_user)
):
    """Remove a media item from current user's watchlist."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        success = await watchlist_crud.remove_from_watchlist(user_id, media_id)
        if not success:
            raise HTTPException(status_code=404, detail="Item not found in watchlist")
        
        return {"message": "Item removed from watchlist successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to remove from watchlist: {str(e)}")

@router.get("/check/{media_id}", response_model=WatchlistCheckResponse)
async def check_watchlist_status(
    media_id: str = Path(..., description="ID of the media to check"),
    user=Depends(get_current_user)
):
    """Check if a media item is in current user's watchlist."""
    user_id = user["sub"] if isinstance(user, dict) else user.sub
    
    try:
        is_in_watchlist = await watchlist_crud.is_in_watchlist(user_id, media_id)
        
        return WatchlistCheckResponse(
            media_id=media_id,
            is_in_watchlist=is_in_watchlist
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to check watchlist status: {str(e)}") 