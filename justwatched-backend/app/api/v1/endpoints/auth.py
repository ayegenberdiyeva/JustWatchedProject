from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from firebase_admin import auth as firebase_auth
import requests
from app.core.config import settings
from jose import jwt
from datetime import datetime, timedelta

router = APIRouter()

def _generate_jwt(user_id: str) -> str:
    now = datetime.utcnow()
    payload = {
        "sub": user_id,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "iat": now,
        "exp": now + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES),
        "roles": ["user"]
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str

class AuthResponse(BaseModel):
    access_token: str
    user_id: str

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
        raise HTTPException(status_code=400, detail=error_message)
    
    user_id = resp.json().get("localId")
    token = _generate_jwt(user_id)
    return {"access_token": token, "user_id": user_id}

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

@router.post("/login", response_model=AuthResponse)
async def login_user(data: LoginRequest):
    if not settings.FIREBASE_API_KEY:
        raise HTTPException(status_code=500, detail="FIREBASE_API_KEY not set in environment")
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={settings.FIREBASE_API_KEY}"
    payload = {"email": data.email, "password": data.password, "returnSecureToken": True}
    resp = requests.post(url, json=payload)
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    user_id = resp.json().get("localId")
    token = _generate_jwt(user_id)
    return {"access_token": token, "user_id": user_id}

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