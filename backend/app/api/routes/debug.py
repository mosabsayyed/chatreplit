# backend/app/api/routes/debug.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import os

router = APIRouter()

class DebugToggleRequest(BaseModel):
    enabled: bool

@router.post("/debug/prompts/toggle")
async def toggle_debug_prompts(request: DebugToggleRequest):
    """
    Enable or disable debug mode to see actual prompts sent to LLM
    
    WARNING: Debug mode prints sensitive prompts to console logs
    Only use in development
    """
    if request.enabled:
        os.environ["DEBUG_PROMPTS"] = "true"
        return {
            "status": "enabled",
            "message": "Debug mode ON - All LLM prompts will be logged to console",
            "warning": "Check server logs to see prompts"
        }
    else:
        os.environ["DEBUG_PROMPTS"] = "false"
        return {
            "status": "disabled",
            "message": "Debug mode OFF"
        }

@router.get("/debug/prompts/status")
async def get_debug_status():
    """Check if debug mode is enabled"""
    enabled = os.getenv("DEBUG_PROMPTS", "false").lower() == "true"
    return {
        "debug_enabled": enabled,
        "message": "Debug logs visible in server console" if enabled else "Debug mode disabled"
    }

@router.get("/debug/database-config")
async def get_database_config():
    """Check which database the server is connected to"""
    from app.config import settings
    
    # Test the logic directly
    test_value = os.getenv("SUPABASE_HOST") or os.getenv("PGHOST", "localhost")
    
    return {
        "settings_PGHOST": settings.PGHOST,
        "settings_PGPORT": settings.PGPORT,
        "settings_PGDATABASE": settings.PGDATABASE,
        "settings_PGUSER": settings.PGUSER,
        "env_SUPABASE_HOST": os.getenv("SUPABASE_HOST"),
        "env_PGHOST": os.getenv("PGHOST"),
        "env_SUPABASE_PORT": os.getenv("SUPABASE_PORT"),
        "env_SUPABASE_DATABASE": os.getenv("SUPABASE_DATABASE"),
        "env_SUPABASE_USER": os.getenv("SUPABASE_USER"),
        "test_logic_result": test_value
    }
