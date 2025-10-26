"""
JOSOOR Optimization: Schema Metadata Loader
Version: 1.0
Purpose: Introspect PostgreSQL database schema for composite key validation

This service queries information_schema to build an authoritative schema Dict
that reflects the actual deployed database structure, supporting composite key
validation without maintaining brittle static files.
"""

from typing import Dict, List, Optional, Set
from app.db.postgres_client import postgres_client
import asyncio


class SchemaMetadataLoader:
    """
    Loads database schema metadata via information_schema introspection.
    Caches results to avoid repeated database queries.
    """
    
    def __init__(self):
        self._schema_cache: Optional[Dict] = None
        self._cache_lock = asyncio.Lock()
    
    async def get_schema(self, force_refresh: bool = False) -> Dict:
        """
        Get schema metadata dict for all tables.
        Returns cached version unless force_refresh=True.
        
        Returns:
            {
                "table_name": {
                    "primary_key": ["col1", "col2"],
                    "columns": ["col1", "col2", "col3", ...]
                },
                ...
            }
        """
        async with self._cache_lock:
            if self._schema_cache is None or force_refresh:
                self._schema_cache = await self._load_schema()
            return self._schema_cache
    
    async def _load_schema(self) -> Dict:
        """
        Introspect database schema from information_schema.
        """
        schema = {}
        
        # Get all table names from information_schema
        tables_query = """
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """
        tables = await postgres_client.execute_query(tables_query, [])
        
        for table_row in tables:
            table_name = table_row['table_name']
            
            # Get primary key columns for this table
            pk_query = """
                SELECT a.attname AS column_name
                FROM pg_index i
                JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                WHERE i.indrelid = $1::regclass
                AND i.indisprimary
                ORDER BY array_position(i.indkey, a.attnum)
            """
            pk_columns = await postgres_client.execute_query(pk_query, [table_name])
            primary_key = [row['column_name'] for row in pk_columns]
            
            # Get all columns for this table
            columns_query = """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = 'public'
                AND table_name = $1
                ORDER BY ordinal_position
            """
            columns = await postgres_client.execute_query(columns_query, [table_name])
            column_list = [row['column_name'] for row in columns]
            
            # Build schema entry
            schema[table_name] = {
                "primary_key": primary_key,
                "columns": column_list
            }
        
        return schema
    
    def clear_cache(self):
        """Clear the schema cache (useful for testing or migrations)."""
        self._schema_cache = None


# Singleton instance
_schema_loader: Optional[SchemaMetadataLoader] = None


def get_schema_loader() -> SchemaMetadataLoader:
    """Get the singleton SchemaMetadataLoader instance."""
    global _schema_loader
    if _schema_loader is None:
        _schema_loader = SchemaMetadataLoader()
    return _schema_loader
