"""
Configuration Module for JOSOOR
"""
import os

class Settings:
    """Application settings"""
    
    # LLM Provider Configuration
    LLM_PROVIDER = os.getenv("LLM_PROVIDER", "replit")  # replit, openai, or anthropic
    
    # Database Configuration
    DATABASE_URL = os.getenv("DATABASE_URL")
    
    # Current year for filters
    CURRENT_YEAR = 2025
    
    # Debug mode
    DEBUG_MODE = os.getenv("DEBUG_MODE", "false").lower() == "true"
    DEBUG_PROMPTS = os.getenv("DEBUG_PROMPTS", "false").lower() == "true"

settings = Settings()
