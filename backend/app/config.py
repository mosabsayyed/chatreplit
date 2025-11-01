from pydantic_settings import BaseSettings
from pydantic import ConfigDict
from typing import Optional
import os

class Settings(BaseSettings):
    model_config = ConfigDict(env_file=".env", case_sensitive=True)
    
    DATABASE_URL: str = os.getenv("SUPABASE_CONN") or os.getenv("DATABASE_URL", "")
    PGHOST: str = os.getenv("SUPABASE_HOST") or os.getenv("PGHOST", "localhost")
    PGPORT: int = int(os.getenv("SUPABASE_PORT") or os.getenv("PGPORT", "5432"))
    PGUSER: str = os.getenv("SUPABASE_USER") or os.getenv("PGUSER", "postgres")
    PGPASSWORD: str = os.getenv("SUPABASE_PASSWORD", "")
    PGDATABASE: str = os.getenv("SUPABASE_DATABASE") or os.getenv("PGDATABASE", "postgres")
    
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    
    NEO4J_URI: str = os.getenv("NEO4J_URI", "")
    NEO4J_USERNAME: str = os.getenv("NEO4J_USERNAME", "neo4j")
    NEO4J_PASSWORD: str = os.getenv("NEO4J_PASSWORD", "")
    NEO4J_DATABASE: str = os.getenv("NEO4J_DATABASE", "neo4j")
    
    OPENAI_API_KEY: Optional[str] = os.getenv("AI_INTEGRATIONS_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    OPENAI_BASE_URL: Optional[str] = os.getenv("AI_INTEGRATIONS_OPENAI_BASE_URL") or os.getenv("OPENAI_BASE_URL")
    
    LLM_PROVIDER: str = os.getenv("LLM_PROVIDER", "replit")
    
    EMBEDDING_MODEL: str = "text-embedding-3-small"

settings = Settings()
