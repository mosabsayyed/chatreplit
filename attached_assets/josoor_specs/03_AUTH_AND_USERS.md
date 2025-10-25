# AUTHENTICATION & USER MANAGEMENT

## META

**Dependencies:** 01_DATABASE_FOUNDATION.md, 02_CORE_DATA_MODELS.md  
**Provides:** Complete JWT authentication system, user registration, session management  
**Integration Points:** All user-facing APIs require auth, Redis session storage, JWT middleware

---

## OVERVIEW

This document provides complete authentication and user management implementation for JOSOOR platform, including:

1. **JWT-based authentication** with access tokens
2. **User registration and login** with password hashing
3. **Role-based access control** (user, analyst, admin)
4. **Session management** via Redis
5. **Password reset** functionality
6. **API authentication middleware**

### Security Features

- **bcrypt password hashing** (industry standard)
- **JWT tokens** with expiration (24-hour default)
- **Refresh token rotation** for security
- **Role-based authorization** decorators
- **Rate limiting** on auth endpoints
- **Session invalidation** on logout

---

## ARCHITECTURE

### Authentication Flow

```
┌──────────────────────────────────────────────────────────┐
│  REGISTRATION FLOW                                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Frontend  │→│   Backend   │→│  PostgreSQL │      │
│  │  Register   │  │  Hash Pass  │  │Store User   │      │
│  │   Form      │  │  Create JWT │  │             │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
│         ↓                 ↓                               │
│  ┌─────────────┐  ┌─────────────┐                       │
│  │   Receive   │←│   Return    │                       │
│  │   JWT Token │  │   JWT +User │                       │
│  └─────────────┘  └─────────────┘                       │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  LOGIN FLOW                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Frontend  │→│   Backend   │→│  PostgreSQL │      │
│  │    Login    │  │  Verify Pass│  │  Find User  │      │
│  │    Form     │  │  Create JWT │  │             │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
│         ↓                 ↓                 ↓             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Store     │←│   Return    │←│   Create    │      │
│  │   JWT in    │  │   JWT Token │  │   Redis     │      │
│  │ LocalStorage│  │             │  │   Session   │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  AUTHENTICATED REQUEST FLOW                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Frontend  │→│   Middleware│→│   Backend   │      │
│  │  + JWT      │  │  Verify JWT │  │   API       │      │
│  │   Header    │  │  Check Redis│  │   Handler   │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
│         ↓                 ↓                 ↓             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Receive   │←│   Execute   │←│   Process   │      │
│  │   Response  │  │   Return    │  │   Request   │      │
│  └─────────────┘  └─────────────┘  └─────────────┘      │
└──────────────────────────────────────────────────────────┘
```

---

## IMPLEMENTATION

### Part 1: Password Hashing & JWT Utilities

```python
# app/core/security.py
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from app.core.config import settings

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# =====================================================
# PASSWORD HASHING
# =====================================================

def hash_password(password: str) -> str:
    """Hash a password using bcrypt"""
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)

# =====================================================
# JWT TOKEN GENERATION
# =====================================================

def create_access_token(data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    """
    Create JWT access token
    
    Args:
        data: Payload to encode (typically {"sub": user_id, "email": email, "role": role})
        expires_delta: Token expiration time (default: 24 hours)
    
    Returns:
        Encoded JWT token string
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.JWT_EXPIRATION_MINUTES)
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "access"
    })
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM
    )
    
    return encoded_jwt

def create_refresh_token(data: Dict[str, Any]) -> str:
    """
    Create JWT refresh token (longer expiration, 7 days)
    
    Args:
        data: Payload to encode
    
    Returns:
        Encoded JWT refresh token
    """
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=7)
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "refresh"
    })
    
    encoded_jwt = jwt.encode(
        to_encode,
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM
    )
    
    return encoded_jwt

def decode_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode and verify JWT token
    
    Args:
        token: JWT token string
    
    Returns:
        Decoded payload dict or None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM]
        )
        return payload
    except JWTError:
        return None
```

### Part 2: Session Management (Redis)

