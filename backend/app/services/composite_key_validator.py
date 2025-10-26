"""
JOSOOR Optimization: Composite Key SQL Validator
Version: 1.0
Purpose: Validate SQL queries for composite key compliance

This validator ensures all generated SQL queries properly use composite keys
(id, year) when joining or filtering tables in the JOSOOR database.
"""

from typing import Dict, List, Set
import re


class CompositeKeyValidator:
    """
    Validates SQL queries for composite key compliance.
    """
    
    def __init__(self, schema: Dict):
        self.schema = schema
        self.composite_key_tables = self._identify_composite_key_tables()
    
    def _identify_composite_key_tables(self) -> Set[str]:
        """Identify all tables using composite keys."""
        composite_tables = set()
        for table_name, table_def in self.schema.items():
            pk = table_def.get("primary_key", [])
            if isinstance(pk, list) and "year" in pk:
                composite_tables.add(table_name)
        return composite_tables
    
    def validate_query(self, sql_json: Dict, expected_hops: int = None) -> Dict:
        """
        Validate SQL query for composite key compliance.
        
        Args:
            sql_json: Dict with "sql" key containing the query
            expected_hops: Optional expected hop count from chain selection
        
        Returns:
            {
                "valid": bool,
                "errors": List[str],
                "warnings": List[str]
            }
        """
        sql = sql_json.get("sql", "")
        errors = []
        warnings = []
        
        # Check 0: JOIN count matches expected hops (if provided)
        if expected_hops is not None:
            joins = self._extract_joins(sql)
            expected_join_count = expected_hops + 1  # N hops = N+1 JOINs
            actual_join_count = len(joins)
            if actual_join_count != expected_join_count:
                errors.append(
                    f"JOIN count mismatch: {expected_hops}-hop query requires {expected_join_count} JOINs, "
                    f"but query has {actual_join_count} JOINs. Missing intermediate tables."
                )
        
        # Check 1: JOIN clauses include year
        joins = self._extract_joins(sql)
        for join in joins:
            if not self._has_year_in_join(join):
                table = self._extract_table_from_join(join)
                if table in self.composite_key_tables:
                    errors.append(
                        f"JOIN on table '{table}' missing year column. "
                        f"Required: ON table1.id = table2.id AND table1.year = table2.year"
                    )
        
        # Check 2: WHERE clauses include year when filtering by ID
        where_clause = self._extract_where(sql)
        if where_clause:
            id_filters = self._extract_id_filters(where_clause)
            for id_filter in id_filters:
                if not self._has_corresponding_year_filter(where_clause, id_filter):
                    warnings.append(
                        f"WHERE clause filters by ID but missing year filter. "
                        f"Recommend adding: AND table.year = value"
                    )
        
        # Check 3: All composite key tables referenced have year in SELECT or JOIN
        referenced_tables = self._extract_referenced_tables(sql)
        for table in referenced_tables:
            if table in self.composite_key_tables:
                if not self._year_referenced_for_table(sql, table):
                    errors.append(
                        f"Table '{table}' uses composite key but year column not referenced"
                    )
        
        return {
            "valid": len(errors) == 0,
            "errors": errors,
            "warnings": warnings
        }
    
    def _extract_joins(self, sql: str) -> List[str]:
        """Extract all JOIN clauses from SQL."""
        pattern = r'JOIN\s+\w+\s+\w+\s+ON\s+[^;]+'
        return re.findall(pattern, sql, re.IGNORECASE)
    
    def _has_year_in_join(self, join_clause: str) -> bool:
        """Check if JOIN clause includes year column."""
        return 'year' in join_clause.lower()
    
    def _extract_table_from_join(self, join_clause: str) -> str:
        """Extract table name from JOIN clause."""
        match = re.search(r'JOIN\s+(\w+)', join_clause, re.IGNORECASE)
        return match.group(1) if match else ""
    
    def _extract_where(self, sql: str) -> str:
        """Extract WHERE clause from SQL."""
        match = re.search(r'WHERE\s+(.+?)(?:GROUP BY|ORDER BY|LIMIT|;|$)', sql, re.IGNORECASE | re.DOTALL)
        return match.group(1) if match else ""
    
    def _extract_id_filters(self, where_clause: str) -> List[str]:
        """Extract ID filters from WHERE clause."""
        return re.findall(r"(\w+\.id\s*=\s*'[^']+')", where_clause, re.IGNORECASE)
    
    def _has_corresponding_year_filter(self, where_clause: str, id_filter: str) -> bool:
        """Check if WHERE clause has corresponding year filter for ID filter."""
        table_alias = id_filter.split('.')[0]
        return f"{table_alias}.year" in where_clause.lower()
    
    def _extract_referenced_tables(self, sql: str) -> Set[str]:
        """Extract all table names referenced in SQL."""
        # FROM clause
        from_tables = re.findall(r'FROM\s+(\w+)', sql, re.IGNORECASE)
        # JOIN clauses
        join_tables = re.findall(r'JOIN\s+(\w+)', sql, re.IGNORECASE)
        return set(from_tables + join_tables)
    
    def _year_referenced_for_table(self, sql: str, table: str) -> bool:
        """Check if year column is referenced for a specific table."""
        # Look for table.year or alias.year in SQL
        # Get table alias
        alias_match = re.search(rf'{table}\s+(\w+)', sql, re.IGNORECASE)
        if alias_match:
            alias = alias_match.group(1)
            return bool(re.search(rf'{alias}\.year', sql, re.IGNORECASE))
        return bool(re.search(rf'{table}\.year', sql, re.IGNORECASE))
