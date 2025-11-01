"""
Neo4j Database Client
Manages connections and basic operations for Neo4j graph database
"""
from neo4j import GraphDatabase, Driver
from typing import Optional, Dict, Any, List
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class Neo4jClient:
    """
    Neo4j graph database client with connection pooling
    """
    
    def __init__(self):
        self.driver: Optional[Driver] = None
        self._connected = False
    
    def connect(self) -> bool:
        """
        Create Neo4j connection
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        if self._connected and self.driver:
            return True
        
        try:
            if not settings.NEO4J_URI:
                logger.warning("NEO4J_URI not configured. Neo4j features will be disabled.")
                return False
            
            self.driver = GraphDatabase.driver(
                settings.NEO4J_URI,
                auth=(settings.NEO4J_USERNAME, settings.NEO4J_PASSWORD),
                max_connection_lifetime=3600,
                max_connection_pool_size=50,
                connection_acquisition_timeout=60
            )
            
            with self.driver.session(database=settings.NEO4J_DATABASE) as session:
                result = session.run("RETURN 1")
                result.single()
            
            self._connected = True
            logger.info(f"Connected to Neo4j at {settings.NEO4J_URI}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect to Neo4j: {str(e)}")
            self._connected = False
            return False
    
    def disconnect(self):
        """Close Neo4j connection"""
        if self.driver:
            self.driver.close()
            self.driver = None
            self._connected = False
            logger.info("Disconnected from Neo4j")
    
    def is_connected(self) -> bool:
        """Check if connected to Neo4j"""
        return self._connected and self.driver is not None
    
    def execute_query(
        self,
        query: str,
        parameters: Optional[Dict[str, Any]] = None,
        database: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Execute a Cypher query and return results
        
        Args:
            query: Cypher query string
            parameters: Query parameters
            database: Database name (defaults to configured database)
            
        Returns:
            List of result records as dictionaries
        """
        if not self.is_connected():
            if not self.connect():
                return []
        
        try:
            db = database or settings.NEO4J_DATABASE
            with self.driver.session(database=db) as session:
                result = session.run(query, parameters or {})
                return [dict(record) for record in result]
        except Exception as e:
            logger.error(f"Neo4j query error: {str(e)}")
            logger.error(f"Query: {query}")
            logger.error(f"Parameters: {parameters}")
            raise
    
    def execute_write_query(
        self,
        query: str,
        parameters: Optional[Dict[str, Any]] = None,
        database: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Execute a write transaction (CREATE, MERGE, DELETE, etc.)
        
        Args:
            query: Cypher query string
            parameters: Query parameters
            database: Database name (defaults to configured database)
            
        Returns:
            Transaction summary
        """
        if not self.is_connected():
            if not self.connect():
                return {"success": False, "error": "Not connected to Neo4j"}
        
        try:
            db = database or settings.NEO4J_DATABASE
            
            def _write_tx(tx):
                result = tx.run(query, parameters or {})
                summary = result.consume()
                return {
                    "success": True,
                    "nodes_created": summary.counters.nodes_created,
                    "relationships_created": summary.counters.relationships_created,
                    "properties_set": summary.counters.properties_set,
                    "nodes_deleted": summary.counters.nodes_deleted,
                    "relationships_deleted": summary.counters.relationships_deleted
                }
            
            with self.driver.session(database=db) as session:
                return session.execute_write(_write_tx)
                
        except Exception as e:
            logger.error(f"Neo4j write query error: {str(e)}")
            logger.error(f"Query: {query}")
            logger.error(f"Parameters: {parameters}")
            return {"success": False, "error": str(e)}
    
    def clear_database(self) -> Dict[str, Any]:
        """
        Clear all nodes and relationships (USE WITH CAUTION)
        
        Returns:
            Transaction summary
        """
        logger.warning("Clearing Neo4j database - all data will be deleted!")
        return self.execute_write_query("MATCH (n) DETACH DELETE n")
    
    def get_node_count(self) -> int:
        """Get total number of nodes in database"""
        if not self.is_connected():
            return 0
        
        try:
            result = self.execute_query("MATCH (n) RETURN count(n) as count")
            return result[0]['count'] if result else 0
        except Exception:
            return 0
    
    def get_relationship_count(self) -> int:
        """Get total number of relationships in database"""
        if not self.is_connected():
            return 0
        
        try:
            result = self.execute_query("MATCH ()-[r]->() RETURN count(r) as count")
            return result[0]['count'] if result else 0
        except Exception:
            return 0
    
    def health_check(self) -> Dict[str, Any]:
        """
        Check Neo4j database health
        
        Returns:
            Health status dictionary
        """
        try:
            if not self.is_connected():
                if not self.connect():
                    return {
                        "status": "disconnected",
                        "connected": False,
                        "error": "Cannot connect to Neo4j"
                    }
            
            node_count = self.get_node_count()
            rel_count = self.get_relationship_count()
            
            return {
                "status": "healthy",
                "connected": True,
                "uri": settings.NEO4J_URI,
                "database": settings.NEO4J_DATABASE,
                "node_count": node_count,
                "relationship_count": rel_count
            }
            
        except Exception as e:
            return {
                "status": "error",
                "connected": False,
                "error": str(e)
            }


neo4j_client = Neo4jClient()
