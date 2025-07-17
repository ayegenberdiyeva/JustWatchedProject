# Token Refresh System Guide

## Overview

The JustWatched backend now supports a comprehensive token refresh system with the following features:

- **Access Tokens**: Short-lived tokens (60 minutes) for API access
- **Refresh Tokens**: Long-lived tokens (30 days) for token renewal
- **Automatic Refresh**: Middleware that automatically refreshes tokens when needed
- **Manual Refresh**: API endpoint for manual token refresh

## Configuration

### Environment Variables

Add these to your `.env` file:

```env
# JWT Settings
JWT_SECRET_KEY=your-super-secret-key-here
JWT_ALGORITHM=HS256
JWT_AUDIENCE=justwatched.app
JWT_ISSUER=justwatched.api
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60
JWT_REFRESH_TOKEN_EXPIRE_DAYS=30
```

## API Endpoints

### 1. Login/Register

**POST** `/api/v1/auth/login`
**POST** `/api/v1/auth/register`

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "user_id": "user123",
  "expires_in": 3600
}
```

### 2. Manual Token Refresh

**POST** `/api/v1/auth/refresh`

**Request:**
```json
{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "expires_in": 3600
}
```

## Frontend Integration

### 1. Basic Token Management

```typescript
interface TokenResponse {
  access_token: string;
  refresh_token: string;
  user_id: string;
  expires_in: number;
}

class TokenManager {
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private tokenExpiry: number | null = null;

  async login(email: string, password: string): Promise<TokenResponse> {
    const response = await fetch('/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });

    if (!response.ok) {
      throw new Error('Login failed');
    }

    const data: TokenResponse = await response.json();
    this.setTokens(data);
    return data;
  }

  async refreshTokens(): Promise<TokenResponse> {
    if (!this.refreshToken) {
      throw new Error('No refresh token available');
    }

    const response = await fetch('/api/v1/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: this.refreshToken })
    });

    if (!response.ok) {
      throw new Error('Token refresh failed');
    }

    const data: TokenResponse = await response.json();
    this.setTokens(data);
    return data;
  }

  private setTokens(data: TokenResponse): void {
    this.accessToken = data.access_token;
    this.refreshToken = data.refresh_token;
    this.tokenExpiry = Date.now() + (data.expires_in * 1000);
    
    // Store in localStorage or secure storage
    localStorage.setItem('access_token', data.access_token);
    localStorage.setItem('refresh_token', data.refresh_token);
    localStorage.setItem('token_expiry', this.tokenExpiry.toString());
  }

  getAccessToken(): string | null {
    return this.accessToken;
  }

  isTokenExpired(): boolean {
    return this.tokenExpiry ? Date.now() > this.tokenExpiry : true;
  }

  shouldRefreshToken(bufferMinutes: number = 5): boolean {
    if (!this.tokenExpiry) return true;
    const bufferTime = bufferMinutes * 60 * 1000;
    return Date.now() > (this.tokenExpiry - bufferTime);
  }
}
```

### 2. HTTP Client with Automatic Refresh

```typescript
class ApiClient {
  private tokenManager: TokenManager;
  private baseUrl: string;

  constructor(baseUrl: string, tokenManager: TokenManager) {
    this.baseUrl = baseUrl;
    this.tokenManager = tokenManager;
  }

  async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    // Check if token needs refresh
    if (this.tokenManager.shouldRefreshToken()) {
      try {
        await this.tokenManager.refreshTokens();
      } catch (error) {
        // Redirect to login if refresh fails
        window.location.href = '/login';
        throw error;
      }
    }

    const accessToken = this.tokenManager.getAccessToken();
    if (!accessToken) {
      throw new Error('No access token available');
    }

    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
        ...options.headers,
      },
    });

    // Check for token refresh headers
    const newAccessToken = response.headers.get('x-new-access-token');
    const newRefreshToken = response.headers.get('x-new-refresh-token');
    
    if (newAccessToken && newRefreshToken) {
      this.tokenManager.setTokens({
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
        user_id: '', // Not provided in headers
        expires_in: 3600
      });
    }

    if (!response.ok) {
      if (response.status === 401) {
        // Token is invalid, redirect to login
        window.location.href = '/login';
      }
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET' });
  }

  async post<T>(endpoint: string, data: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  async put<T>(endpoint: string, data: any): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }
}
```

### 3. React Hook for Token Management

```typescript
import { useState, useEffect, useCallback } from 'react';

interface UseAuthReturn {
  isAuthenticated: boolean;
  user: any | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  refreshTokens: () => Promise<void>;
}

