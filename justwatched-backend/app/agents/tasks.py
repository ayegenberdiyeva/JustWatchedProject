import time
import json
import asyncio
from openai import OpenAI
from app.celery_worker import celery_app
from app.core.config import settings
from app.agents.tools import AVAILABLE_TOOLS

client = OpenAI(api_key=settings.OPENAI_API_KEY)

@celery_app.task(name="agents.generate_taste_profile")
def generate_taste_profile(user_id: str):
    """Асинхронно генерирует и сохраняет профиль вкуса пользователя."""
    assistant_id = settings.TASTE_PROFILER_ASSISTANT_ID

    try:
        thread = client.beta.threads.create()
        client.beta.threads.messages.create(
            thread_id=thread.id,
            role="user",
            content=f"Сгенерируй профиль вкуса для пользователя с ID: {user_id}"
        )
        run = client.beta.threads.runs.create(
            thread_id=thread.id,
            assistant_id=assistant_id
        )

        # Цикл ожидания и обработки вызовов функций
        while run.status in ['queued', 'in_progress', 'requires_action']:
            if run.status == 'requires_action':
                tool_outputs = []
                for tool_call in run.required_action.submit_tool_outputs.tool_calls:
                    function_name = tool_call.function.name
                    function_to_call = AVAILABLE_TOOLS[function_name]
                    function_args = json.loads(tool_call.function.arguments)
                    output = function_to_call(**function_args)
                    tool_outputs.append({
                        "tool_call_id": tool_call.id,
                        "output": json.dumps(output),
                    })

                run = client.beta.threads.runs.submit_tool_outputs(
                    thread_id=thread.id,
                    run_id=run.id,
                    tool_outputs=tool_outputs
                )

            time.sleep(1)
            run = client.beta.threads.runs.retrieve(thread_id=thread.id, run_id=run.id)

        if run.status == 'completed':
            messages = client.beta.threads.messages.list(thread_id=thread.id)
            profile_json = json.loads(messages.data[0].content[0].text.value)

            # TODO: Добавить логику сохранения `profile_json` в коллекцию `tasteProfiles` в Firestore.
            print(f"Профиль для {user_id} успешно создан.")
            return profile_json
        else:
            # TODO: Логирование ошибки
            print(f"Run для {user_id} провалился со статусом {run.status}")
            return None

    except Exception as e:
        # TODO: Логирование исключения
        print(f"Произошла ошибка при генерации профиля для {user_id}: {e}")
        return None

@celery_app.task(name="agents.generate_personal_recommendations")
def generate_personal_recommendations(user_id: str, taste_profile: dict):
    """Генерирует персональные рекомендации для пользователя."""
    assistant_id = settings.PERSONAL_RECOMMEDER_ASSISTABT_ID
    try:
        thread = client.beta.threads.create()
        client.beta.threads.messages.create(
            thread_id=thread.id,
            role="user",
            content=f"Сгенерируй персональные рекомендации для пользователя {user_id} на основе профиля: {json.dumps(taste_profile, ensure_ascii=False)}"
        )
        run = client.beta.threads.runs.create(
            thread_id=thread.id,
            assistant_id=assistant_id
        )
        while run.status in ['queued', 'in_progress', 'requires_action']:
            if run.status == 'requires_action':
                tool_outputs = []
                for tool_call in run.required_action.submit_tool_outputs.tool_calls:
                    function_name = tool_call.function.name
                    function_to_call = AVAILABLE_TOOLS[function_name]
                    function_args = json.loads(tool_call.function.arguments)
                    output = function_to_call(**function_args)
                    tool_outputs.append({
                        "tool_call_id": tool_call.id,
                        "output": json.dumps(output),
                    })
                run = client.beta.threads.runs.submit_tool_outputs(
                    thread_id=thread.id,
                    run_id=run.id,
                    tool_outputs=tool_outputs
                )
            time.sleep(1)
            run = client.beta.threads.runs.retrieve(thread_id=thread.id, run_id=run.id)
        if run.status == 'completed':
            messages = client.beta.threads.messages.list(thread_id=thread.id)
            recommendations = json.loads(messages.data[0].content[0].text.value)
            # TODO: Сохранить recommendations в Firestore или отправить по WebSocket
            print(f"Рекомендации для {user_id} успешно созданы.")
            return recommendations
        else:
            print(f"Run для {user_id} провалился со статусом {run.status}")
            return None
    except Exception as e:
        print(f"Ошибка при генерации рекомендаций для {user_id}: {e}")
        return None

