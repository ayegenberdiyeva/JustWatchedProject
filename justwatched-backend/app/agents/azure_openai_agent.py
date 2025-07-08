import os
import requests
import json
import re
import demjson3
from app.core.config import settings

class AzureOpenAIAgent:
    def __init__(self):
        self.api_key = settings.AZURE_OPENAI_KEY
        self.endpoint = settings.AZURE_ENDPOINT.rstrip('/')
        self.deployment = settings.AZURE_DEPLOYMENT_NAME
        self.api_version = getattr(settings, 'AZURE_API_VERSION', '2024-04-01-preview')

    def extract_json_from_string(self, s):
        # Remove markdown code fences if present
        s = s.strip()
        if s.startswith('```json'):
            s = s[len('```json'):].strip()
        if s.startswith('```'):
            s = s[len('```'):].strip()
        if s.endswith('```'):
            s = s[:-3].strip()
        # Find the first {...} block, non-greedy
        match = re.search(r'({.*?})', s, re.DOTALL)
        if match:
            return match.group(1)
        return s  # fallback

    def chat(self, messages, temperature=0.8, max_tokens=4000):
        url = f"{self.endpoint}/openai/deployments/{self.deployment}/chat/completions?api-version={self.api_version}"
        headers = {
            "api-key": self.api_key,
            "Content-Type": "application/json"
        }
        data = {
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        response = requests.post(url, headers=headers, json=data)
        response.raise_for_status()
        content = response.json()["choices"][0]["message"]["content"].strip()
        # Try parsing the whole output first
        try:
            return json.loads(content)
        except Exception as e:
            print("[AzureOpenAIAgent] json.loads() failed:", e)
            # Try extracting JSON block
            json_str = self.extract_json_from_string(content)
            try:
                return json.loads(json_str)
            except Exception as e2:
                print("[AzureOpenAIAgent] extract_json_from_string failed:", e2)
                # Try tolerant parsing
                try:
                    return demjson3.decode(json_str)
                except Exception as e3:
                    print("[AzureOpenAIAgent] LLM raw output (for debugging):\n", content)
                    raise e3

    async def analyze_taste_profile(self, user_id: str, reviews: list) -> dict:
        """Analyze user reviews to generate a taste profile."""
        if not reviews:
            return {
                "user_id": user_id,
                "favorite_genres": [],
                "favorite_actors": [],
                "favorite_directors": [],
                "mood_preferences": [],
                "preferred_era": "modern",
                "preferred_language": "english"
            }
        
        # Prepare reviews for analysis
        reviews_text = "\n".join([
            f"Movie: {review.get('movie_title', 'Unknown')}, "
            f"Rating: {review.get('rating', 0)}, "
            f"Review: {review.get('review_text', '')}"
            for review in reviews[:20]  # Limit to 20 most recent reviews
        ])
        
        messages = [
            {
                "role": "system",
                "content": """You are a film taste analyzer. Analyze the user's movie reviews and create a comprehensive taste profile. 
                Return ONLY a JSON object with the following structure:
                {
                    "user_id": "string",
                    "favorite_genres": ["list", "of", "genres"],
                    "favorite_actors": ["list", "of", "actors"],
                    "favorite_directors": ["list", "of", "directors"],
                    "mood_preferences": ["list", "of", "moods"],
                    "preferred_era": "modern|classic|mixed",
                    "preferred_language": "english|foreign|mixed",
                    "analysis_confidence": 0.85
                }"""
            },
            {
                "role": "user",
                "content": f"Analyze these movie reviews for user {user_id}:\n\n{reviews_text}"
            }
        ]
        
        return self.chat(messages, temperature=0.3)

    async def generate_personal_recommendations(self, user_id: str, taste_profile: dict) -> dict:
        """Generate personal movie recommendations based on taste profile."""
        messages = [
            {
                "role": "system",
                "content": """You are a movie recommendation expert. Generate 20 personalized movie recommendations.
                Return ONLY a JSON object with the following structure:
                {
                    "recommendations": [
                        {
                            "movie_id": "string",
                            "title": "string",
                            "poster_path": "string or null",
                            "confidence_score": 0.85,
                            "reasoning": "string explaining why this movie matches the user's taste"
                        }
                    ],
                    "generated_at": "timestamp"
                }"""
            },
            {
                "role": "user",
                "content": f"Generate recommendations for user {user_id} with taste profile: {json.dumps(taste_profile, ensure_ascii=False)}"
            }
        ]
        
        return self.chat(messages, temperature=0.7, max_tokens=6000)

    async def generate_group_recommendations(self, room_id: str, taste_profiles: list) -> dict:
        """Generate group recommendations based on multiple taste profiles."""
        profiles_text = "\n".join([
            f"User {profile.get('user_id', 'unknown')}: {json.dumps(profile, ensure_ascii=False)}"
            for profile in taste_profiles
        ])
        
        messages = [
            {
                "role": "system",
                "content": """You are a group movie recommendation expert. Generate 7-10 movies that would appeal to the group.
                Return ONLY a JSON object with the following structure:
                {
                    "recommendations": [
                        {
                            "movie_id": "string",
                            "title": "string",
                            "poster_path": "string or null",
                            "group_score": 0.85,
                            "reasons": ["list", "of", "reasons"],
                            "participants_who_liked": ["list", "of", "user_ids"]
                        }
                    ],
                    "room_id": "string",
                    "generated_at": "timestamp"
                }"""
            },
            {
                "role": "user",
                "content": f"Generate group recommendations for room {room_id} with taste profiles:\n\n{profiles_text}"
            }
        ]
        
        return self.chat(messages, temperature=0.6)

    async def generate_moodboard(self, movie_id: int, movie_details: dict) -> dict:
        """Generate moodboard assets for a movie."""
        movie_info = f"Title: {movie_details.get('title', 'Unknown')}\n"
        movie_info += f"Overview: {movie_details.get('overview', '')}\n"
        movie_info += f"Genres: {', '.join([g['name'] for g in movie_details.get('genres', [])])}\n"
        movie_info += f"Release Date: {movie_details.get('release_date', '')}"
        
        messages = [
            {
                "role": "system",
                "content": """You are a creative moodboard generator. Create a moodboard for the given movie.
                Return ONLY a JSON object with the following structure:
                {
                    "movie_id": "integer",
                    "color_palette": {
                        "primary": "#hexcolor",
                        "secondary": "#hexcolor",
                        "accent": "#hexcolor"
                    },
                    "mood_keywords": ["list", "of", "moods"],
                    "music_suggestions": [
                        {
                            "title": "string",
                            "artist": "string",
                            "genre": "string",
                            "mood": "string"
                        }
                    ],
                    "visual_elements": ["list", "of", "visual", "elements"],
                    "atmosphere_description": "string"
                }"""
            },
            {
                "role": "user",
                "content": f"Generate a moodboard for this movie:\n\n{movie_info}"
            }
        ]
        
        return self.chat(messages, temperature=0.8) 