"""
Data Sync Service
Synchronizes data from PostgreSQL (Supabase) to Neo4j graph database
"""
from typing import Dict, Any, List, Optional
from app.db.postgres_client import PostgresClient
from app.db.neo4j_client import neo4j_client
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class DataSyncService:
    """
    Service to sync PostgreSQL data to Neo4j
    
    Implements batch sync strategy for the dual database architecture
    """
    
    def __init__(self):
        self.pg_client = PostgresClient()
        self.neo4j_client = neo4j_client
    
    async def sync_all(self, year: Optional[int] = None) -> Dict[str, Any]:
        """
        Sync all entity tables and relationships to Neo4j
        
        Args:
            year: Optional year filter (defaults to current year)
            
        Returns:
            Sync statistics and results
        """
        if not self.neo4j_client.is_connected():
            if not self.neo4j_client.connect():
                return {
                    "success": False,
                    "error": "Cannot connect to Neo4j"
                }
        
        year = year or settings.CURRENT_YEAR
        
        results = {
            "success": True,
            "year": year,
            "entities_synced": {},
            "relationships_synced": {},
            "errors": []
        }
        
        try:
            logger.info(f"Starting data sync for year {year}")
            
            entity_results = await self._sync_entities(year)
            results["entities_synced"] = entity_results
            
            relationship_results = await self._sync_relationships(year)
            results["relationships_synced"] = relationship_results
            
            logger.info(f"Data sync completed for year {year}")
            
        except Exception as e:
            logger.error(f"Error in sync_all: {str(e)}")
            results["success"] = False
            results["errors"].append(str(e))
        
        return results
    
    async def _sync_entities(self, year: int) -> Dict[str, int]:
        """
        Sync entity tables to Neo4j nodes
        
        Returns count of synced nodes per entity type
        """
        entity_tables = [
            ("ent_projects", "Project"),
            ("ent_capabilities", "Capability"),
            ("ent_risks", "Risk"),
            ("ent_it_systems", "ITSystem"),
            ("ent_org_units", "OrgUnit"),
            ("ent_processes", "Process"),
            ("ent_vendors", "Vendor"),
            ("sec_objectives", "Objective"),
            ("sec_performance", "Performance")
        ]
        
        results = {}
        
        for table_name, node_label in entity_tables:
            try:
                count = await self._sync_entity_table(table_name, node_label, year)
                results[node_label] = count
                logger.info(f"Synced {count} {node_label} nodes")
            except Exception as e:
                logger.error(f"Error syncing {table_name}: {str(e)}")
                results[node_label] = 0
        
        return results
    
    async def _sync_entity_table(
        self,
        table_name: str,
        node_label: str,
        year: int
    ) -> int:
        """
        Sync a single entity table to Neo4j
        
        Returns number of nodes created/updated
        """
        query = f"SELECT * FROM {table_name} WHERE year = {year}"
        rows = await self.pg_client.execute_query(query)
        
        count = 0
        for row in rows:
            node_id = row.get('id')
            node_year = row.get('year')
            
            if not node_id or not node_year:
                continue
            
            properties = {
                "id": node_id,
                "year": node_year,
                "name": row.get('name', ''),
                "status": row.get('status', ''),
                "description": row.get('description', '')
            }
            
            properties = {k: v for k, v in properties.items() if v is not None}
            
            props_str = ", ".join([f"{k}: ${k}" for k in properties.keys()])
            
            cypher = f"""
            MERGE (n:{node_label} {{id: $id, year: $year}})
            SET n += {{{props_str}}}
            """
            
            result = self.neo4j_client.execute_write_query(cypher, properties)
            if result.get("success"):
                count += 1
        
        return count
    
    async def _sync_relationships(self, year: int) -> Dict[str, int]:
        """
        Sync join tables to Neo4j relationships
        
        Returns count of synced relationships per type
        """
        relationship_mappings = [
            {
                "table": "jt_project_capabilities",
                "from_label": "Project",
                "from_id": "project_id",
                "from_year": "project_year",
                "to_label": "Capability",
                "to_id": "capability_id",
                "to_year": "capability_year",
                "rel_type": "HAS_CAPABILITY"
            },
            {
                "table": "jt_project_it_systems",
                "from_label": "Project",
                "from_id": "project_id",
                "from_year": "project_year",
                "to_label": "ITSystem",
                "to_id": "it_system_id",
                "to_year": "it_system_year",
                "rel_type": "USES_IT_SYSTEM"
            },
            {
                "table": "jt_it_system_risks",
                "from_label": "ITSystem",
                "from_id": "it_system_id",
                "from_year": "it_system_year",
                "to_label": "Risk",
                "to_id": "risk_id",
                "to_year": "risk_year",
                "rel_type": "HAS_RISK"
            },
            {
                "table": "jt_capability_processes",
                "from_label": "Capability",
                "from_id": "capability_id",
                "from_year": "capability_year",
                "to_label": "Process",
                "to_id": "process_id",
                "to_year": "process_year",
                "rel_type": "SUPPORTED_BY_PROCESS"
            },
            {
                "table": "jt_objective_projects",
                "from_label": "Objective",
                "from_id": "objective_id",
                "from_year": "objective_year",
                "to_label": "Project",
                "to_id": "project_id",
                "to_year": "project_year",
                "rel_type": "ACHIEVED_BY_PROJECT"
            }
        ]
        
        results = {}
        
        for mapping in relationship_mappings:
            try:
                count = await self._sync_relationship_table(mapping, year)
                results[mapping["rel_type"]] = count
                logger.info(f"Synced {count} {mapping['rel_type']} relationships")
            except Exception as e:
                logger.error(f"Error syncing {mapping['table']}: {str(e)}")
                results[mapping["rel_type"]] = 0
        
        return results
    
    async def _sync_relationship_table(
        self,
        mapping: Dict[str, str],
        year: int
    ) -> int:
        """
        Sync a single join table to Neo4j relationships
        
        Returns number of relationships created
        """
        query = f"""
        SELECT * FROM {mapping['table']} 
        WHERE {mapping['from_year']} = {year}
        """
        
        rows = await self.pg_client.execute_query(query)
        
        count = 0
        for row in rows:
            from_id = row.get(mapping['from_id'])
            from_year = row.get(mapping['from_year'])
            to_id = row.get(mapping['to_id'])
            to_year = row.get(mapping['to_year'])
            
            if not all([from_id, from_year, to_id, to_year]):
                continue
            
            cypher = f"""
            MATCH (from:{mapping['from_label']} {{id: $from_id, year: $from_year}})
            MATCH (to:{mapping['to_label']} {{id: $to_id, year: $to_year}})
            MERGE (from)-[r:{mapping['rel_type']} {{year: $from_year}}]->(to)
            """
            
            parameters = {
                "from_id": from_id,
                "from_year": from_year,
                "to_id": to_id,
                "to_year": to_year
            }
            
            result = self.neo4j_client.execute_write_query(cypher, parameters)
            if result.get("success"):
                count += 1
        
        return count
    
    async def clear_neo4j(self) -> Dict[str, Any]:
        """
        Clear all data from Neo4j (USE WITH CAUTION)
        
        Returns:
            Clear operation result
        """
        logger.warning("Clearing Neo4j database!")
        
        if not self.neo4j_client.is_connected():
            if not self.neo4j_client.connect():
                return {
                    "success": False,
                    "error": "Cannot connect to Neo4j"
                }
        
        result = self.neo4j_client.clear_database()
        return result
    
    async def sync_incremental(
        self,
        entity_type: str,
        entity_id: str,
        year: int
    ) -> Dict[str, Any]:
        """
        Sync a single entity and its relationships
        
        Args:
            entity_type: Type of entity (project, capability, etc.)
            entity_id: Entity ID
            year: Entity year
            
        Returns:
            Sync result
        """
        logger.info(f"Incremental sync: {entity_type} {entity_id} ({year})")
        
        table_mapping = {
            "project": ("ent_projects", "Project"),
            "capability": ("ent_capabilities", "Capability"),
            "risk": ("ent_risks", "Risk"),
            "it_system": ("ent_it_systems", "ITSystem"),
            "objective": ("sec_objectives", "Objective")
        }
        
        if entity_type not in table_mapping:
            return {
                "success": False,
                "error": f"Unknown entity type: {entity_type}"
            }
        
        table_name, node_label = table_mapping[entity_type]
        
        try:
            query = f"SELECT * FROM {table_name} WHERE id = '{entity_id}' AND year = {year}"
            rows = await self.pg_client.execute_query(query)
            
            if not rows:
                return {
                    "success": False,
                    "error": f"Entity not found: {entity_id}"
                }
            
            row = rows[0]
            
            properties = {
                "id": row.get('id'),
                "year": row.get('year'),
                "name": row.get('name', ''),
                "status": row.get('status', ''),
                "description": row.get('description', '')
            }
            
            properties = {k: v for k, v in properties.items() if v is not None}
            props_str = ", ".join([f"{k}: ${k}" for k in properties.keys()])
            
            cypher = f"""
            MERGE (n:{node_label} {{id: $id, year: $year}})
            SET n += {{{props_str}}}
            """
            
            result = self.neo4j_client.execute_write_query(cypher, properties)
            
            return {
                "success": result.get("success", False),
                "entity": f"{entity_type} {entity_id} ({year})",
                "result": result
            }
            
        except Exception as e:
            logger.error(f"Error in incremental sync: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }


data_sync_service = DataSyncService()
