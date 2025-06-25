import os
import openai
from app.core.config import settings

class OpenAIAgent:
    def __init__(self):
        api_key = os.getenv("OPENAI_API_KEY", getattr(settings, "OPENAI_API_KEY", None))
        self.client = openai.AsyncOpenAI(api_key=api_key)
        self.personal_recommender_id = settings.PERSONAL_RECOMMEDER_ASSISTABT_ID
        self.taste_profiler_id = settings.TASTE_PROFILER_ASSISTANT_ID
        self.room_moderator_id = settings.ROOM_MODERATOR_ASSISTANT_ID
        self.creative_asset_id = settings.CREATIVE_ASSET_ASSISTANT_ID

    async def _run_assistant(self, assistant_id: str, input_data: dict):
        response = await self.client.responses.create(
            assistant_id=assistant_id,
            input=input_data
        )
        # Wait for completion if needed (depends on OpenAI SDK version)
        # Here, we assume response.result contains the output
        return getattr(response, "result", response)

    async def generate_film_recommendations(self, user_id: str, watch_history: list):
        input_data = {
            "user_id": user_id,
            "watch_history": watch_history
        }
        return await self._run_assistant(self.personal_recommender_id, input_data)

    async def generate_taste_profile(self, user_id: str, watch_history: list):
        input_data = {
            "user_id": user_id,
            "watch_history": watch_history
        }
        return await self._run_assistant(self.taste_profiler_id, input_data)

    async def moderate_room(self, room_id: str, messages: list):
        input_data = {
            "room_id": room_id,
            "messages": messages
        }
        return await self._run_assistant(self.room_moderator_id, input_data)

    async def generate_moodboard_assets(self, user_id: str, preferences: dict):
        input_data = {
            "user_id": user_id,
            "preferences": preferences
        }
        return await self._run_assistant(self.creative_asset_id, input_data) 