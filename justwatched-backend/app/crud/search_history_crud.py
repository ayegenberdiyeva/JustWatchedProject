from typing import List, Dict, Any, Optional
from app.core.firestore import get_firestore_client, run_in_threadpool
from app.schemas.search import SearchHistoryEntry, SearchHistoryRequest
from datetime import datetime, timedelta
import uuid

class SearchHistoryCRUD:
    """
    Data access layer for search history operations (Firestore integration).
    """
    def __init__(self):
        self.db = get_firestore_client()
        self.search_history_col = self.db.collection("search_history")

    async def create_search_entry(self, user_id: str, search_data: SearchHistoryRequest) -> SearchHistoryEntry:
        """Create a new search history entry."""
        search_id = str(uuid.uuid4())
        entry_data = {
            "search_id": search_id,
            "user_id": user_id,
            "query": search_data.query,
            "timestamp": datetime.utcnow().isoformat(),
            "result_count": search_data.result_count,
            "search_type": search_data.search_type,
            "clicked_results": search_data.clicked_results or [],
            "session_id": search_data.session_id
        }
        
        await run_in_threadpool(lambda: self.search_history_col.document(search_id).set(entry_data))
        
        # Convert back to SearchHistoryEntry for response
        entry_data["timestamp"] = datetime.fromisoformat(entry_data["timestamp"])
        return SearchHistoryEntry(**entry_data)

    async def get_user_search_history(
        self, 
        user_id: str, 
        limit: int = 20, 
        offset: int = 0,
        days_back: Optional[int] = None
    ) -> List[SearchHistoryEntry]:
        """Get search history for a specific user with pagination and optional time filter."""
        def fetch():
            query = self.search_history_col.where("user_id", "==", user_id)
            
            # Add time filter if specified
            if days_back:
                cutoff_date = datetime.utcnow() - timedelta(days=days_back)
                query = query.where("timestamp", ">=", cutoff_date.isoformat())
            
            # Order by timestamp descending (most recent first)
            query = query.order_by("timestamp", direction="DESCENDING")
            
            # Apply pagination
            query = query.offset(offset).limit(limit)
            
            docs = query.stream()
            entries = []
            for doc in docs:
                if doc.exists:
                    data = doc.to_dict()
                    # Convert timestamp string back to datetime
                    if isinstance(data["timestamp"], str):
                        data["timestamp"] = datetime.fromisoformat(data["timestamp"])
                    entries.append(SearchHistoryEntry(**data))
            return entries
        
        return await run_in_threadpool(fetch)

    async def get_total_search_count(self, user_id: str, days_back: Optional[int] = None) -> int:
        """Get total count of searches for a user."""
        def count():
            query = self.search_history_col.where("user_id", "==", user_id)
            
            if days_back:
                cutoff_date = datetime.utcnow() - timedelta(days=days_back)
                query = query.where("timestamp", ">=", cutoff_date.isoformat())
            
            docs = query.stream()
            return len(list(docs))
        
        return await run_in_threadpool(count)

    async def update_clicked_results(self, search_id: str, clicked_movie_id: str) -> bool:
        """Update a search entry to record which movie was clicked."""
        def update():
            doc_ref = self.search_history_col.document(search_id)
            doc = doc_ref.get()
            if doc.exists:
                data = doc.to_dict()
                clicked_results = data.get("clicked_results", [])
                if clicked_movie_id not in clicked_results:
                    clicked_results.append(clicked_movie_id)
                    doc_ref.update({"clicked_results": clicked_results})
                return True
            return False
        
        return await run_in_threadpool(update)

    async def delete_search_entry(self, user_id: str, search_id: str) -> bool:
        """Delete a specific search entry (only if it belongs to the user)."""
        def delete():
            doc_ref = self.search_history_col.document(search_id)
            doc = doc_ref.get()
            if doc.exists:
                data = doc.to_dict()
                if data.get("user_id") == user_id:
                    doc_ref.delete()
                    return True
            return False
        
        return await run_in_threadpool(delete)

    async def clear_user_search_history(self, user_id: str, days_back: Optional[int] = None) -> int:
        """Clear all search history for a user, optionally within a time range."""
        def clear():
            query = self.search_history_col.where("user_id", "==", user_id)
            
            if days_back:
                cutoff_date = datetime.utcnow() - timedelta(days=days_back)
                query = query.where("timestamp", ">=", cutoff_date.isoformat())
            
            docs = query.stream()
            deleted_count = 0
            for doc in docs:
                doc.reference.delete()
                deleted_count += 1
            
            return deleted_count
        
        return await run_in_threadpool(clear)

    async def get_search_analytics(self, user_id: str, days_back: int = 30) -> Dict[str, Any]:
        """Get analytics data for user's search patterns."""
        def analyze():
            cutoff_date = datetime.utcnow() - timedelta(days=days_back)
            query = self.search_history_col.where("user_id", "==", user_id).where("timestamp", ">=", cutoff_date.isoformat())
            
            docs = query.stream()
            searches = [doc.to_dict() for doc in docs if doc.exists]
            
            if not searches:
                return {
                    "total_searches": 0,
                    "unique_queries": 0,
                    "most_searched_terms": [],
                    "search_frequency_by_day": [],
                    "average_results_per_search": 0.0
                }
            
            # Count total searches
            total_searches = len(searches)
            
            # Count unique queries
            unique_queries = len(set(search["query"].lower() for search in searches))
            
            # Most searched terms
            query_counts = {}
            for search in searches:
                query_lower = search["query"].lower()
                query_counts[query_lower] = query_counts.get(query_lower, 0) + 1
            
            most_searched = sorted(query_counts.items(), key=lambda x: x[1], reverse=True)[:10]
            most_searched_terms = [{"query": query, "count": count} for query, count in most_searched]
            
            # Search frequency by day
            day_counts = {}
            for search in searches:
                if isinstance(search["timestamp"], str):
                    search_date = datetime.fromisoformat(search["timestamp"]).date()
                else:
                    search_date = search["timestamp"].date()
                day_counts[search_date.isoformat()] = day_counts.get(search_date.isoformat(), 0) + 1
            
            search_frequency_by_day = [{"date": date, "count": count} for date, count in day_counts.items()]
            
            # Average results per search
            result_counts = [search.get("result_count", 0) for search in searches if search.get("result_count") is not None]
            average_results = sum(result_counts) / len(result_counts) if result_counts else 0.0
            
            return {
                "total_searches": total_searches,
                "unique_queries": unique_queries,
                "most_searched_terms": most_searched_terms,
                "search_frequency_by_day": search_frequency_by_day,
                "average_results_per_search": round(average_results, 2)
            }
        
        return await run_in_threadpool(analyze) 