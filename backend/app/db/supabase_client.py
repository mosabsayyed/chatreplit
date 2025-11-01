from supabase import create_client, Client
from typing import List, Dict, Any, Optional
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class SupabaseClient:
    def __init__(self):
        self.client: Optional[Client] = None
    
    async def connect(self):
        """Initialize Supabase client using REST API"""
        if not self.client:
            self.client = create_client(
                settings.SUPABASE_URL,
                settings.SUPABASE_SERVICE_ROLE_KEY
            )
            logger.info(f"✅ Connected to Supabase at {settings.SUPABASE_URL}")
    
    async def disconnect(self):
        """Supabase client doesn't need explicit disconnection"""
        self.client = None
    
    async def execute_query(self, query: str, params: List[Any] = None) -> List[Dict[str, Any]]:
        """Execute a SELECT query using RPC or direct table access"""
        if not self.client:
            await self.connect()
        
        # For raw SQL queries, we'll use RPC functions
        # This is a simplified approach - in production you'd want to use table methods
        raise NotImplementedError("Use table-based methods instead of raw SQL with REST API")
    
    async def execute_mutation(self, query: str, params: List[Any] = None) -> str:
        """Execute INSERT/UPDATE/DELETE using RPC or direct table access"""
        if not self.client:
            await self.connect()
        
        raise NotImplementedError("Use table-based methods instead of raw SQL with REST API")
    
    # Table-based methods for CRUD operations
    async def table_select(self, table: str, columns: str = "*", filters: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """Select data from a table"""
        if not self.client:
            await self.connect()
        
        query = self.client.table(table).select(columns)
        
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        
        response = query.execute()
        return response.data
    
    async def table_insert(self, table: str, data: Dict[str, Any] | List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Insert data into a table"""
        if not self.client:
            await self.connect()
        
        response = self.client.table(table).insert(data).execute()
        return response.data
    
    async def table_update(self, table: str, data: Dict[str, Any], filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Update data in a table"""
        if not self.client:
            await self.connect()
        
        query = self.client.table(table).update(data)
        
        for key, value in filters.items():
            query = query.eq(key, value)
        
        response = query.execute()
        return response.data
    
    async def table_delete(self, table: str, filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Delete data from a table"""
        if not self.client:
            await self.connect()
        
        query = self.client.table(table).delete()
        
        for key, value in filters.items():
            query = query.eq(key, value)
        
        response = query.execute()
        return response.data
    
    async def rpc(self, function_name: str, params: Dict[str, Any] = None) -> Any:
        """Call a Supabase RPC function"""
        if not self.client:
            await self.connect()
        
        response = self.client.rpc(function_name, params or {}).execute()
        return response.data

supabase_client = SupabaseClient()