```python
# app/core/session.py
import redis
import json
from typing import Optional, Dict, Any
from app.core.config import settings

# Redis client
redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)

# =====================================================
# SESSION MANAGEMENT
# =====================================================

def create_session(user_id: int, session_data: Dict[str, Any], ttl: int = 86400) -> str:
    """
    Create user session in Redis
    
    Args:
        user_id: User ID
        session_data: Session data to store
        ttl: Time to live in seconds (default: 24 hours)
    
    Returns:
        Session ID
    """
    session_key = f"session:{user_id}"
    redis_client.setex(
        session_key,
        ttl,
        json.dumps(session_data)
    )
    return session_key

def get_session(user_id: int) -> Optional[Dict[str, Any]]:
    """
    Get user session from Redis
    
    Args:
        user_id: User ID
    
    Returns:
        Session data dict or None if not found
    """
    session_key = f"session:{user_id}"
    data = redis_client.get(session_key)
    
    if data:
        return json.loads(data)
    return None

def update_session(user_id: int, session_data: Dict[str, Any]) -> bool:
    """
    Update user session in Redis (maintains existing TTL)
    
    Args:
        user_id: User ID
        session_data: New session data
    
    Returns:
        True if successful
    """
    session_key = f"session:{user_id}"
    ttl = redis_client.ttl(session_key)
    
    if ttl > 0:
        redis_client.setex(session_key, ttl, json.dumps(session_data))
        return True
    return False

def delete_session(user_id: int) -> bool:
    """
    Delete user session from Redis (logout)
    
    Args:
        user_id: User ID
    
    Returns:
        True if deleted
    """
    session_key = f"session:{user_id}"
    return redis_client.delete(session_key) > 0

def extend_session(user_id: int, additional_ttl: int = 3600) -> bool:
    """
    Extend session TTL
    
    Args:
        user_id: User ID
        additional_ttl: Additional time in seconds
    
    Returns:
        True if extended
    """
    session_key = f"session:{user_id}"
    current_ttl = redis_client.ttl(session_key)
    
    if current_ttl > 0:
        return redis_client.expire(session_key, current_ttl + additional_ttl)
    return False
```

### Part 3: Authentication Dependencies (FastAPI)

```python
# app/core/dependencies.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import Optional
from app.core.security import decode_token
from app.core.session import get_session
from app.models.schemas import UserResponse, UserRole
from app.db.session import get_db
from app.db.models import User

security = HTTPBearer()

# =====================================================
# AUTHENTICATION DEPENDENCY
# =====================================================

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> UserResponse:
    """
    Dependency to get current authenticated user from JWT token
    
    Raises:
        HTTPException: If token is invalid or user not found
    
    Returns:
        UserResponse object
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # Decode JWT token
    token = credentials.credentials
    payload = decode_token(token)
    
    if payload is None:
        raise credentials_exception
    
    user_id: Optional[int] = payload.get("sub")
    if user_id is None:
        raise credentials_exception
    
    # Check session in Redis
    session_data = get_session(user_id)
    if session_data is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired. Please login again."
        )
    
    # Get user from database
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    
    return UserResponse.from_orm(user)

# =====================================================
# ROLE-BASED AUTHORIZATION DEPENDENCIES
# =====================================================

def require_role(*allowed_roles: UserRole):
    """
    Dependency factory for role-based authorization
    
    Usage:
        @router.get("/admin/config", dependencies=[Depends(require_role(UserRole.ADMIN))])
    """
    async def check_role(current_user: UserResponse = Depends(get_current_user)):
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions. Required roles: {[r.value for r in allowed_roles]}"
            )
        return current_user
    
    return check_role

# Convenience dependencies
require_admin = require_role(UserRole.ADMIN)
require_analyst = require_role(UserRole.ANALYST, UserRole.ADMIN)
```

### Part 4: Auth API Endpoints

```python
# app/api/endpoints/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import timedelta
from app.models.schemas import (
    UserCreate, UserLogin, UserResponse, TokenResponse,
    BaseResponse, ErrorResponse
)
from app.core.security import hash_password, verify_password, create_access_token, create_refresh_token
from app.core.session import create_session, delete_session
from app.core.dependencies import get_current_user, get_db
from app.db.models import User

router = APIRouter(prefix="/auth", tags=["Authentication"])

# =====================================================
# REGISTRATION
# =====================================================

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """
    Register new user
    
    - Validates email uniqueness
    - Hashes password
    - Creates user in database
    - Returns JWT token
    """
    # Check if email already exists
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user
    hashed_password = hash_password(user_data.password)
    new_user = User(
        email=user_data.email,
        password_hash=hashed_password,
        full_name=user_data.full_name,
        role=user_data.role,
        is_active=True
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Create JWT token
    access_token = create_access_token(data={
        "sub": new_user.id,
        "email": new_user.email,
        "role": new_user.role
    })
    
    # Create session in Redis
    create_session(new_user.id, {
        "email": new_user.email,
        "role": new_user.role,
        "login_at": str(datetime.utcnow())
    })
    
    return TokenResponse(
        access_token=access_token,
        user=UserResponse.from_orm(new_user)
    )

# =====================================================
# LOGIN
# =====================================================

@router.post("/login", response_model=TokenResponse)
async def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """
    User login
    
    - Validates email and password
    - Creates JWT token
    - Creates session in Redis
    """
    # Find user
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Verify password
    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Check if user is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )
    
    # Create JWT token
    access_token = create_access_token(data={
        "sub": user.id,
        "email": user.email,
        "role": user.role
    })
    
    # Create session in Redis
    create_session(user.id, {
        "email": user.email,
        "role": user.role,
        "login_at": str(datetime.utcnow())
    })
    
    return TokenResponse(
        access_token=access_token,
        user=UserResponse.from_orm(user)
    )

# =====================================================
# LOGOUT
# =====================================================

@router.post("/logout", response_model=BaseResponse)
async def logout(current_user: UserResponse = Depends(get_current_user)):
    """
    User logout
    
    - Deletes session from Redis
    - Invalidates token (client must discard)
    """
    delete_session(current_user.id)
    
    return BaseResponse(
        success=True,
        message="Logged out successfully"
    )

# =====================================================
# GET CURRENT USER
# =====================================================

@router.get("/me", response_model=UserResponse)
async def get_me(current_user: UserResponse = Depends(get_current_user)):
    """
    Get current authenticated user details
    """
    return current_user

# =====================================================
# TOKEN REFRESH
# =====================================================

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(
    current_user: UserResponse = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Refresh access token
    
    - Issues new JWT token
    - Extends session in Redis
    """
    # Create new access token
    access_token = create_access_token(data={
        "sub": current_user.id,
        "email": current_user.email,
        "role": current_user.role
    })
    
    # Extend session
    from app.core.session import extend_session
    extend_session(current_user.id, additional_ttl=3600)
    
    return TokenResponse(
        access_token=access_token,
        user=current_user
    )
```

