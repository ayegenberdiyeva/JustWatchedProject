# JustWatched 🎬

A comprehensive movie discovery and social watching platform that combines AI-powered recommendations, group watching experiences, and social features to create the ultimate movie companion app.

## 🌟 Features

### 🎯 Core Features
- **AI-Powered Recommendations**: Personalized movie suggestions based on taste profiles
- **Group Watch Rooms**: Create and join virtual movie watching sessions with friends
- **Social Features**: Friend connections, reviews, and shared collections
- **Watchlist Management**: Organize and track movies you want to watch
- **Moodboards**: Create visual collections and share your movie taste
- **Real-time Chat**: Communicate with friends during group watch sessions
- **Search & Discovery**: Advanced movie search with TMDB integration

### 🤖 AI Capabilities
- **Taste Profiling**: AI analyzes your preferences to build personalized profiles
- **Smart Recommendations**: Context-aware movie suggestions
- **Room Moderation**: AI-assisted group watch room management
- **Creative Assets**: AI-generated moodboards and visual content

## 🏗️ Architecture

### Backend (FastAPI + Python)
- **Framework**: FastAPI with async/await support
- **Database**: Google Cloud Firestore
- **Authentication**: JWT with Firebase integration
- **Message Queue**: Redis + Celery for background tasks
- **AI Integration**: Azure OpenAI for intelligent features
- **External APIs**: TMDB for movie data
- **Real-time**: WebSocket support for live features

### Frontend (iOS SwiftUI)
- **Framework**: SwiftUI with MVVM architecture
- **Features**: Native iOS app with modern UI/UX
- **Networking**: Custom NetworkService for API communication
- **State Management**: ObservableObject pattern with ViewModels

### Infrastructure
- **Containerization**: Docker with multi-stage builds
- **Orchestration**: Docker Compose for local development
- **Production**: Azure deployment with CI/CD
- **Monitoring**: Application Insights integration
- **Load Balancing**: Nginx reverse proxy

## 📁 Project Structure

```
justwatched-project/
├── justwatched-backend/          # FastAPI backend
│   ├── app/
│   │   ├── api/v1/endpoints/     # API endpoints
│   │   ├── core/                 # Configuration & utilities
│   │   ├── crud/                 # Database operations
│   │   ├── schemas/              # Pydantic models
│   │   ├── services/             # Business logic
│   │   └── tasks/                # Celery background tasks
│   ├── docker-compose.yml        # Development environment
│   └── requirements.txt          # Python dependencies
├── justwatched-frontend/         # iOS SwiftUI app
│   └── justwatched-app/
│       ├── Features/             # Feature modules
│       ├── Shared/               # Shared components
│       └── Core/                 # Core services
└── .github/workflows/            # CI/CD pipeline
```

## 🚀 Quick Start

### Prerequisites
- Python 3.12+
- Docker & Docker Compose
- Xcode 15+ (for iOS development)
- Firebase project setup
- Azure OpenAI account
- TMDB API key

### Backend Setup

1. **Clone and navigate to backend**:
   ```bash
   cd justwatched-backend
   ```

2. **Create environment file**:
   ```bash
   cp .env.template .env
   # Edit .env with your configuration
   ```

3. **Start with Docker**:
   ```bash
   docker-compose up -d
   ```

4. **Or run locally**:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   uvicorn app.main:app --reload
   ```

### iOS App Setup

1. **Open in Xcode**:
   ```bash
   open justwatched-app.xcodeproj
   ```

2. **Configure API endpoints** in `NetworkService.swift`

3. **Build and run** on simulator or device

## 🔧 Configuration

### Environment Variables

#### Backend (.env)
```env
# Project
PROJECT_NAME=JustWatched
API_V1_STR=/api/v1

# Firebase
GOOGLE_APPLICATION_CREDENTIALS=./firebase-key.json
FIREBASE_API_KEY=your_firebase_api_key

# Azure OpenAI
AZURE_OPENAI_KEY=your_azure_openai_key
AZURE_ENDPOINT=your_azure_endpoint
AZURE_DEPLOYMENT_NAME=your_deployment_name

# External APIs
TMDB_API_KEY=your_tmdb_api_key

# JWT
JWT_SECRET_KEY=your_jwt_secret
JWT_ALGORITHM=HS256

# Redis/Celery
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
```

### Firebase Setup
1. Create a Firebase project
2. Enable Authentication (Email/Password)
3. Enable Firestore Database
4. Download service account key as `firebase-key.json`
5. Configure iOS app with Firebase

## 📱 API Documentation

### Core Endpoints

- **Authentication**: `/api/v1/auth/`
- **Users**: `/api/v1/users/`
- **Movies**: `/api/v1/movies/`
- **Rooms**: `/api/v1/rooms/`
- **Reviews**: `/api/v1/reviews/`
- **Watchlist**: `/api/v1/watchlist/`
- **Friends**: `/api/v1/friends/`
- **AI**: `/api/v1/ai/`
- **WebSocket**: `/api/v1/websocket/`

### Interactive API Docs
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## 🧪 Testing

### Backend Testing
```bash
# Run tests
pytest

# Run with coverage
pytest --cov=app tests/
```

### iOS Testing
- Use Xcode's built-in testing framework
- Unit tests for ViewModels
- UI tests for critical user flows

## 🚀 Deployment

### Production Deployment
The project uses GitHub Actions for automated deployment:

1. **Push to main branch** triggers deployment
2. **Self-hosted runner** handles the deployment
3. **Docker Compose** orchestrates production services
4. **Health checks** ensure service availability

### Manual Deployment
```bash
# Production deployment
docker-compose -f docker-compose.production.yml up -d --build
```

## 🔍 Monitoring & Observability

- **Health Checks**: `/healthcheck` endpoint
- **Application Insights**: Azure monitoring integration
- **Logging**: Structured logging with Azure Log Analytics
- **Metrics**: Prometheus-compatible metrics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow PEP 8 for Python code
- Use Swift style guidelines for iOS code
- Write tests for new features
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **TMDB** for comprehensive movie database
- **Firebase** for backend services
- **Azure OpenAI** for AI capabilities
- **FastAPI** for the excellent Python framework
- **SwiftUI** for modern iOS development

## 📞 Support

For support, email support@justwatched.app or create an issue in this repository.

---

**JustWatched** - Discover, Watch, Share 🎬✨