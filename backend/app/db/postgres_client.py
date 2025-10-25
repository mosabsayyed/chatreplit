import asyncpg
from typing import List, Dict, Any, Optional
from app.config import settings

class PostgresClient:
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None
    
    async def connect(self):
        """Create database connection pool"""
        if not self.pool:
            self.pool = await asyncpg.create_pool(
                host=settings.PGHOST,
                port=settings.PGPORT,
                user=settings.PGUSER,
                password=settings.PGPASSWORD,
                database=settings.PGDATABASE,
                min_size=5,
                max_size=20
            )
    
    async def disconnect(self):
        """Close database connection pool"""
        if self.pool:
            await self.pool.close()
            self.pool = None
    
    async def execute_query(self, query: str, params: List[Any] = None) -> List[Dict[str, Any]]:
        """Execute a SELECT query and return results as list of dicts"""
        if not self.pool:
            await self.connect()
        
        async with self.pool.acquire() as conn:
            if params:
                rows = await conn.fetch(query, *params)
            else:
                rows = await conn.fetch(query)
            
            return [dict(row) for row in rows]
    
    async def execute_mutation(self, query: str, params: List[Any] = None) -> str:
        """Execute INSERT/UPDATE/DELETE and return status"""
        if not self.pool:
            await self.connect()
        
        async with self.pool.acquire() as conn:
            if params:
                result = await conn.execute(query, *params)
            else:
                result = await conn.execute(query)
            return result
    
    async def execute_many(self, query: str, params_list: List[List[Any]]) -> int:
        """Execute many statements in batch"""
        if not self.pool:
            await self.connect()
        
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                result = await conn.executemany(query, params_list)
                return len(params_list)

# Global instance
postgres_client = PostgresClient()
