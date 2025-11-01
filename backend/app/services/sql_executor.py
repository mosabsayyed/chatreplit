"""
SQL Executor Service
Validates and executes SQL queries with composite key enforcement via Supabase REST API
"""
from typing import Dict, Any, List, Optional
from .composite_key_validator import CompositeKeyValidator
from .schema_loader import SchemaLoader
from app.db.supabase_client import supabase_client
import asyncio

class SQLExecutorService:
    """Service to execute validated SQL queries via Supabase REST API"""
    
    def __init__(self):
        self.schema_loader = SchemaLoader()
        self.validator = None
        self.supabase = supabase_client
    
    def _ensure_validator(self):
        """Lazy load the composite key validator"""
        if self.validator is None:
            schema = self.schema_loader.load_schema()
            self.validator = CompositeKeyValidator(schema)
    
    def validate_sql(self, sql: str) -> Dict[str, Any]:
        """
        Validate SQL for composite key compliance
        
        Args:
            sql: SQL query to validate
            
        Returns:
            Dict with is_valid, errors, warnings
        """
        self._ensure_validator()
        sql_dict = {"sql": sql}
        return self.validator.validate_query(sql_dict)
    
    def execute_query(
        self,
        sql: str,
        validate: bool = True,
        max_rows: int = 1000
    ) -> Dict[str, Any]:
        """
        Execute a SQL query with validation and error handling via Supabase REST API
        
        Args:
            sql: SQL query to execute
            validate: Whether to validate composite keys first
            max_rows: Maximum rows to return
            
        Returns:
            Dict with success, data, error, validation_result
        """
        loop = None
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        return loop.run_until_complete(self._execute_query_async(sql, validate, max_rows))
    
    async def _execute_query_async(
        self,
        sql: str,
        validate: bool = True,
        max_rows: int = 1000
    ) -> Dict[str, Any]:
        """Async implementation of execute_query"""
        result = {
            "success": False,
            "data": None,
            "row_count": 0,
            "error": None,
            "validation_result": None,
            "sql": sql
        }
        
        if validate:
            validation = self.validate_sql(sql)
            result["validation_result"] = validation
            
            if not validation["is_valid"]:
                result["error"] = f"SQL validation failed: {'; '.join(validation['errors'])}"
                return result
        
        try:
            sql_with_limit = sql.strip()
            if not sql_with_limit.upper().endswith(')') and 'LIMIT' not in sql_with_limit.upper():
                sql_with_limit += f" LIMIT {max_rows}"
            
            rows = await self.supabase.execute_raw_sql(sql_with_limit)
            
            result["data"] = rows if isinstance(rows, list) else []
            result["row_count"] = len(result["data"]) if result["data"] else 0
            result["success"] = True
            
            return result
            
        except Exception as e:
            result["error"] = f"Execution error: {str(e)}"
            return result
    
    def execute_simple_filter_query(
        self,
        table_name: str,
        filters: Dict[str, Any],
        columns: Optional[List[str]] = None,
        max_rows: int = 1000
    ) -> Dict[str, Any]:
        """
        Execute a simple SELECT query with WHERE filters via Supabase REST API
        
        Args:
            table_name: Table to query
            filters: Dict of column: value filters
            columns: Optional list of columns to select
            max_rows: Maximum rows to return
            
        Returns:
            Query execution result
        """
        loop = None
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        return loop.run_until_complete(
            self._execute_simple_filter_query_async(table_name, filters, columns, max_rows)
        )
    
    async def _execute_simple_filter_query_async(
        self,
        table_name: str,
        filters: Dict[str, Any],
        columns: Optional[List[str]] = None,
        max_rows: int = 1000
    ) -> Dict[str, Any]:
        """Async implementation of execute_simple_filter_query"""
        result = {
            "success": False,
            "data": None,
            "row_count": 0,
            "error": None
        }
        
        try:
            column_str = "*" if not columns else ",".join(columns)
            rows = await self.supabase.table_select(table_name, column_str, filters)
            
            result["data"] = rows[:max_rows] if rows else []
            result["row_count"] = len(result["data"])
            result["success"] = True
            
            return result
        except Exception as e:
            result["error"] = f"Execution error: {str(e)}"
            return result
    
    def get_table_sample(
        self,
        table_name: str,
        limit: int = 5
    ) -> Dict[str, Any]:
        """
        Get a small sample from a table for context
        
        Args:
            table_name: Table to sample
            limit: Number of rows
            
        Returns:
            Query result with sample rows
        """
        sql = f"SELECT * FROM {table_name} ORDER BY year DESC, id LIMIT {limit}"
        return self.execute_query(sql, validate=False, max_rows=limit)


# Singleton instance
_sql_executor_service = None

def get_sql_executor_service() -> SQLExecutorService:
    """Get or create singleton SQL executor service"""
    global _sql_executor_service
    if _sql_executor_service is None:
        _sql_executor_service = SQLExecutorService()
    return _sql_executor_service
