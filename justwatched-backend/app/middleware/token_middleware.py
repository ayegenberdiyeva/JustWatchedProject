from fastapi import Request, Response
from fastapi.responses import JSONResponse
from app.services.token_service import TokenService
from app.core.security import create_access_token, create_refresh_token
from typing import Optional
import json

class TokenMiddleware:
    """Middleware for handling token refresh and validation."""
    
    def __init__(self, app):
        self.app = app
    
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        
        request = Request(scope, receive)
        
        # Skip token handling for auth endpoints
        if request.url.path.startswith("/api/v1/auth/"):
            await self.app(scope, receive, send)
            return
        
        # Check if request has authorization header
        auth_header = request.headers.get("authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            await self.app(scope, receive, send)
            return
        
        token = auth_header.split(" ")[1]
        
        # Check if token is expired or about to expire
        if TokenService.should_refresh_token(token):
            # Try to get refresh token from request headers or cookies
            refresh_token = self._get_refresh_token(request)
            
            if refresh_token and not TokenService.is_token_expired(refresh_token, "refresh"):
                # Generate new tokens
                payload = TokenService.verify_refresh_token(refresh_token)
                if payload:
                    user_id = payload.get("sub")
                    new_access_token = create_access_token(user_id)
                    new_refresh_token = create_refresh_token(user_id)
                    
                    # Add new tokens to response headers
                    async def send_with_tokens(message):
                        if message["type"] == "http.response.start":
                            message["headers"].extend([
                                (b"x-new-access-token", new_access_token.encode()),
                                (b"x-new-refresh-token", new_refresh_token.encode()),
                                (b"x-token-refreshed", b"true")
                            ])
                        await send(message)
                    
                    await self.app(scope, receive, send_with_tokens)
                    return
        
        await self.app(scope, receive, send)
    
    def _get_refresh_token(self, request: Request) -> Optional[str]:
        """Extract refresh token from request headers or cookies."""
        # Try to get from custom header
        refresh_token = request.headers.get("x-refresh-token")
        if refresh_token:
            return refresh_token
        
        # Try to get from cookies
        refresh_token = request.cookies.get("refresh_token")
        if refresh_token:
            return refresh_token
        
        return None

def add_token_refresh_headers(response: Response, access_token: str, refresh_token: str):
    """Add token refresh headers to response."""
    response.headers["x-new-access-token"] = access_token
    response.headers["x-new-refresh-token"] = refresh_token
    response.headers["x-token-refreshed"] = "true"
    return response 