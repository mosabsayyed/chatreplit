"""
Schema Loader for JOSOOR - Transforms schema_definition.json into validator format.
Reads user-provided schema and transforms column-based format into table-based Dict.
"""

import json
from pathlib import Path
from typing import Dict, List, Set, Optional
from collections import defaultdict


class SchemaLoader:
    """Loads and transforms schema from schema_definition.json"""
    
    def __init__(self, schema_path: Optional[str] = None):
        if schema_path is None:
            # Use absolute path relative to this module
            schema_path = Path(__file__).parent.parent / "config" / "schema_definition.json"
        self.schema_path = Path(schema_path)
        self._cached_schema: Optional[Dict] = None
    
    def load_schema(self) -> Dict:
        """
        Load schema from JSON file and transform to validator format.
        
        Returns:
            Dict in format:
            {
                "table_name": {
                    "primary_key": ["id", "year"],
                    "columns": [...]
                }
            }
        """
        if self._cached_schema is not None:
            return self._cached_schema
        
        with open(self.schema_path, 'r') as f:
            column_records = json.load(f)
        
        schema = self._transform_to_table_format(column_records)
        self._cached_schema = schema
        return schema
    
    def _transform_to_table_format(self, column_records: List[Dict]) -> Dict:
        """Transform column-based records into table-based schema"""
        tables = defaultdict(lambda: {"columns": [], "primary_key": []})
        
        for record in column_records:
            table_name = record.get("table_name")
            column_name = record.get("column_name")
            
            if not table_name or not column_name:
                continue
            
            if column_name not in [col["name"] for col in tables[table_name]["columns"]]:
                tables[table_name]["columns"].append({
                    "name": column_name,
                    "data_type": record.get("data_type"),
                    "is_nullable": record.get("is_nullable") == "YES"
                })
        
        for table_name in tables:
            tables[table_name]["primary_key"] = self._detect_primary_key(table_name)
        
        return dict(tables)
    
    def _detect_primary_key(self, table_name: str) -> List[str]:
        """
        Detect primary key for a table based on naming convention.
        
        JOSOOR convention:
        - Entity/Sector tables (ent_*, sec_*, str_*, tac_*): composite (id, year)
        - Join tables (jt_*): composite foreign keys
        """
        if table_name.startswith(('ent_', 'sec_', 'str_', 'tac_', 'jt_')):
            return ["id", "year"]
        
        return ["id"]


def get_schema_loader() -> SchemaLoader:
    """Get singleton schema loader instance"""
    return SchemaLoader()