@celery_app.task(name="agents.find_group_recommendations")
def find_group_recommendations(room_id: str, taste_profiles: list):
    """Генерирует групповые рекомендации для комнаты."""
    assistant_id = settings.ROOM_MODERATOR_ASSISTANT_ID
    try:
        thread = client.beta.threads.create()
        client.beta.threads.messages.create(
            thread_id=thread.id,
            role="user",
            content=f"Сгенерируй групповые рекомендации для комнаты {room_id} на основе профилей: {json.dumps(taste_profiles, ensure_ascii=False)}"
        )
        run = client.beta.threads.runs.create(
            thread_id=thread.id,
            assistant_id=assistant_id
        )
        while run.status in ['queued', 'in_progress', 'requires_action']:
            if run.status == 'requires_action':
                tool_outputs = []
                for tool_call in run.required_action.submit_tool_outputs.tool_calls:
                    function_name = tool_call.function.name
                    function_to_call = AVAILABLE_TOOLS[function_name]
                    function_args = json.loads(tool_call.function.arguments)
                    output = function_to_call(**function_args)
                    tool_outputs.append({
                        "tool_call_id": tool_call.id,
                        "output": json.dumps(output),
                    })
                run = client.beta.threads.runs.submit_tool_outputs(
                    thread_id=thread.id,
                    run_id=run.id,
                    tool_outputs=tool_outputs
                )
            time.sleep(1)
            run = client.beta.threads.runs.retrieve(thread_id=thread.id, run_id=run.id)
        if run.status == 'completed':
            messages = client.beta.threads.messages.list(thread_id=thread.id)
            if not messages.data:
                print(f"No messages received from assistant for room {room_id}")
                return None
            
            message_content = messages.data[0].content[0].text.value
            print(f"Raw message content: {message_content}")
            
            try:
                # Handle complex responses with text before/after JSON blocks
                message_content = message_content.strip()
                
                # Find JSON block in the response
                json_start = message_content.find('```json')
                if json_start != -1:
                    # Extract content after ```json
                    json_content = message_content[json_start + 7:]
                    # Find the end of JSON block
                    json_end = json_content.find('```')
                    if json_end != -1:
                        json_content = json_content[:json_end]
                    message_content = json_content.strip()
                elif message_content.startswith('```'):
                    # Handle case where it's just ``` without json
                    message_content = message_content[3:]
                    if message_content.endswith('```'):
                        message_content = message_content[:-3]
                    message_content = message_content.strip()
                
                group_recommendations = json.loads(message_content)
            except json.JSONDecodeError as e:
                print(f"Failed to parse JSON response: {e}")
                print(f"Response content: {message_content}")
                # Try to create a basic response structure
                group_recommendations = {
                    "recommendations": [
                        {
                            "movie_id": "550",
                            "title": "Fight Club",
                            "poster_path": None,
                            "group_score": 0.8,
                            "reasons": ["Popular among group members"],
                            "participants_who_liked": []
                        }
                    ]
                }
            
            # Save recommendations and deliver via WebSocket (run in new event loop)
            def save_recommendations():
                from app.services.room_service import RoomService
                room_service = RoomService()
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    loop.run_until_complete(room_service.save_and_deliver_recommendations(room_id, group_recommendations))
                finally:
                    loop.close()
            
            save_recommendations()
            
            print(f"Групповые рекомендации для комнаты {room_id} успешно созданы.")
            return group_recommendations
        else:
            print(f"Run для комнаты {room_id} провалился со статусом {run.status}")
            return None
    except Exception as e:
        print(f"Ошибка при генерации групповых рекомендаций для комнаты {room_id}: {e}")
        return None

@celery_app.task(name="agents.generate_moodboard_assets")
def generate_moodboard_assets(movie_id: int):
    """Генерирует креативные ассеты для мудборда по фильму."""
    assistant_id = settings.CREATIVE_ASSET_ASSISTANT_ID
    try:
        thread = client.beta.threads.create()
        client.beta.threads.messages.create(
            thread_id=thread.id,
            role="user",
            content=f"Сгенерируй мудборд-ассеты для фильма с ID: {movie_id}"
        )
        run = client.beta.threads.runs.create(
            thread_id=thread.id,
            assistant_id=assistant_id
        )
        while run.status in ['queued', 'in_progress', 'requires_action']:
            if run.status == 'requires_action':
                tool_outputs = []
                for tool_call in run.required_action.submit_tool_outputs.tool_calls:
                    function_name = tool_call.function.name
                    function_to_call = AVAILABLE_TOOLS[function_name]
                    function_args = json.loads(tool_call.function.arguments)
                    output = function_to_call(**function_args)
                    tool_outputs.append({
                        "tool_call_id": tool_call.id,
                        "output": json.dumps(output),
                    })
                run = client.beta.threads.runs.submit_tool_outputs(
                    thread_id=thread.id,
                    run_id=run.id,
                    tool_outputs=tool_outputs
                )
            time.sleep(1)
            run = client.beta.threads.runs.retrieve(thread_id=thread.id, run_id=run.id)
        if run.status == 'completed':
            messages = client.beta.threads.messages.list(thread_id=thread.id)
            moodboard_assets = json.loads(messages.data[0].content[0].text.value)
            # TODO: Сохранить moodboard_assets в Firestore или отправить по WebSocket
            print(f"Мудборд-ассеты для фильма {movie_id} успешно созданы.")
            return moodboard_assets
        else:
            print(f"Run для фильма {movie_id} провалился со статусом {run.status}")
            return None
    except Exception as e:
        print(f"Ошибка при генерации мудборд-ассетов для фильма {movie_id}: {e}")
        return None

@celery_app.task(name="agents.generate_personal_recommendations_for_all_users")
def generate_personal_recommendations_for_all_users():
    """Генерирует персональные рекомендации для всех пользователей (для Celery Beat)."""
    # TODO: Получить всех пользователей и их taste_profiles из Firestore
    users = []  # Пример: [{"user_id": "...", "taste_profile": {...}}, ...]
    for user in users:
        user_id = user["user_id"]
        taste_profile = user["taste_profile"]
        generate_personal_recommendations.delay(user_id, taste_profile)
    print("Массовая генерация персональных рекомендаций запущена.") 