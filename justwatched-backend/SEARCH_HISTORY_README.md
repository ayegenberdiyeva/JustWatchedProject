# Search History Feature Implementation

## Overview
The search history feature allows users to track their movie search queries, view their search patterns, and get personalized search suggestions. This implementation follows the layered architecture pattern (API → Services → CRUD → Data Access) and integrates seamlessly with the existing FilmLog AI backend.

## Features

### Core Functionality
- **Search Recording**: Automatically record all user searches with metadata
- **Search History Viewing**: Paginated view of user's search history
- **Click Tracking**: Record which movies users click on from search results
- **Search Analytics**: Detailed analytics on search patterns and behavior
- **Recent Searches**: Get recent search queries for autocomplete
- **Popular Searches**: Get most frequently searched terms
- **History Management**: Delete individual entries or clear entire history

### Advanced Features
- **Time-based Filtering**: Filter searches by date range
- **Session Tracking**: Track searches by session for better analytics
- **Search Type Classification**: Categorize searches (movie, tv, person, etc.)
- **Result Count Tracking**: Track how many results each search returned
- **Anonymous Search**: Allow searches without authentication (no history tracking)
- **Multi-Type Search**: Search across different content types (movies, TV shows, people, etc.)

## TMDB API Integration

### How Search Types Work

The system now properly routes searches to different TMDB API endpoints based on the `search_type` parameter:

#### Supported Search Types:

1. **Movies** (`search_type="movie"` or `"movies"`)
   - **TMDB Endpoint**: `/search/movie`
   - **Returns**: Movie results with title, release date, poster, etc.

2. **TV Shows** (`search_type="tv"`, `"tvshow"`, `"tvshows"`, or `"series"`)
   - **TMDB Endpoint**: `/search/tv`
   - **Returns**: TV show results with name, first air date, poster, etc.

3. **People** (`search_type="person"`, `"people"`, `"actor"`, `"actors"`, `"director"`, or `"directors"`)
   - **TMDB Endpoint**: `/search/person`
   - **Returns**: Person results with name, known for, profile photo, etc.

4. **Companies** (`search_type="company"` or `"companies"`)
   - **TMDB Endpoint**: `/search/company`
   - **Returns**: Production company results

5. **Collections** (`search_type="collection"` or `"collections"`)
   - **TMDB Endpoint**: `/search/collection`
   - **Returns**: Movie collection results

6. **Keywords** (`search_type="keyword"` or `"keywords"`)
   - **TMDB Endpoint**: `/search/keyword`
   - **Returns**: Keyword/tag results

7. **Multi-Search** (`search_type="multi"`)
   - **TMDB Endpoint**: `/search/multi`
   - **Returns**: Mixed results from movies, TV shows, and people

### Search Flow Example

```python
# When user searches for "batman" with search_type="movie"
GET /api/v1/movies/search?query=batman&search_type=movie

# The system:
# 1. Calls TMDB API: GET https://api.themoviedb.org/3/search/movie?api_key=xxx&query=batman
# 2. Records in search history with search_type="movie"
# 3. Returns movie results to user
```

## API Endpoints

### Search History Management
```
GET    /api/v1/search-history                    # Get user's search history
POST   /api/v1/search-history/record             # Record a new search
DELETE /api/v1/search-history/{search_id}        # Delete specific search entry
DELETE /api/v1/search-history                    # Clear all search history
```

### Analytics & Insights
```
GET    /api/v1/search-history/analytics          # Get search analytics
GET    /api/v1/search-history/recent             # Get recent searches
GET    /api/v1/search-history/popular            # Get popular searches
```

### Enhanced Search (Multi-Type)
```
GET    /api/v1/search-with-history               # Search with automatic history tracking
GET    /api/v1/movies/search                     # Enhanced movie search (with history)
GET    /api/v1/movies/search-anonymous           # Anonymous search (no history)
GET    /api/v1/movies/search-multi               # Multi-search across all types
```

### Click Tracking
```
POST   /api/v1/search-history/{search_id}/click/{movie_id}  # Record movie click
```

## Data Models

