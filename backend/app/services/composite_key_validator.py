"""
Composite Key Validator for JOSOOR SQL Queries.
Validates SQL queries for composite key compliance.
Source: OPTIMIZATION_ANALYSIS.md lines 743-863
"""

from typing import Dict, List, Set


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
    
    def validate_query(self, sql_json: Dict) -> Dict:
        """
        Validate SQL query for composite key compliance.
        
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
        """Extract all JOIN clauses from SQL (enhanced to handle multi-line SQL)."""
        import re
        # Match JOIN ... ON ... but stop before WHERE/GROUP/ORDER/LIMIT/next JOIN
        # DOTALL flag allows . to match newlines for multi-line SQL
        pattern = r'(?:INNER\s+|LEFT\s+|RIGHT\s+|FULL\s+|CROSS\s+)?JOIN\s+\w+(?:\s+AS)?\s+\w+\s+ON\s+.+?(?=\s+(?:WHERE|GROUP\s+BY|ORDER\s+BY|LIMIT|INNER\s+JOIN|LEFT\s+JOIN|RIGHT\s+JOIN|FULL\s+JOIN|CROSS\s+JOIN|JOIN|;|$))'
        return re.findall(pattern, sql, re.IGNORECASE | re.DOTALL)
    
    def _has_year_in_join(self, join_clause: str) -> bool:
        """Check if JOIN clause includes year column."""
        return 'year' in join_clause.lower()
    
    def _extract_table_from_join(self, join_clause: str) -> str:
        """Extract table name from JOIN clause (handles LEFT/RIGHT/INNER/etc)."""
        import re
        match = re.search(r'(?:INNER\s+|LEFT\s+|RIGHT\s+|FULL\s+|CROSS\s+)?JOIN\s+(\w+)', join_clause, re.IGNORECASE)
        return match.group(1) if match else ""
    
    def _extract_where(self, sql: str) -> str:
        """Extract WHERE clause from SQL."""
        import re
        match = re.search(r'WHERE\s+(.+?)(?:GROUP BY|ORDER BY|LIMIT|;|$)', sql, re.IGNORECASE | re.DOTALL)
        return match.group(1) if match else ""
    
    def _extract_id_filters(self, where_clause: str) -> List[str]:
        """Extract ID filters from WHERE clause."""
        import re
        return re.findall(r"(\w+\.id\s*=\s*'[^']+')", where_clause, re.IGNORECASE)
    
    def _has_corresponding_year_filter(self, where_clause: str, id_filter: str) -> bool:
        """Check if WHERE clause has corresponding year filter for ID filter."""
        table_alias = id_filter.split('.')[0]
        return f"{table_alias}.year" in where_clause.lower()
    
    def _extract_referenced_tables(self, sql: str) -> Set[str]:
        """Extract all table names referenced in SQL (handles all JOIN types)."""
        import re
        # FROM clause
        from_tables = re.findall(r'FROM\s+(\w+)', sql, re.IGNORECASE)
        # JOIN clauses (all types)
        join_tables = re.findall(r'(?:INNER\s+|LEFT\s+|RIGHT\s+|FULL\s+|CROSS\s+)?JOIN\s+(\w+)', sql, re.IGNORECASE)
        return set(from_tables + join_tables)
    
    def _year_referenced_for_table(self, sql: str, table: str) -> bool:
        """Check if year column is referenced for a specific table (handles AS keyword)."""
        # Look for table.year or alias.year in SQL
        import re
        # Get table alias (handles both "table alias" and "table AS alias")
        alias_match = re.search(rf'{table}(?:\s+AS)?\s+(\w+)', sql, re.IGNORECASE)
        if alias_match:
            alias = alias_match.group(1)
            # Skip if alias is a SQL keyword
            sql_keywords = {'WHERE', 'JOIN', 'LEFT', 'RIGHT', 'INNER', 'OUTER', 'ON', 'AND', 'OR', 'GROUP', 'ORDER', 'LIMIT'}
            if alias.upper() not in sql_keywords:
                return bool(re.search(rf'{alias}\.year', sql, re.IGNORECASE))
        return bool(re.search(rf'{table}\.year', sql, re.IGNORECASE))
