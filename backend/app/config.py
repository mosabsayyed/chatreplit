from pydantic_settings import BaseSettings
from pydantic import ConfigDict
from typing import Optional
import os

class Settings(BaseSettings):
    model_config = ConfigDict(env_file=".env", case_sensitive=True)
    
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    PGHOST: str = os.getenv("PGHOST", "localhost")
    PGPORT: int = int(os.getenv("PGPORT", "5432"))
    PGUSER: str = os.getenv("PGUSER", "postgres")
    PGPASSWORD: str = os.getenv("PGPASSWORD", "")
    PGDATABASE: str = os.getenv("PGDATABASE", "postgres")
    
    OPENAI_API_KEY: Optional[str] = os.getenv("AI_INTEGRATIONS_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    OPENAI_BASE_URL: Optional[str] = os.getenv("AI_INTEGRATIONS_OPENAI_BASE_URL") or os.getenv("OPENAI_BASE_URL")
    
    LLM_PROVIDER: str = os.getenv("LLM_PROVIDER", "replit")
    
    EMBEDDING_MODEL: str = "text-embedding-3-small"

settings = Settings()
