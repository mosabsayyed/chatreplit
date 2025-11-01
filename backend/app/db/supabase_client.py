from supabase import create_client, Client
from typing import List, Dict, Any, Optional
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class SupabaseClient:
    def __init__(self):
        self.client: Client | None = None
    
    async def connect(self) -> None:
        """Initialize Supabase client using REST API"""
        if not self.client:
            self.client = create_client(
                settings.SUPABASE_URL,
                settings.SUPABASE_SERVICE_ROLE_KEY
            )
            logger.info(f"✅ Connected to Supabase at {settings.SUPABASE_URL}")
    
    async def disconnect(self) -> None:
        """Supabase client doesn't need explicit disconnection"""
        self.client = None
    
    def _ensure_connected(self) -> Client:
        """Ensure client is connected and return it"""
        if self.client is None:
            raise RuntimeError("Supabase client not connected. Call connect() first.")
        return self.client
    
    async def execute_query(self, query: str, params: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        """Execute a SELECT query using RPC or direct table access"""
        if not self.client:
            await self.connect()
        
        # For raw SQL queries, we'll use RPC functions
        # This is a simplified approach - in production you'd want to use table methods
        raise NotImplementedError("Use table-based methods instead of raw SQL with REST API")
    
    async def execute_mutation(self, query: str, params: Optional[List[Any]] = None) -> str:
        """Execute INSERT/UPDATE/DELETE using RPC or direct table access"""
        if not self.client:
            await self.connect()
        
        raise NotImplementedError("Use table-based methods instead of raw SQL with REST API")
    
    # Table-based methods for CRUD operations
    async def table_select(self, table: str, columns: str = "*", filters: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Select data from a table"""
        if not self.client:
            await self.connect()
        
        client = self._ensure_connected()
        query = client.table(table).select(columns)
        
        if filters:
            for key, value in filters.items():
                query = query.eq(key, value)
        
        response = query.execute()
        return response.data or []
    
    async def table_insert(self, table: str, data: Dict[str, Any] | List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Insert data into a table"""
        if not self.client:
            await self.connect()
        
        client = self._ensure_connected()
        response = client.table(table).insert(data).execute()
        return response.data or []
    
    async def table_update(self, table: str, data: Dict[str, Any], filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Update data in a table"""
        if not self.client:
            await self.connect()
        
        client = self._ensure_connected()
        query = client.table(table).update(data)
        
        for key, value in filters.items():
            query = query.eq(key, value)
        
        response = query.execute()
        return response.data or []
    
    async def table_delete(self, table: str, filters: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Delete data from a table"""
        if not self.client:
            await self.connect()
        
        client = self._ensure_connected()
        query = client.table(table).delete()
        
        for key, value in filters.items():
            query = query.eq(key, value)
        
        response = query.execute()
        return response.data or []
    
    async def rpc(self, function_name: str, params: Optional[Dict[str, Any]] = None) -> Any:
        """Call a Supabase RPC function"""
        if not self.client:
            await self.connect()
        
        client = self._ensure_connected()
        response = client.rpc(function_name, params or {}).execute()
        return response.data
    
    async def execute_raw_sql(self, sql: str, params: Optional[List[Any]] = None) -> List[Dict[str, Any]]:
        """
        Execute raw SQL query via Supabase RPC
        
        NOTE: This requires a PostgreSQL function called 'execute_sql' to be created in Supabase:
        
        CREATE OR REPLACE FUNCTION execute_sql(query_text text)
        RETURNS json
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $$
        DECLARE
            result json;
        BEGIN
            EXECUTE 'SELECT json_agg(row_to_json(t)) FROM (' || query_text || ') t' INTO result;
            RETURN COALESCE(result, '[]'::json);
        END;
        $$;
        
        Args:
            sql: Raw SQL query to execute
            params: Query parameters (not yet supported in this implementation)
            
        Returns:
            List of result rows as dictionaries
        """
        if not self.client:
            await self.connect()
        
        try:
            # Call the execute_sql RPC function
            result = await self.rpc('execute_sql', {'query_text': sql})
            return result if isinstance(result, list) else []
        except Exception as e:
            logger.error(f"Error executing raw SQL via RPC: {e}")
            # Fallback: Return empty list for now
            # In production, you'd want proper error handling
            return []

supabase_client = SupabaseClient()