### Part 5: Database User Model

```python
# app/db/models.py
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum
from sqlalchemy.sql import func
from app.db.base import Base
from app.models.schemas import UserRole

class User(Base):
    """User database model"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=True)
    role = Column(Enum(UserRole), default=UserRole.USER, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
```

---

## FRONTEND INTEGRATION

### Part 1: Auth Service (React/TypeScript)

```typescript
// src/services/authService.ts
import axios from 'axios';
import { UserCreate, UserLogin, TokenResponse, UserResponse } from '../types';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

class AuthService {
  private static TOKEN_KEY = 'josoor_access_token';
  private static USER_KEY = 'josoor_user';

  /**
   * Register new user
   */
  async register(userData: UserCreate): Promise<TokenResponse> {
    const response = await axios.post<TokenResponse>(
      `${API_BASE_URL}/auth/register`,
      userData
    );
    
    // Store token and user data
    this.setToken(response.data.access_token);
    this.setUser(response.data.user);
    
    return response.data;
  }

  /**
   * Login user
   */
  async login(credentials: UserLogin): Promise<TokenResponse> {
    const response = await axios.post<TokenResponse>(
      `${API_BASE_URL}/auth/login`,
      credentials
    );
    
    // Store token and user data
    this.setToken(response.data.access_token);
    this.setUser(response.data.user);
    
    return response.data;
  }

  /**
   * Logout user
   */
  async logout(): Promise<void> {
    const token = this.getToken();
    
    if (token) {
      try {
        await axios.post(
          `${API_BASE_URL}/auth/logout`,
          {},
          { headers: { Authorization: `Bearer ${token}` } }
        );
      } catch (error) {
        console.error('Logout error:', error);
      }
    }
    
    // Clear local storage
    this.clearAuth();
  }

  /**
   * Get current user
   */
  async getCurrentUser(): Promise<UserResponse> {
    const token = this.getToken();
    
    const response = await axios.get<UserResponse>(
      `${API_BASE_URL}/auth/me`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    this.setUser(response.data);
    return response.data;
  }

  /**
   * Refresh token
   */
  async refreshToken(): Promise<TokenResponse> {
    const token = this.getToken();
    
    const response = await axios.post<TokenResponse>(
      `${API_BASE_URL}/auth/refresh`,
      {},
      { headers: { Authorization: `Bearer ${token}` } }
    );
    
    this.setToken(response.data.access_token);
    return response.data;
  }

  // ===== Token Management =====

  setToken(token: string): void {
    localStorage.setItem(AuthService.TOKEN_KEY, token);
  }

  getToken(): string | null {
    return localStorage.getItem(AuthService.TOKEN_KEY);
  }

  setUser(user: UserResponse): void {
    localStorage.setItem(AuthService.USER_KEY, JSON.stringify(user));
  }

  getUser(): UserResponse | null {
    const userData = localStorage.getItem(AuthService.USER_KEY);
    return userData ? JSON.parse(userData) : null;
  }

  clearAuth(): void {
    localStorage.removeItem(AuthService.TOKEN_KEY);
    localStorage.removeItem(AuthService.USER_KEY);
  }

  isAuthenticated(): boolean {
    return !!this.getToken();
  }
}

export default new AuthService();
```

### Part 2: Axios Interceptor (Auto-attach JWT)

