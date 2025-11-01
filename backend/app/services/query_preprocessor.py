"""
Query Preprocessor Layer
Performs "prep work" BEFORE LLM calls to enrich context with vector and graph data
"""
from typing import Dict, Any, List, Optional
from app.services.semantic_search import SemanticSearchService
from app.services.neo4j_service import neo4j_service
import logging

logger = logging.getLogger(__name__)

class QueryPreprocessor:
    """
    Pre-processes user queries to enrich context BEFORE LLM call
    
    This is the "prep work" that makes LLM smarter by:
    1. Resolving entities mentioned in query via semantic search
    2. Pre-querying graph for related nodes
    3. Suggesting appropriate tools based on query complexity
    4. Providing enriched context to LLM
    """
    
    def __init__(self):
        self.semantic_search = SemanticSearchService()
    
    async def preprocess(
        self,
        user_query: str,
        conversation_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Pre-process query to build enriched context
        
        Args:
            user_query: User's natural language query
            conversation_id: Optional conversation ID for context
            
        Returns:
            {
                "user_query": str,
                "pre_resolved_entities": List[Dict],  # Entities found via semantic search
                "graph_context": Dict,  # Related nodes from Neo4j
                "suggested_tools": List[str],  # Tools LLM should consider
                "complexity_hint": str,  # Query complexity indicator
                "available_paths": List[str]  # Valid worldview paths
            }
        """
        logger.info(f"Preprocessing query: {user_query}")
        
        enriched_context = {
            "user_query": user_query,
            "pre_resolved_entities": [],
            "graph_context": {},
            "suggested_tools": [],
            "complexity_hint": "",
            "available_paths": []
        }
        
        try:
            entities = await self._resolve_entities(user_query)
            enriched_context["pre_resolved_entities"] = entities
            
            if entities and neo4j_service.is_available():
                graph_context = await self._pre_query_graph(entities)
                enriched_context["graph_context"] = graph_context
            
            complexity = self._analyze_complexity(user_query, entities)
            enriched_context["complexity_hint"] = complexity
            
            suggested_tools = self._suggest_tools(complexity, entities)
            enriched_context["suggested_tools"] = suggested_tools
            
            paths = self._identify_worldview_paths(user_query)
            enriched_context["available_paths"] = paths
            
            logger.info(f"Preprocessed context: {len(entities)} entities, complexity: {complexity}")
            
        except Exception as e:
            logger.error(f"Error preprocessing query: {str(e)}")
        
        return enriched_context
    
    async def _resolve_entities(self, user_query: str) -> List[Dict[str, Any]]:
        """
        Resolve entities mentioned in query via semantic search
        
        Returns list of entities with their composite keys (id, year)
        """
        try:
            entity_types = ['project', 'capability', 'risk', 'it_system', 'objective']
            resolved_entities = []
            
            for entity_type in entity_types:
                results = self.semantic_search.search_entities(
                    query=user_query,
                    entity_type=entity_type,
                    top_k=3
                )
                
                if results.get('success') and results.get('entities'):
                    for entity in results['entities'][:1]:
                        resolved_entities.append({
                            "type": entity_type,
                            "id": entity.get('id'),
                            "year": entity.get('year'),
                            "name": entity.get('name'),
                            "score": entity.get('score', 0.0)
                        })
            
            resolved_entities.sort(key=lambda x: x.get('score', 0), reverse=True)
            return resolved_entities[:3]
            
        except Exception as e:
            logger.error(f"Error resolving entities: {str(e)}")
            return []
    
    async def _pre_query_graph(self, entities: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Pre-query Neo4j graph for related nodes
        
        Provides graph context about entities before LLM decides what to do
        """
        try:
            if not entities:
                return {}
            
            primary_entity = entities[0]
            
            connected_nodes = neo4j_service.get_connected_nodes(
                node_id=primary_entity['id'],
                year=primary_entity['year'],
                node_type=primary_entity['type'].capitalize()
            )
            
            degree = neo4j_service.get_node_degree(
                node_id=primary_entity['id'],
                year=primary_entity['year'],
                node_type=primary_entity['type'].capitalize()
            )
            
            return {
                "primary_entity": primary_entity,
                "connected_nodes_count": len(connected_nodes),
                "degree": degree,
                "connected_node_types": list(set(
                    node.get('relationship_type', 'Unknown')
                    for node in connected_nodes
                ))
            }
            
        except Exception as e:
            logger.error(f"Error pre-querying graph: {str(e)}")
            return {}
    
    def _analyze_complexity(
        self,
        user_query: str,
        entities: List[Dict[str, Any]]
    ) -> str:
        """
        Analyze query complexity to determine if simple SQL or complex graph traversal
        
        Returns: "simple" (1-2 hops), "moderate" (2-3 hops), "complex" (3-5+ hops)
        """
        query_lower = user_query.lower()
        
        multi_hop_keywords = [
            'through', 'via', 'affecting', 'impacting', 'connected to',
            'related to', 'linked to', 'across', 'between'
        ]
        
        relationship_keywords = [
            'relationships', 'connections', 'dependencies',
            'path', 'chain', 'network'
        ]
        
        hop_count = 0
        
        if any(keyword in query_lower for keyword in multi_hop_keywords):
            hop_count += 1
        
        if any(keyword in query_lower for keyword in relationship_keywords):
            hop_count += 2
        
        if len(entities) > 1:
            hop_count += 1
        
        if hop_count == 0:
            return "simple (1-2 hops)"
        elif hop_count <= 2:
            return "moderate (2-3 hops)"
        else:
            return "complex (3-5+ hops)"
    
    def _suggest_tools(
        self,
        complexity: str,
        entities: List[Dict[str, Any]]
    ) -> List[str]:
        """
        Suggest which tools LLM should consider based on query complexity
        
        Returns list of tool names
        """
        suggested = []
        
        if "simple" in complexity:
            suggested.extend(["execute_sql", "execute_simple_query"])
        
        if "moderate" in complexity or "complex" in complexity:
            if neo4j_service.is_available():
                suggested.append("graph_walk")
            else:
                suggested.append("execute_sql")
        
        if "complex" in complexity:
            if neo4j_service.is_available():
                suggested.append("graph_search")
        
        if entities:
            suggested.insert(0, "search_entities")
        
        return suggested
    
    def _identify_worldview_paths(self, user_query: str) -> List[str]:
        """
        Identify which worldview map paths are relevant to the query
        
        Returns list of valid SQL join paths or Cypher relationship patterns
        """
        query_lower = user_query.lower()
        paths = []
        
        path_mapping = {
            "project.*capability": [
                "ent_projects → jt_project_capabilities → ent_capabilities"
            ],
            "project.*risk": [
                "ent_projects → jt_project_it_systems → ent_it_systems → jt_it_system_risks → ent_risks"
            ],
            "capability.*it.*system": [
                "ent_capabilities → jt_capability_processes → ent_processes → jt_process_it_systems → ent_it_systems"
            ],
            "objective.*project": [
                "sec_objectives → jt_objective_projects → ent_projects"
            ]
        }
        
        for pattern, path_list in path_mapping.items():
            pattern_parts = pattern.split(".*")
            if all(part in query_lower for part in pattern_parts):
                paths.extend(path_list)
        
        return paths


query_preprocessor = QueryPreprocessor()
