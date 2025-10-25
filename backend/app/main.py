from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.api.v1 import health
from app.api.routes import chat, debug
from app.db.postgres_client import postgres_client
import os

app = FastAPI(
    title="JOSOOR - Transformation Analytics Platform",
    description="Autonomous analytical agent for enterprise transformation analytics",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="/api/v1/health", tags=["Health"])
app.include_router(chat.router, prefix="/api/v1/chat", tags=["Chat"])
app.include_router(debug.router, prefix="/api/v1", tags=["Debug"])

frontend_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "frontend")
if os.path.exists(frontend_dir):
    app.mount("/static", StaticFiles(directory=frontend_dir), name="static")

@app.on_event("startup")
async def startup():
    await postgres_client.connect()
    print("✅ Database connected successfully")

@app.on_event("shutdown")
async def shutdown():
    await postgres_client.disconnect()
    print("👋 Database disconnected")

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
