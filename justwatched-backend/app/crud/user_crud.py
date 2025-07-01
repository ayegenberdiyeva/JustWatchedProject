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

    async def register_user(self, user: UserRegister) -> UserProfile:
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
            query = self.users_col.where("email", "==", login.email).where("password", "==", login.password).limit(1).stream()
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
                avatar_url=data.get("avatar_url"),
                color=color
            )
        return None

    async def create_user_profile(self, user_id: str, data: Dict[str, Any]) -> None:
        data = dict(data)
        data["createdAt"] = datetime.utcnow().isoformat()
        await run_in_threadpool(lambda: self.users_col.document(user_id).set(data))

    async def update_user_profile(self, user_id: str, data: Dict[str, Any]) -> None:
        await run_in_threadpool(lambda: self.users_col.document(user_id).set(data, merge=True))

    async def get_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        doc = await run_in_threadpool(lambda: self.users_col.document(user_id).get())
        if doc.exists:
            profile_data = doc.to_dict()
            # Ensure we have all expected fields with defaults
            profile_data.setdefault("display_name", None)
            profile_data.setdefault("email", None)
            profile_data.setdefault("bio", None)
            profile_data.setdefault("avatar_url", None)
            profile_data.setdefault("created_at", profile_data.get("createdAt"))  # Handle legacy field name
            profile_data.setdefault("personal_recommendations", None)
            # Set default color if not present (lazy default)
            profile_data.setdefault("color", "red")
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