### SearchHistoryEntry
```python
{
    "search_id": "uuid",
    "user_id": "user_uuid",
    "query": "search query string",
    "timestamp": "2024-01-01T12:00:00Z",
    "result_count": 25,
    "search_type": "movie",  # Now actually reflects the TMDB endpoint used
    "clicked_results": ["movie_id_1", "movie_id_2"],
    "session_id": "session_uuid"
}
```

### SearchAnalytics
```python
{
    "total_searches": 150,
    "unique_queries": 45,
    "most_searched_terms": [
        {"query": "batman", "count": 12},
        {"query": "marvel", "count": 8}
    ],
    "search_frequency_by_day": [
        {"date": "2024-01-01", "count": 5},
        {"date": "2024-01-02", "count": 3}
    ],
    "average_results_per_search": 18.5
}
```

## Usage Examples

### 1. Search Movies
```bash
# Search for movies
GET /api/v1/movies/search?query=batman&search_type=movie
Authorization: Bearer <jwt_token>

# Response includes movie results from TMDB /search/movie endpoint
{
    "page": 1,
    "results": [
        {
            "id": 268,
            "title": "Batman",
            "release_date": "1989-06-23",
            "poster_path": "/kBf3g9crrADGMc4L7LECwUzRqMk.jpg"
        }
    ],
    "total_pages": 1,
    "total_results": 1
}
```

### 2. Search TV Shows
```bash
# Search for TV shows
GET /api/v1/movies/search?query=breaking&search_type=tv
Authorization: Bearer <jwt_token>

# Response includes TV show results from TMDB /search/tv endpoint
{
    "page": 1,
    "results": [
        {
            "id": 1396,
            "name": "Breaking Bad",
            "first_air_date": "2008-01-20",
            "poster_path": "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg"
        }
    ],
    "total_pages": 1,
    "total_results": 1
}
```

### 3. Search People
```bash
# Search for actors/directors
GET /api/v1/movies/search?query=christopher&search_type=person
Authorization: Bearer <jwt_token>

# Response includes person results from TMDB /search/person endpoint
{
    "page": 1,
    "results": [
        {
            "id": 525,
            "name": "Christopher Nolan",
            "known_for_department": "Directing",
            "profile_path": "/xuAIuYSmsUzKlUMBFGVZaWsYaxD.jpg"
        }
    ],
    "total_pages": 1,
    "total_results": 1
}
```

### 4. Multi-Search
```bash
# Search across all types
GET /api/v1/movies/search-multi?query=batman
Authorization: Bearer <jwt_token>

# Response includes mixed results from TMDB /search/multi endpoint
{
    "page": 1,
    "results": [
        {
            "id": 268,
            "media_type": "movie",
            "title": "Batman",
            "release_date": "1989-06-23"
        },
        {
            "id": 1234,
            "media_type": "tv",
            "name": "Batman: The Animated Series",
            "first_air_date": "1992-09-05"
        },
        {
            "id": 567,
            "media_type": "person",
            "name": "Christian Bale",
            "known_for_department": "Acting"
        }
    ],
    "total_pages": 1,
    "total_results": 3
}
```

### 5. View Search History by Type
```bash
# Get recent searches with pagination
GET /api/v1/search-history?limit=20&offset=0&days_back=30
Authorization: Bearer <jwt_token>

# Response shows different search types
{
    "searches": [
        {
            "search_id": "uuid1",
            "user_id": "user_uuid",
            "query": "batman",
            "timestamp": "2024-01-01T12:00:00Z",
            "result_count": 25,
            "search_type": "movie",  # Actually searched movies
            "clicked_results": ["268"],
            "session_id": "session_uuid"
        },
        {
            "search_id": "uuid2",
            "user_id": "user_uuid",
            "query": "breaking bad",
            "timestamp": "2024-01-01T13:00:00Z",
            "result_count": 5,
            "search_type": "tv",     # Actually searched TV shows
            "clicked_results": ["1396"],
            "session_id": "session_uuid"
        }
    ],
    "total_count": 150,
    "has_more": true
}
```

## Database Schema

### Firestore Collection: `search_history`
```javascript
{
    "search_id": "uuid",
    "user_id": "user_uuid",
    "query": "search query",
    "timestamp": "2024-01-01T12:00:00Z",
    "result_count": 25,
    "search_type": "movie",  // Now accurately reflects TMDB endpoint used
    "clicked_results": ["movie_id_1", "movie_id_2"],
    "session_id": "session_uuid"
}
```

