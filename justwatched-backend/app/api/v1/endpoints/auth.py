from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from firebase_admin import auth as firebase_auth
import requests
from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token, verify_token
from datetime import datetime, timedelta

router = APIRouter()

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    user_id: str
    expires_in: int

class RefreshTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int

@router.post("/register", response_model=AuthResponse)
async def register_user(data: RegisterRequest):
    if not settings.FIREBASE_API_KEY:
        raise HTTPException(status_code=500, detail="FIREBASE_API_KEY not set in environment")
    
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={settings.FIREBASE_API_KEY}"
    payload = {
        "email": data.email,
        "password": data.password,
        "returnSecureToken": True
    }
    
    resp = requests.post(url, json=payload)
    if resp.status_code != 200:
        error_data = resp.json()
        error_message = error_data.get("error", {}).get("message", "Registration failed")
        print(f"Firebase registration error: {error_message}")  # Debug log
        raise HTTPException(status_code=400, detail=error_message)
    
    user_id = resp.json().get("localId")
    access_token = create_access_token(user_id)
    refresh_token = create_refresh_token(user_id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user_id": user_id,
        "expires_in": settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60  # Convert to seconds
    }

@router.post("/login", response_model=AuthResponse)
async def login_user(data: LoginRequest):
    if not settings.FIREBASE_API_KEY:
        raise HTTPException(status_code=500, detail="FIREBASE_API_KEY not set in environment")
    
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={settings.FIREBASE_API_KEY}"
    payload = {"email": data.email, "password": data.password, "returnSecureToken": True}
    resp = requests.post(url, json=payload)
    
    if resp.status_code != 200:
        error_data = resp.json()
        error_message = error_data.get("error", {}).get("message", "Invalid credentials")
        print(f"Firebase login error: {error_message}")  # Debug log
        raise HTTPException(status_code=401, detail=error_message)
    
    # Check if email is verified
    if not resp.json().get("emailVerified", False):
        raise HTTPException(status_code=403, detail="Email not verified. Please check your inbox.")

    user_id = resp.json().get("localId")
    access_token = create_access_token(user_id)
    refresh_token = create_refresh_token(user_id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user_id": user_id,
        "expires_in": settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60  # Convert to seconds
    }

@router.post("/refresh", response_model=RefreshTokenResponse)
async def refresh_token(data: RefreshTokenRequest):
    """Refresh an access token using a refresh token."""
    # Verify the refresh token
    payload = verify_token(data.refresh_token, "refresh")
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    # Create new tokens
    new_access_token = create_access_token(user_id)
    new_refresh_token = create_refresh_token(user_id)
    
    return {
        "access_token": new_access_token,
        "refresh_token": new_refresh_token,
        "expires_in": settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60  # Convert to seconds
    }

class ResetPasswordRequest(BaseModel):
    email: EmailStr

@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT)
async def reset_password(data: ResetPasswordRequest):
    if not settings.FIREBASE_API_KEY:
        raise HTTPException(status_code=500, detail="FIREBASE_API_KEY not set in environment")
    
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key={settings.FIREBASE_API_KEY}"
    payload = {
        "requestType": "PASSWORD_RESET",
        "email": data.email
    }
    
    resp = requests.post(url, json=payload)
    if resp.status_code != 200:
        raise HTTPException(
            status_code=400,
            detail="Failed to initiate password reset"
        )
    
    return None  # Returns 204 No Content as expected by frontend 