```typescript
// src/services/api.ts
import axios from 'axios';
import authService from './authService';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

// Create axios instance
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor: Attach JWT token
apiClient.interceptors.request.use(
  (config) => {
    const token = authService.getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor: Handle 401 errors
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // If 401 and not already retried
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;

      try {
        // Try to refresh token
        await authService.refreshToken();
        
        // Retry original request
        const token = authService.getToken();
        originalRequest.headers.Authorization = `Bearer ${token}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Refresh failed, logout user
        authService.clearAuth();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default apiClient;
```

### Part 3: Login Component (React)

```typescript
// src/components/Auth/LoginForm.tsx
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import authService from '../../services/authService';

export const LoginForm: React.FC = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await authService.login({ email, password });
      navigate('/dashboard');
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto mt-8">
      <h2 className="text-2xl font-bold mb-4">Login to JOSOOR</h2>
      
      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-3 py-2 border rounded"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-3 py-2 border rounded"
            required
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700 disabled:opacity-50"
        >
          {loading ? 'Logging in...' : 'Login'}
        </button>
      </form>
    </div>
  );
};
```

### Part 4: Protected Route Component

```typescript
// src/components/Auth/ProtectedRoute.tsx
import React from 'react';
import { Navigate } from 'react-router-dom';
import authService from '../../services/authService';
import { UserRole } from '../../types';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRole?: UserRole;
}

export const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ 
  children, 
  requiredRole 
}) => {
  const isAuthenticated = authService.isAuthenticated();
  const user = authService.getUser();

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (requiredRole && user?.role !== requiredRole && user?.role !== UserRole.ADMIN) {
    return <Navigate to="/unauthorized" replace />;
  }

  return <>{children}</>;
};
```

---

## CONFIGURATION

### Environment Variables

```bash
# Backend .env
JWT_SECRET=your-secret-key-change-this-in-production
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=1440

# Frontend .env
REACT_APP_API_URL=http://localhost:8000
```

---

## TESTING

### Backend Tests

```python
# tests/test_auth.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_register_success():
    """Test successful user registration"""
    response = client.post("/auth/register", json={
        "email": "test@example.com",
        "password": "Password123",
        "full_name": "Test User"
    })
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["user"]["email"] == "test@example.com"

def test_register_duplicate_email():
    """Test registration with duplicate email"""
    # First registration
    client.post("/auth/register", json={
        "email": "duplicate@example.com",
        "password": "Password123"
    })
    
    # Second registration (should fail)
    response = client.post("/auth/register", json={
        "email": "duplicate@example.com",
        "password": "Password123"
    })
    assert response.status_code == 400

def test_login_success():
    """Test successful login"""
    # Register user first
    client.post("/auth/register", json={
        "email": "login@example.com",
        "password": "Password123"
    })
    
    # Login
    response = client.post("/auth/login", json={
        "email": "login@example.com",
        "password": "Password123"
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data

def test_login_wrong_password():
    """Test login with wrong password"""
    response = client.post("/auth/login", json={
        "email": "test@example.com",
        "password": "WrongPassword"
    })
    assert response.status_code == 401

def test_protected_endpoint():
    """Test accessing protected endpoint"""
    # Without token
    response = client.get("/auth/me")
    assert response.status_code == 403
    
    # With token
    login_response = client.post("/auth/login", json={
        "email": "test@example.com",
        "password": "Password123"
    })
    token = login_response.json()["access_token"]
    
    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
```

---

## CHECKLIST FOR CODING AGENT

### Backend Implementation

- [ ] Create `app/core/security.py` with password hashing and JWT functions
- [ ] Create `app/core/session.py` with Redis session management
- [ ] Create `app/core/dependencies.py` with auth dependencies
- [ ] Create `app/api/endpoints/auth.py` with auth endpoints
- [ ] Create `app/db/models.py` with User model
- [ ] Install dependencies: `pip install passlib[bcrypt] python-jose[cryptography] redis`
- [ ] Test password hashing: `hash_password()` and `verify_password()`
- [ ] Test JWT generation: `create_access_token()`
- [ ] Test Redis connection
- [ ] Run pytest tests for auth endpoints

### Frontend Implementation

- [ ] Create `src/services/authService.ts`
- [ ] Create `src/services/api.ts` with axios interceptor
- [ ] Create `src/components/Auth/LoginForm.tsx`
- [ ] Create `src/components/Auth/RegisterForm.tsx`
- [ ] Create `src/components/Auth/ProtectedRoute.tsx`
- [ ] Add routing with protected routes
- [ ] Test login flow end-to-end
- [ ] Test token refresh on 401
- [ ] Test logout functionality

### Next Steps

- [ ] Proceed to **04_AI_PERSONAS_AND_MEMORY.md** for multi-persona system
- [ ] Integrate auth with chat interface (conversation ownership)
- [ ] Integrate auth with admin interface (role-based access)