export function useAuth(): UseAuthReturn {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState(null);
  const [tokenManager] = useState(() => new TokenManager());

  const login = useCallback(async (email: string, password: string) => {
    try {
      const response = await tokenManager.login(email, password);
      setIsAuthenticated(true);
      // Fetch user profile here if needed
    } catch (error) {
      console.error('Login failed:', error);
      throw error;
    }
  }, [tokenManager]);

  const logout = useCallback(() => {
    tokenManager.clearTokens();
    setIsAuthenticated(false);
    setUser(null);
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    localStorage.removeItem('token_expiry');
  }, [tokenManager]);

  const refreshTokens = useCallback(async () => {
    try {
      await tokenManager.refreshTokens();
    } catch (error) {
      logout();
      throw error;
    }
  }, [tokenManager, logout]);

  // Check authentication status on mount
  useEffect(() => {
    const accessToken = localStorage.getItem('access_token');
    const refreshToken = localStorage.getItem('refresh_token');
    
    if (accessToken && refreshToken) {
      tokenManager.setTokens({
        access_token: accessToken,
        refresh_token: refreshToken,
        user_id: '',
        expires_in: 3600
      });
      
      if (!tokenManager.isTokenExpired()) {
        setIsAuthenticated(true);
      } else {
        // Try to refresh token
        refreshTokens().catch(() => {
          logout();
        });
      }
    }
  }, [tokenManager, refreshTokens, logout]);

  return {
    isAuthenticated,
    user,
    login,
    logout,
    refreshTokens,
  };
}
```

### 4. Axios Interceptor Example

```typescript
import axios from 'axios';

const api = axios.create({
  baseURL: '/api/v1',
});

// Request interceptor
api.interceptors.request.use(
  async (config) => {
    const accessToken = localStorage.getItem('access_token');
    if (accessToken) {
      config.headers.Authorization = `Bearer ${accessToken}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor
api.interceptors.response.use(
  (response) => {
    // Check for token refresh headers
    const newAccessToken = response.headers['x-new-access-token'];
    const newRefreshToken = response.headers['x-new-refresh-token'];
    
    if (newAccessToken && newRefreshToken) {
      localStorage.setItem('access_token', newAccessToken);
      localStorage.setItem('refresh_token', newRefreshToken);
    }
    
    return response;
  },
  async (error) => {
    const originalRequest = error.config;
    
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      
      try {
        const refreshToken = localStorage.getItem('refresh_token');
        if (!refreshToken) {
          throw new Error('No refresh token');
        }
        
        const response = await axios.post('/api/v1/auth/refresh', {
          refresh_token: refreshToken,
        });
        
        const { access_token, refresh_token } = response.data;
        localStorage.setItem('access_token', access_token);
        localStorage.setItem('refresh_token', refresh_token);
        
        // Retry original request with new token
        originalRequest.headers.Authorization = `Bearer ${access_token}`;
        return api(originalRequest);
      } catch (refreshError) {
        // Refresh failed, redirect to login
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }
    
    return Promise.reject(error);
  }
);

export default api;
```

## Security Considerations

### 1. Token Storage
- **Access tokens**: Store in memory or short-term storage
- **Refresh tokens**: Store securely (httpOnly cookies, secure storage)
- **Never store tokens in localStorage for production** (use secure alternatives)

### 2. Token Rotation
- Refresh tokens are rotated on each refresh
- Old refresh tokens become invalid immediately
- This prevents token replay attacks

### 3. Token Expiry
- Access tokens expire quickly (60 minutes)
- Refresh tokens expire after 30 days
- Automatic refresh happens 5 minutes before expiry

### 4. Error Handling
- Handle 401 errors gracefully
- Redirect to login when refresh fails
- Clear all tokens on logout

## Testing

### 1. Test Token Expiry
```bash
# Set short expiry for testing
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1

# Make a request and wait for expiry
curl -H "Authorization: Bearer <token>" /api/v1/users/me

# Should get 401 after 1 minute
```

### 2. Test Token Refresh
```bash
# Use refresh token to get new access token
curl -X POST /api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "<refresh_token>"}'
```

### 3. Test Automatic Refresh
```bash
# Make request with expiring token
# Check response headers for x-new-access-token
curl -H "Authorization: Bearer <expiring_token>" \
  -H "x-refresh-token: <refresh_token>" \
  /api/v1/users/me
```

## Troubleshooting

### Common Issues

1. **Token not refreshing automatically**
   - Check if refresh token is being sent in headers
   - Verify middleware is properly configured
   - Check token expiry times

2. **401 errors after refresh**
   - Ensure refresh token is valid
   - Check if refresh token has expired
   - Verify JWT secret key is consistent

3. **CORS issues with token refresh**
   - Ensure refresh endpoint allows CORS
   - Check if credentials are being sent properly

### Debug Mode

Enable debug logging by setting:
```env
LOG_LEVEL=DEBUG
```

This will log token operations and middleware actions. 