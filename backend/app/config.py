from typing import Optional
import os

class Settings:
    def __init__(self):
        # PostgreSQL connection settings - prioritize SUPABASE_* env vars
        print(f"🔧 Initializing Settings...")
        print(f"  SUPABASE_HOST env: {os.getenv('SUPABASE_HOST')}")
        print(f"  PGHOST env: {os.getenv('PGHOST')}")
        
        self.DATABASE_URL: str = os.getenv("SUPABASE_CONN") or os.getenv("DATABASE_URL", "")
        self.PGHOST: str = os.getenv("SUPABASE_HOST") or os.getenv("PGHOST", "localhost")
        self.PGPORT: int = int(os.getenv("SUPABASE_PORT") or os.getenv("PGPORT", "5432"))
        self.PGUSER: str = os.getenv("SUPABASE_USER") or os.getenv("PGUSER", "postgres")
        self.PGPASSWORD: str = os.getenv("SUPABASE_PASSWORD") or os.getenv("PGPASSWORD", "")
        self.PGDATABASE: str = os.getenv("SUPABASE_DATABASE") or os.getenv("PGDATABASE", "postgres")
        
        print(f"  Result PGHOST: {self.PGHOST}")
        print(f"  Result PGDATABASE: {self.PGDATABASE}")
        
        # Supabase settings
        self.SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
        self.SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
        self.SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
        
        # Neo4j settings
        self.NEO4J_URI: str = os.getenv("NEO4J_URI", "")
        self.NEO4J_USERNAME: str = os.getenv("NEO4J_USERNAME", "neo4j")
        self.NEO4J_PASSWORD: str = os.getenv("NEO4J_PASSWORD", "")
        self.NEO4J_DATABASE: str = os.getenv("NEO4J_DATABASE", "neo4j")
        
        # LLM settings
        self.OPENAI_API_KEY: Optional[str] = os.getenv("AI_INTEGRATIONS_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
        self.OPENAI_BASE_URL: Optional[str] = os.getenv("AI_INTEGRATIONS_OPENAI_BASE_URL") or os.getenv("OPENAI_BASE_URL")
        self.LLM_PROVIDER: str = os.getenv("LLM_PROVIDER", "replit")
        self.EMBEDDING_MODEL: str = "text-embedding-3-small"

# Recreate settings to pick up latest environment variables
settings = Settings()