### Indexes Required
- `user_id` (ascending)
- `user_id` + `timestamp` (descending)
- `user_id` + `timestamp` (for time-based queries)
- `user_id` + `search_type` (for filtering by search type)

## Implementation Details

### Architecture Layers

1. **API Layer** (`app/api/v1/endpoints/search_history.py`)
   - Handles HTTP requests/responses
   - Input validation with Pydantic
   - Authentication and authorization
   - Error handling

2. **Service Layer** (`app/services/search_history_service.py`)
   - Business logic coordination
   - Data transformation
   - Integration between different components

3. **CRUD Layer** (`app/crud/search_history_crud.py`)
   - Data access operations
   - Firestore queries
   - Data persistence

4. **Schema Layer** (`app/schemas/search.py`)
   - Pydantic models for validation
   - Request/response models
   - Data structure definitions

### Key Features

#### 1. Proper TMDB API Routing
- **Before**: All searches went to `/search/movie` regardless of search_type
- **After**: Searches are routed to appropriate TMDB endpoints based on search_type
- **Benefit**: Users get accurate results for the content type they're searching

#### 2. Multi-Search Support
- New `/search-multi` endpoint for searching across all content types
- Uses TMDB's `/search/multi` endpoint
- Returns mixed results with `media_type` field

#### 3. Search Type Validation
- `get_tmdb_search_endpoint()` function maps search types to correct TMDB endpoints
- Supports aliases (e.g., "tv", "tvshow", "series" all map to TV search)
- Defaults to movie search for unknown types

#### 4. Enhanced Analytics
- Search history now accurately reflects what was actually searched
- Analytics can show user preferences by content type
- Better insights into user behavior

#### 5. Privacy & Security
- User-specific search history (isolated by user_id)
- Authentication required for history features
- Anonymous search option available
- Secure deletion of search history

#### 6. Performance Optimizations
- Pagination for large search histories
- Efficient Firestore queries with proper indexing
- Async/await for all database operations
- Caching-friendly design

## Integration Points

### With Existing Features
- **Authentication**: Uses existing JWT authentication system
- **Movie Search**: Integrates with TMDB API search functionality
- **User Management**: Links search history to user profiles
- **Recommendations**: Search patterns can feed into recommendation algorithms

### Future Enhancements
- **AI-Powered Suggestions**: Use search history for intelligent autocomplete
- **Search Optimization**: Analyze search patterns to improve search relevance
- **Personalization**: Use search history for personalized movie recommendations
- **Analytics Dashboard**: Web interface for viewing search analytics
- **Search Type Preferences**: Learn user preferences for different content types

## Testing

### Unit Tests
- Test each layer independently
- Mock external dependencies (Firestore, TMDB API)
- Test edge cases and error conditions
- Test search type routing logic

### Integration Tests
- Test complete search flow for each search type
- Test authentication integration
- Test data persistence and retrieval
- Test multi-search functionality

### API Tests
- Test all endpoints with various inputs
- Test authentication and authorization
- Test error handling and validation
- Test search type parameter validation

## Deployment Considerations

### Environment Variables
- Ensure all required environment variables are set
- Configure Firestore credentials properly
- Set up proper authentication

### Database Setup
- Create required Firestore indexes
- Set up proper security rules
- Configure backup and retention policies

### Monitoring
- Monitor search performance
- Track API usage and errors
- Set up alerts for system issues
- Monitor TMDB API rate limits

## Security Considerations

### Data Privacy
- Search history is user-specific and isolated
- Users can delete their own search history
- No cross-user data access

### Authentication
- All history-related endpoints require authentication
- JWT tokens are validated for each request
- Anonymous search available for public access

### Data Validation
- All inputs are validated with Pydantic
- Query length limits prevent abuse
- Search type validation prevents invalid API calls
- Proper error handling prevents data leakage

## Performance Considerations

### Database Optimization
- Proper Firestore indexes for efficient queries
- Pagination to handle large datasets
- Efficient query patterns

### Caching Strategy
- Consider Redis caching for frequently accessed data
- Cache search analytics results
- Implement cache invalidation strategies

### Scalability
- Async operations for better concurrency
- Efficient data structures
- Proper error handling and retry logic
- TMDB API rate limiting considerations 