# 20: DEPLOYMENT ARCHITECTURE

```yaml
META:
  version: 1.0
  status: EXTRACTED_FROM_EXISTING_SPEC
  priority: HIGH
  dependencies: [ALL]
  implements: Docker Compose multi-container deployment
  file_location: docker-compose.yml, Dockerfile
```

---

## **9\. DEPLOYMENT ARCHITECTURE**

### **9.1 Docker Compose Configuration**

Copy  
\# docker-compose.yml  
version: '3.8'

services:  
  \# Backend API (FastAPI)  
  backend:  
    build:  
      context: ./backend  
      dockerfile: Dockerfile  
    container\_name: analytics-backend  
    ports:  
      \- "8000:8000"  
    environment:  
      \- SUPABASE\_URL=${SUPABASE\_URL}  
      \- SUPABASE\_KEY=${SUPABASE\_KEY}  
      \- OPENAI\_API\_KEY=${OPENAI\_API\_KEY}  
      \- QDRANT\_URL=http://qdrant:6333  
      \- REDIS\_URL=redis://redis:6379  
    depends\_on:  
      \- redis  
      \- qdrant  
    volumes:  
      \- ./backend:/app  
      \- ./data:/app/data  
    command: uvicorn app.main:app \--host 0.0.0.0 \--port 8000 \--reload  
    
  \# Frontend (React)  
  frontend:  
    build:  
      context: ./frontend  
      dockerfile: Dockerfile  
    container\_name: analytics-frontend  
    ports:  
      \- "3000:3000"  
    environment:  
      \- REACT\_APP\_API\_URL=http://localhost:8000/api/v1  
    volumes:  
      \- ./frontend:/app  
      \- /app/node\_modules  
    command: npm start  
    
  \# Redis Cache  
  redis:  
    image: redis:7-alpine  
    container\_name: analytics-redis  
    ports:  
      \- "6379:6379"  
    volumes:  
      \- redis-data:/data  
    
  \# Qdrant Vector Database  
  qdrant:  
    image: qdrant/qdrant:latest  
    container\_name: analytics-qdrant  
    ports:  
      \- "6333:6333"  
      \- "6334:6334"  
    volumes:  
      \- qdrant-storage:/qdrant/storage  
    
  \# Nginx Reverse Proxy  
  nginx:  
    image: nginx:alpine  
    container\_name: analytics-nginx  
    ports:  
      \- "80:80"  
      \- "443:443"  
    volumes:  
      \- ./nginx/nginx.conf:/etc/nginx/nginx.conf  
      \- ./nginx/ssl:/etc/nginx/ssl  
    depends\_on:  
      \- backend  
      \- frontend

volumes:  
  redis-data:  
  qdrant-storage:

### **9.2 Backend Dockerfile**

Copy  
\# backend/Dockerfile  
FROM python:3.11\-slim

WORKDIR /app

\# Install system dependencies  
RUN apt-get update && apt-get install \-y \\  
    gcc \\  
    g++ \\  
    libpq-dev \\  
    && rm \-rf /var/lib/apt/lists/\*

\# Copy requirements  
COPY requirements.txt .  
RUN pip install \--no-cache-dir \-r requirements.txt

\# Copy application code  
COPY . .

\# Expose port  
EXPOSE 8000

\# Run application  
CMD \["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"\]

### **9.3 Frontend Dockerfile**

Copy  
\# frontend/Dockerfile  
FROM node:18\-alpine

WORKDIR /app

\# Copy package files  
COPY package\*.json ./  
RUN npm install

\# Copy application code  
COPY . .

\# Build for production  
RUN npm run build

\# Expose port  
EXPOSE 3000

\# Run application  
CMD \["npm", "start"\]

### **9.4 Nginx Configuration**

Copy  
\# nginx/nginx.conf  
**events** {  
    worker\_connections 1024;  
}

**http** {  
    **upstream** backend {  
        server backend:8000;  
    }  
      
    **upstream** frontend {  
        server frontend:3000;  
    }  
      
    **server** {  
        listen 80;  
        server\_name localhost;  
          
        \# Frontend  
        **location** / {  
            proxy\_pass http://frontend;  
            proxy\_http\_version 1.1;  
            proxy\_set\_header Upgrade $http\_upgrade;  
            proxy\_set\_header Connection 'upgrade';  
            proxy\_set\_header Host $host;  
            proxy\_cache\_bypass $http\_upgrade;  
        }  
          
        \# Backend API  
        **location** /api/ {  
            proxy\_pass http://backend;  
            proxy\_http\_version 1.1;  
            proxy\_set\_header Host $host;  
            proxy\_set\_header X-Real-IP $remote\_addr;  
            proxy\_set\_header X-Forwarded-For $proxy\_add\_x\_forwarded\_for;  
            proxy\_set\_header X-Forwarded-Proto $scheme;  
              
            \# CORS headers  
            add\_header 'Access-Control-Allow-Origin' '\*' always;  
            add\_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;  
            add\_header 'Access-Control-Allow-Headers' 'Content-Type' always;  
        }  
    }  
}

---



---

**DOCUMENT STATUS:** ✅ COMPLETE - Extracted from existing comprehensive spec
