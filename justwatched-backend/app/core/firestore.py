import os
import firebase_admin
from firebase_admin import credentials, firestore
from functools import lru_cache
from concurrent.futures import ThreadPoolExecutor
import asyncio
from pathlib import Path

_executor = ThreadPoolExecutor()

@lru_cache()
def get_firestore_client():
    if not firebase_admin._apps:
        cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "./firebase-key.json")
        # cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        cred_path = Path(cred_path)
        if not cred_path.is_absolute():
            # Resolve relative to project root (where main.py is run)
            cred_path = Path(os.getcwd()) / cred_path
        if not cred_path.exists():
            raise FileNotFoundError(f"Firebase credentials file not found at: {cred_path}")
        cred = credentials.Certificate(str(cred_path))
        firebase_admin.initialize_app(cred)
    return firestore.client()

async def run_in_threadpool(func, *args, **kwargs):
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(_executor, lambda: func(*args, **kwargs)) 