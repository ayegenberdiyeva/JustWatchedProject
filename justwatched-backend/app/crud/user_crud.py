from typing import Optional, Dict, Any
from app.schemas.user import UserRegister, UserLogin, UserProfile
from app.schemas.ai import TasteProfile
from app.core.firestore import get_firestore_client, run_in_threadpool
from google.cloud.firestore_v1.base_document import DocumentSnapshot
import uuid
from datetime import datetime

class UserCRUD:
    """
    Data access layer for user-related operations (Firestore integration).
    """
    def __init__(self):
        self.db = get_firestore_client()
        self.users_col = self.db.collection("users")
        self.taste_col = self.db.collection("taste_profiles")

    async def is_display_name_taken(self, display_name: str, exclude_user_id: Optional[str] = None) -> bool:
        """Check if a display name is already taken by another user."""
        def check_name():
            query = self.users_col.filter("display_name", "==", display_name).limit(1).stream()
            doc = next(query, None)
            if doc and exclude_user_id and doc.id == exclude_user_id:
                return False  # Same user, so name is not "taken"
            return doc is not None
        return await run_in_threadpool(check_name)

    async def register_user(self, user: UserRegister) -> UserProfile:
        # Check if display name is already taken
        if user.display_name:
            is_taken = await self.is_display_name_taken(user.display_name)
            if is_taken:
                raise ValueError(f"Display name '{user.display_name}' is already taken")
        
        user_id = str(uuid.uuid4())
        user_data = user.dict()
        user_data["user_id"] = user_id
        # Set default color for new users
        user_data["color"] = "red"
        # WARNING: Password should be hashed in production!
        await run_in_threadpool(lambda: self.users_col.document(user_id).set(user_data))
        return UserProfile(user_id=user_id, email=user.email, display_name=user.display_name, color="red")

    async def login_user(self, login: UserLogin) -> Optional[UserProfile]:
        # WARNING: Password should be hashed and checked securely in production!
        def find_user():
            query = self.users_col.filter("email", "==", login.email).filter("password", "==", login.password).limit(1).stream()
            return next(query, None)
        doc: DocumentSnapshot = await run_in_threadpool(find_user)
        if doc and doc.exists:
            data = doc.to_dict()
            # Set default color if not present
            color = data.get("color", "red")
            return UserProfile(
                user_id=data["user_id"], 
                email=data["email"], 
                display_name=data.get("display_name"),
                color=color
            )
        return None

    async def create_user_profile(self, user_id: str, data: Dict[str, Any]) -> None:
        # Check if display name is already taken by another user
        if "display_name" in data and data["display_name"]:
            is_taken = await self.is_display_name_taken(data["display_name"], exclude_user_id=user_id)
            if is_taken:
                raise ValueError(f"Display name '{data['display_name']}' is already taken")
        
        data = dict(data)
        data["created_at"] = datetime.utcnow().isoformat()
        await run_in_threadpool(lambda: self.users_col.document(user_id).set(data))

    async def update_user_profile(self, user_id: str, data: Dict[str, Any]) -> None:
        # Check if display name is already taken by another user
        if "display_name" in data and data["display_name"]:
            is_taken = await self.is_display_name_taken(data["display_name"], exclude_user_id=user_id)
            if is_taken:
                raise ValueError(f"Display name '{data['display_name']}' is already taken")
        
        await run_in_threadpool(lambda: self.users_col.document(user_id).set(data, merge=True))

    async def get_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        doc = await run_in_threadpool(lambda: self.users_col.document(user_id).get())
        if doc.exists:
            profile_data = doc.to_dict()
            # Ensure we have all expected fields with defaults
            profile_data["user_id"] = user_id  # Always include user_id
            
            # Handle required fields - provide fallbacks for existing data
            if not profile_data.get("display_name"):
                profile_data["display_name"] = f"user_{user_id[:8]}"  # Fallback display name
            if not profile_data.get("email"):
                profile_data["email"] = f"user_{user_id[:8]}@placeholder.com"  # Fallback email
            
            profile_data.setdefault("bio", None)
            # Handle both legacy "createdAt" and new "created_at" field names
            if "createdAt" in profile_data and "created_at" not in profile_data:
                profile_data["created_at"] = profile_data["createdAt"]
            profile_data.setdefault("created_at", None)
            profile_data.setdefault("personal_recommendations", None)
            
            # Ensure color is always a valid string
            if not profile_data.get("color"):
                profile_data["color"] = "red"
            elif profile_data["color"] is None:
                profile_data["color"] = "red"
            
            return profile_data
        return None

    async def get_user_by_display_name(self, display_name: str) -> Optional[Dict[str, Any]]:
        """Get user profile by display name (for finding users)."""
        def find_user():
            query = self.users_col.filter("display_name", "==", display_name).limit(1).stream()
            return next(query, None)
        
        doc = await run_in_threadpool(find_user)
        if doc and doc.exists:
            profile_data = doc.to_dict()
            profile_data["user_id"] = doc.id
            
            # Handle required fields - provide fallbacks for existing data
            if not profile_data.get("display_name"):
                profile_data["display_name"] = f"user_{doc.id[:8]}"  # Fallback display name
            if not profile_data.get("email"):
                profile_data["email"] = f"user_{doc.id[:8]}@placeholder.com"  # Fallback email
            
            profile_data.setdefault("bio", None)
            if "createdAt" in profile_data and "created_at" not in profile_data:
                profile_data["created_at"] = profile_data["createdAt"]
            profile_data.setdefault("created_at", None)
            profile_data.setdefault("personal_recommendations", None)
            
            # Ensure color is always a valid string
            if not profile_data.get("color"):
                profile_data["color"] = "red"
            elif profile_data["color"] is None:
                profile_data["color"] = "red"
            
            return profile_data
        return None

    async def update_taste_profile(self, user_id: str, taste: TasteProfile) -> TasteProfile:
        await run_in_threadpool(lambda: self.taste_col.document(user_id).set(taste.dict()))
        return taste

    async def get_taste_profile(self, user_id: str) -> Optional[TasteProfile]:
        doc = await run_in_threadpool(lambda: self.taste_col.document(user_id).get())
        if doc.exists:
            return TasteProfile(**doc.to_dict())
        return None

    async def get_all_users(self) -> list:
        """Get all users from the database."""
        def fetch_users():
            docs = self.users_col.stream()
            users = []
            for doc in docs:
                user_data = doc.to_dict()
                user_data["user_id"] = doc.id
                users.append(user_data)
            return users
        
        return await run_in_threadpool(fetch_users) 