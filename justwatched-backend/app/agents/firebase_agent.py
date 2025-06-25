import firebase_admin
from firebase_admin import auth
from app.core.firestore import run_in_threadpool

class FirebaseAgent:
    """
    Handles Firebase authentication and user info retrieval.
    """
    async def verify_id_token(self, id_token: str) -> dict:
        """Verify a Firebase ID token and return the decoded claims."""
        return await run_in_threadpool(lambda: auth.verify_id_token(id_token))

    async def get_user(self, uid: str) -> dict:
        """Get Firebase user info by UID."""
        user_record = await run_in_threadpool(lambda: auth.get_user(uid))
        return user_record.__dict__ 