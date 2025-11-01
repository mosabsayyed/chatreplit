from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from contextlib import asynccontextmanager
from app.api.v1 import health, setup
from app.api.routes import chat, debug, embeddings
from app.db.postgres_client import postgres_client
import os

@asynccontextmanager
async def lifespan(app: FastAPI):
    await postgres_client.connect()
    print("✅ Database connected successfully")
    yield
    await postgres_client.disconnect()
    print("👋 Database disconnected")

app = FastAPI(
    title="JOSOOR - Transformation Analytics Platform",
    description="Autonomous analytical agent for enterprise transformation analytics",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="/api/v1/health", tags=["Health"])
app.include_router(setup.router, prefix="/api/v1/setup", tags=["Setup"])
app.include_router(chat.router, prefix="/api/v1/chat", tags=["Chat"])
app.include_router(debug.router, prefix="/api/v1", tags=["Debug"])
app.include_router(embeddings.router, prefix="/api/v1/embeddings", tags=["Embeddings"])

frontend_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "frontend")
if os.path.exists(frontend_dir):
    app.mount("/static", StaticFiles(directory=frontend_dir), name="static")

@app.get("/")
async def root():
    frontend_path = os.path.join(frontend_dir, "index.html")
    if os.path.exists(frontend_path):
        return FileResponse(frontend_path)
    return {
        "message": "Welcome to JOSOOR Transformation Analytics Platform",
        "version": "1.0.0",
        "docs": "/docs"
    }
