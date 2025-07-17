from app.core.security import create_access_token, create_refresh_token, verify_token
from app.core.config import settings
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, Tuple

class TokenService:
    """Service for managing JWT tokens."""
    
    @staticmethod
    def create_token_pair(user_id: str) -> Tuple[str, str]:
        """Create both access and refresh tokens for a user."""
        access_token = create_access_token(user_id)
        refresh_token = create_refresh_token(user_id)
        return access_token, refresh_token
    
    @staticmethod
    def verify_access_token(token: str) -> Optional[Dict[str, Any]]:
        """Verify an access token."""
        return verify_token(token, "access")
    
    @staticmethod
    def verify_refresh_token(token: str) -> Optional[Dict[str, Any]]:
        """Verify a refresh token."""
        return verify_token(token, "refresh")
    
    @staticmethod
    def is_token_expired(token: str, token_type: str = "access") -> bool:
        """Check if a token is expired."""
        payload = verify_token(token, token_type)
        if not payload:
            return True
        
        exp_timestamp = payload.get("exp")
        if not exp_timestamp:
            return True
        
        # Convert timestamp to datetime
        exp_datetime = datetime.fromtimestamp(exp_timestamp)
        return datetime.utcnow() > exp_datetime
    
    @staticmethod
    def get_token_expiry(token: str, token_type: str = "access") -> Optional[datetime]:
        """Get the expiry datetime of a token."""
        payload = verify_token(token, token_type)
        if not payload:
            return None
        
        exp_timestamp = payload.get("exp")
        if not exp_timestamp:
            return None
        
        return datetime.fromtimestamp(exp_timestamp)
    
    @staticmethod
    def get_token_remaining_time(token: str, token_type: str = "access") -> Optional[timedelta]:
        """Get the remaining time until token expiry."""
        expiry = TokenService.get_token_expiry(token, token_type)
        if not expiry:
            return None
        
        return expiry - datetime.utcnow()
    
    @staticmethod
    def should_refresh_token(token: str, buffer_minutes: int = 5) -> bool:
        """Check if a token should be refreshed (expires within buffer time)."""
        remaining_time = TokenService.get_token_remaining_time(token, "access")
        if not remaining_time:
            return True
        
        buffer_time = timedelta(minutes=buffer_minutes)
        return remaining_time <= buffer_time 