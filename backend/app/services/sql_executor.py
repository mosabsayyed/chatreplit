"""
SQL Executor Service
Validates and executes SQL queries with composite key enforcement
"""
import psycopg2
import psycopg2.extras
from typing import Dict, Any, List, Optional
from .composite_key_validator import CompositeKeyValidator
from app.config.schema_loader import SchemaLoader
import os

class SQLExecutorService:
    """Service to execute validated SQL queries"""
    
    def __init__(self):
        self.schema_loader = SchemaLoader()
        self.validator = None
    
    def get_db_connection(self):
        """Get database connection"""
        return psycopg2.connect(os.environ.get("DATABASE_URL"))
    
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
        # Wrap SQL in a simple dict format expected by validator
        sql_dict = {"sql": sql}
        return self.validator.validate_query(sql_dict)
    
    def execute_query(
        self,
        sql: str,
        validate: bool = True,
        max_rows: int = 1000
    ) -> Dict[str, Any]:
        """
        Execute a SQL query with validation and error handling
        
        Args:
            sql: SQL query to execute
            validate: Whether to validate composite keys first
            max_rows: Maximum rows to return
            
        Returns:
            Dict with success, data, error, validation_result
        """
        result = {
            "success": False,
            "data": None,
            "row_count": 0,
            "error": None,
            "validation_result": None,
            "sql": sql
        }
        
        # Validate SQL if requested
        if validate:
            validation = self.validate_sql(sql)
            result["validation_result"] = validation
            
            if not validation["is_valid"]:
                result["error"] = f"SQL validation failed: {'; '.join(validation['errors'])}"
                return result
        
        # Execute query
        conn = self.get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        try:
            cursor.execute(sql)
            
            # Fetch results
            rows = cursor.fetchmany(max_rows)
            result["data"] = [dict(row) for row in rows]
            result["row_count"] = len(rows)
            result["success"] = True
            
            return result
            
        except psycopg2.Error as e:
            result["error"] = f"Database error: {str(e)}"
            return result
        except Exception as e:
            result["error"] = f"Execution error: {str(e)}"
            return result
        finally:
            cursor.close()
            conn.close()
    
    def execute_simple_filter_query(
        self,
        table_name: str,
        filters: Dict[str, Any],
        columns: Optional[List[str]] = None,
        max_rows: int = 1000
    ) -> Dict[str, Any]:
        """
        Execute a simple SELECT query with WHERE filters
        Builds SQL deterministically for general queries
        
        Args:
            table_name: Table to query
            filters: Dict of column: value filters
            columns: Optional list of columns to select
            max_rows: Maximum rows to return
            
        Returns:
            Query execution result
        """
        # Build SELECT clause
        if columns:
            select_clause = ", ".join(columns)
        else:
            select_clause = "*"
        
        # Build WHERE clause
        where_clauses = []
        params = []
        
        for column, value in filters.items():
            if value is not None:
                where_clauses.append(f"{column} = %s")
                params.append(value)
        
        sql = f"SELECT {select_clause} FROM {table_name}"
        
        if where_clauses:
            sql += " WHERE " + " AND ".join(where_clauses)
        
        # Add ORDER BY for consistent results
        sql += " ORDER BY id, year"
        
        # Add LIMIT
        sql += f" LIMIT {max_rows}"
        
        # Execute with parameters
        conn = self.get_db_connection()
        cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        
        result = {
            "success": False,
            "data": None,
            "row_count": 0,
            "error": None,
            "sql": cursor.mogrify(sql, params).decode() if params else sql
        }
        
        try:
            cursor.execute(sql, params)
            rows = cursor.fetchall()
            result["data"] = [dict(row) for row in rows]
            result["row_count"] = len(rows)
            result["success"] = True
            
            return result
            
        except psycopg2.Error as e:
            result["error"] = f"Database error: {str(e)}"
            return result
        except Exception as e:
            result["error"] = f"Execution error: {str(e)}"
            return result
        finally:
            cursor.close()
            conn.close()
    
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
