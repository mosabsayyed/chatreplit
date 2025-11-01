"""
Neo4j Service Layer
Provides graph-based operations for the dual database architecture
"""
from typing import List, Dict, Any, Optional
from app.db.neo4j_client import neo4j_client
import logging

logger = logging.getLogger(__name__)

class Neo4jService:
    """
    Neo4j graph database service for relationship traversal and analytics
    """
    
    def __init__(self):
        self.client = neo4j_client
    
    def is_available(self) -> bool:
        """Check if Neo4j is available"""
        return self.client.is_connected() or self.client.connect()
    
    def graph_walk(
        self,
        start_node: Dict[str, Any],
        relationship_types: List[str],
        max_depth: int = 5
    ) -> Dict[str, Any]:
        """
        Walk graph relationships from start node
        
        Args:
            start_node: Starting node with id, year, type
                       e.g., {id: 'PRJ001', year: 2024, type: 'Project'}
            relationship_types: List of relationship types to follow
                              e.g., ['HAS_CAPABILITY', 'SUPPORTED_BY_IT_SYSTEM']
            max_depth: Maximum number of hops (default: 5)
            
        Returns:
            {
                "paths": [
                    {
                        "nodes": [...],
                        "relationships": [...],
                        "length": 4
                    }
                ],
                "summary": {
                    "total_paths": 3,
                    "max_depth_reached": 4,
                    "unique_end_nodes": 2
                },
                "success": True
            }
        """
        if not self.is_available():
            logger.warning("Neo4j not available for graph_walk")
            return {
                "success": False,
                "error": "Neo4j not available",
                "paths": [],
                "summary": {"total_paths": 0, "max_depth_reached": 0, "unique_end_nodes": 0}
            }
        
        try:
            node_type = start_node.get('type', 'Entity')
            node_id = start_node.get('id')
            node_year = start_node.get('year')
            
            if not node_id or not node_year:
                return {
                    "success": False,
                    "error": "start_node must have 'id' and 'year' properties",
                    "paths": [],
                    "summary": {"total_paths": 0, "max_depth_reached": 0, "unique_end_nodes": 0}
                }
            
            query = f"""
            MATCH path = (start:{node_type} {{id: $start_id, year: $start_year}})
            -[r*1..{max_depth}]->(end)
            WHERE ALL(rel in r WHERE type(rel) IN $rel_types AND rel.year = $start_year)
            RETURN path
            LIMIT 100
            """
            
            parameters = {
                "start_id": node_id,
                "start_year": node_year,
                "rel_types": relationship_types
            }
            
            results = self.client.execute_query(query, parameters)
            
            paths = []
            for record in results:
                path = record.get('path')
                if path:
                    try:
                        nodes = [dict(node) for node in path.nodes]
                        relationships = [dict(rel) for rel in path.relationships]
                        paths.append({
                            "nodes": nodes,
                            "relationships": relationships,
                            "length": len(relationships)
                        })
                    except Exception as e:
                        logger.error(f"Error processing path: {e}")
                        continue
            
            unique_end_nodes = len(set(p['nodes'][-1]['id'] for p in paths if p.get('nodes'))) if paths else 0
            max_depth_reached = max([p['length'] for p in paths], default=0)
            
            return {
                "success": True,
                "paths": paths,
                "summary": {
                    "total_paths": len(paths),
                    "max_depth_reached": max_depth_reached,
                    "unique_end_nodes": unique_end_nodes
                }
            }
            
        except Exception as e:
            logger.error(f"Error in graph_walk: {str(e)}")
            return {
                "success": False,
                "error": str(e),
                "paths": [],
                "summary": {"total_paths": 0, "max_depth_reached": 0, "unique_end_nodes": 0}
            }
    
    def graph_search(
        self,
        pattern: str,
        filters: Optional[Dict[str, Any]] = None,
        limit: int = 100
    ) -> Dict[str, Any]:
        """
        Search for matching patterns in graph
        
        Args:
            pattern: Cypher pattern like "(p:Project)-[:HAS_RISK]->(r:Risk)"
            filters: Property filters e.g., {year: 2024, status: 'active'}
            limit: Maximum results to return
            
        Returns:
            {
                "matches": [
                    {
                        "nodes": {...},
                        "relationships": {...}
                    }
                ],
                "total_matches": 10,
                "success": True
            }
        """
        if not self.is_available():
            logger.warning("Neo4j not available for graph_search")
            return {
                "success": False,
                "error": "Neo4j not available",
                "matches": [],
                "total_matches": 0
            }
        
        try:
            where_clauses = []
            parameters = {"limit": limit}
            
            if filters:
                for i, (key, value) in enumerate(filters.items()):
                    param_name = f"filter_{i}"
                    where_clauses.append(f"p.{key} = ${param_name}")
                    parameters[param_name] = value
            
            where_str = " AND ".join(where_clauses) if where_clauses else "true"
            
            query = f"""
            MATCH {pattern}
            WHERE {where_str}
            RETURN *
            LIMIT $limit
            """
            
            results = self.client.execute_query(query, parameters)
            
            return {
                "success": True,
                "matches": results,
                "total_matches": len(results)
            }
            
        except Exception as e:
            logger.error(f"Error in graph_search: {str(e)}")
            return {
                "success": False,
                "error": str(e),
                "matches": [],
                "total_matches": 0
            }
    
    def get_node_degree(
        self,
        node_id: str,
        year: int,
        node_type: str = "Entity",
        direction: str = 'both'
    ) -> int:
        """
        Get degree (number of connections) for a node
        
        Args:
            node_id: Node ID
            year: Node year
            node_type: Node label/type
            direction: 'in', 'out', or 'both'
            
        Returns:
            Number of connections
        """
        if not self.is_available():
            return 0
        
        try:
            if direction == 'in':
                query = f"MATCH (n:{node_type} {{id: $id, year: $year}})<-[r]-() RETURN count(r) as degree"
            elif direction == 'out':
                query = f"MATCH (n:{node_type} {{id: $id, year: $year}})-[r]->() RETURN count(r) as degree"
            else:
                query = f"MATCH (n:{node_type} {{id: $id, year: $year}})-[r]-() RETURN count(r) as degree"
            
            result = self.client.execute_query(query, {"id": node_id, "year": year})
            return result[0].get('degree', 0) if result else 0
            
        except Exception as e:
            logger.error(f"Error getting node degree: {str(e)}")
            return 0
    
    def get_connected_nodes(
        self,
        node_id: str,
        year: int,
        node_type: str = "Entity",
        relationship_type: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get all nodes directly connected to a given node
        
        Args:
            node_id: Node ID
            year: Node year
            node_type: Node label/type
            relationship_type: Optional filter by relationship type
            
        Returns:
            List of connected nodes
        """
        if not self.is_available():
            return []
        
        try:
            if relationship_type:
                query = f"""
                MATCH (n:{node_type} {{id: $id, year: $year}})-[r:{relationship_type}]-(connected)
                WHERE r.year = $year
                RETURN connected, type(r) as relationship_type
                """
            else:
                query = f"""
                MATCH (n:{node_type} {{id: $id, year: $year}})-[r]-(connected)
                WHERE r.year = $year
                RETURN connected, type(r) as relationship_type
                """
            
            results = self.client.execute_query(query, {"id": node_id, "year": year})
            
            connected_nodes = []
            for record in results:
                node = record.get('connected')
                rel_type = record.get('relationship_type')
                if node:
                    node_dict = dict(node)
                    node_dict['relationship_type'] = rel_type
                    connected_nodes.append(node_dict)
            
            return connected_nodes
            
        except Exception as e:
            logger.error(f"Error getting connected nodes: {str(e)}")
            return []
    
    def find_shortest_path(
        self,
        start_node: Dict[str, Any],
        end_node: Dict[str, Any],
        relationship_types: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Find shortest path between two nodes
        
        Args:
            start_node: {id, year, type}
            end_node: {id, year, type}
            relationship_types: Optional list of allowed relationship types
            
        Returns:
            Path information or None if no path found
        """
        if not self.is_available():
            return {"success": False, "error": "Neo4j not available"}
        
        try:
            start_type = start_node.get('type', 'Entity')
            end_type = end_node.get('type', 'Entity')
            year = start_node.get('year')
            
            if relationship_types:
                rel_filter = f"WHERE ALL(r in relationships(path) WHERE type(r) IN {relationship_types})"
            else:
                rel_filter = ""
            
            query = f"""
            MATCH path = shortestPath(
                (start:{start_type} {{id: $start_id, year: $year}})
                -[*]->
                (end:{end_type} {{id: $end_id, year: $year}})
            )
            {rel_filter}
            RETURN path
            """
            
            parameters = {
                "start_id": start_node.get('id'),
                "end_id": end_node.get('id'),
                "year": year
            }
            
            results = self.client.execute_query(query, parameters)
            
            if results and len(results) > 0:
                path = results[0].get('path')
                if path:
                    return {
                        "success": True,
                        "nodes": [dict(node) for node in path.nodes],
                        "relationships": [dict(rel) for rel in path.relationships],
                        "length": len(path.relationships)
                    }
            
            return {
                "success": False,
                "error": "No path found"
            }
            
        except Exception as e:
            logger.error(f"Error finding shortest path: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }


neo4j_service = Neo4jService()
