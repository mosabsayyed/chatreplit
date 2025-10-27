"""
Semantic Search Service
Unified interface for schema and entity semantic search using pgvector
"""
from typing import Dict, Any, List, Optional
from .schema_embedder import get_schema_embedder
from .entity_embedder import get_entity_embedder

class SemanticSearchService:
    """Unified semantic search service for LLM function calling"""
    
    def __init__(self):
        self.schema_embedder = get_schema_embedder()
        self.entity_embedder = get_entity_embedder()
    
    def search_schema(self, query: str, top_k: int = 5) -> Dict[str, Any]:
        """
        Search for relevant database schema elements
        
        Args:
            query: Natural language query describing what to find
            top_k: Number of results to return
            
        Returns:
            Dict with relevant tables, join paths, and metadata
        """
        results = self.schema_embedder.search_schema(query, top_k)
        
        # Organize results by type
        tables = []
        chains = []
        join_tables = []
        
        for item in results:
            metadata = item.get("metadata", {})
            item_type = metadata.get("type")
            
            if item_type == "entity_table":
                tables.append({
                    "table_name": item["table_name"],
                    "description": item["description"],
                    "domain": metadata.get("domain"),
                    "columns": metadata.get("columns", []),
                    "similarity": item["similarity"]
                })
            elif item_type == "relationship_chain":
                chains.append({
                    "chain_id": metadata.get("chain_id"),
                    "path": metadata.get("path", []),
                    "hops": metadata.get("hops"),
                    "source": metadata.get("source"),
                    "target": metadata.get("target"),
                    "similarity": item["similarity"]
                })
            elif item_type == "join_table":
                join_tables.append({
                    "table_name": item["table_name"],
                    "description": item["description"],
                    "connects": metadata.get("connects", []),
                    "similarity": item["similarity"]
                })
        
        return {
            "query": query,
            "tables": tables,
            "relationship_chains": chains,
            "join_tables": join_tables,
            "total_results": len(results)
        }
    
    def search_entities(
        self, 
        query: str, 
        entity_type: Optional[str] = None,
        top_k: int = 10
    ) -> Dict[str, Any]:
        """
        Search for specific entities (projects, capabilities, etc.)
        
        Args:
            query: Natural language description of entity to find
            entity_type: Optional filter (project, capability, objective, risk, etc.)
            top_k: Number of results to return
            
        Returns:
            Dict with matching entities and their metadata
        """
        results = self.entity_embedder.search_entities(query, entity_type, top_k)
        
        entities = []
        for item in results:
            entities.append({
                "entity_type": item["entity_type"],
                "entity_id": item["entity_id"],
                "entity_year": item["entity_year"],
                "name": item["name"],
                "description": item["description"],
                "similarity": item["similarity"],
                "table_name": item.get("metadata", {}).get("table_name")
            })
        
        return {
            "query": query,
            "entity_type_filter": entity_type,
            "entities": entities,
            "total_results": len(entities)
        }
    
    def resolve_entity_reference(
        self, 
        reference_text: str,
        entity_type: Optional[str] = None,
        year: Optional[int] = None,
        threshold: float = 0.7
    ) -> Optional[Dict[str, Any]]:
        """
        Resolve a user's entity reference to a specific entity
        
        Args:
            reference_text: How user referred to the entity
            entity_type: Optional type hint
            year: Optional year filter
            threshold: Minimum similarity score to accept
            
        Returns:
            Best matching entity or None
        """
        results = self.search_entities(reference_text, entity_type, top_k=5)
        
        if not results["entities"]:
            return None
        
        # Filter by year if specified
        candidates = results["entities"]
        if year:
            candidates = [e for e in candidates if e["entity_year"] == year]
        
        # Return best match if above threshold
        if candidates and candidates[0]["similarity"] >= threshold:
            return candidates[0]
        
        return None
    
    def discover_relevant_schema(
        self,
        user_query: str,
        top_tables: int = 3,
        top_chains: int = 2
    ) -> Dict[str, Any]:
        """
        Discover relevant schema elements for a user query
        Optimized for LLM consumption
        
        Args:
            user_query: Full user question
            top_tables: Number of tables to return
            top_chains: Number of relationship chains to return
            
        Returns:
            Compact schema context for LLM
        """
        schema_results = self.search_schema(user_query, top_k=top_tables + top_chains)
        
        # Extract most relevant table names
        relevant_tables = [t["table_name"] for t in schema_results["tables"][:top_tables]]
        
        # Extract best relationship chain
        best_chain = None
        if schema_results["relationship_chains"]:
            chain = schema_results["relationship_chains"][0]
            best_chain = {
                "chain_id": chain["chain_id"],
                "path": chain["path"],
                "source": chain["source"],
                "target": chain["target"]
            }
        
        return {
            "relevant_tables": relevant_tables,
            "relationship_chain": best_chain,
            "user_query": user_query
        }


# Singleton instance
_semantic_search_service = None

def get_semantic_search_service() -> SemanticSearchService:
    """Get or create singleton semantic search service"""
    global _semantic_search_service
    if _semantic_search_service is None:
        _semantic_search_service = SemanticSearchService()
    return _semantic_search_service
