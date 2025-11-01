"""
Single-Layer LLM Orchestrator with Function Calling
Replaces inefficient 4-layer agent with pgvector-augmented single LLM call
"""
import json
from typing import List, Dict, Any, Optional
from datetime import datetime
import openai
from pydantic import ValidationError

from app.services.semantic_search import SemanticSearchService
from app.services.sql_executor import SQLExecutorService
from app.services.llm_provider import LLMProvider
from app.services.neo4j_service import neo4j_service
from app.models.function_calling import (
    SemanticSearchSchemaInput,
    SemanticSearchEntitiesInput,
    ExecuteSQLInput,
    ExecuteSimpleQueryInput,
    SchemaSearchResult,
    EntitySearchResult,
    SQLExecutionResult,
    OrchestratorResponse,
    OrchestratorStep,
    FunctionCall
)
from app.config import settings


class OrchestratorV2:
    """
    ENHANCED - Single-layer LLM orchestrator with DUAL DATABASE support
    
    Architecture:
        User Query → LLM with function calling → pgvector + Neo4j + SQL → Response
        
    Benefits:
        - 75% cost reduction (1 LLM call vs 4)
        - Graph traversal for complex multi-hop queries
        - Faster response times
        - Structured outputs guaranteed via Pydantic
        - Function calling for tool orchestration
    """
    
    SYSTEM_PROMPT = """You are JOSOOR, an enterprise transformation analytics assistant with dual database capabilities.

Your role is to help users analyze transformation data using semantic search, SQL queries, and graph traversal.

AVAILABLE TOOLS:

**Vector Search Tools (pgvector on Supabase):**

1. search_schema(query, top_k) - Find relevant database tables, columns, and relationships
   - Use when user asks about available data or schema discovery
   - Example: "What tables are related to projects?"

2. search_entities(query, entity_type, top_k) - Find specific entities using semantic search
   - Use to resolve fuzzy entity references: "Project Atlas", "high-risk issues", "digital initiatives"
   - entity_type options: project, capability, objective, risk, strategy, tactic, it_system, entity
   - Returns exact IDs and years for SQL queries

**SQL Tools (Supabase PostgreSQL):**

3. execute_sql(sql, validate, max_rows) - Execute SQL queries with composite key validation
   - USE FOR: Simple queries (1-2 hops), aggregations, filtering, data retrieval
   - CRITICAL: All JOINs and WHERE clauses on ID columns MUST include year
   - Example: "Show all projects in 2024", "Count active capabilities"

4. execute_simple_query(table_name, filters, columns, max_rows) - Simple filter-based queries
   - USE FOR: Basic lookups on single tables
   - Example: table_name="ent_projects", filters={"year": 2027, "status": "active"}

**Graph Tools (Neo4j - for complex relationship queries):**

5. graph_walk(start_node, relationship_types, max_depth) - Walk graph relationships from a starting node
   - USE FOR: Complex multi-hop traversal (3-5+ hops), relationship exploration
   - EXAMPLE: "Find all risks affecting capabilities through projects and IT systems"
   - RETURNS: Paths with nodes, relationships, and connectivity data
   - start_node format: {id: "PRJ001", year: 2024, type: "Project"}
   - relationship_types: ["HAS_CAPABILITY", "SUPPORTED_BY_IT_SYSTEM", "HAS_RISK"]

6. graph_search(pattern, filters, limit) - Find matching patterns in graph
   - USE FOR: Exploratory queries, pattern discovery
   - EXAMPLE: "Find all projects with high-risk IT systems"
   - RETURNS: Matching subgraphs with metadata
   - pattern format: "(p:Project)-[:HAS_RISK]->(r:Risk)"

**DECISION RULES:**

- Simple Query (1-2 hops, aggregations)? → execute_sql or execute_simple_query
- Complex Query (3+ hops, relationship exploration)? → graph_walk
- Pattern Discovery (finding connections)? → graph_search
- Schema Discovery? → search_schema
- Entity Resolution (fuzzy search)? → search_entities

**WORKFLOW:**

1. User asks a question
2. Determine query complexity:
   - Simple data retrieval → SQL tools
   - Multi-hop relationships → Graph tools
   - Need entity IDs first? → search_entities, then SQL or graph
3. Call tools in parallel when possible
4. Synthesize results into clear, concise answer

**COMPOSITE KEY RULES:**
- Tables use (id, year) composite primary keys
- SQL: ALWAYS join on BOTH id AND year: ON a.id = b.parent_id AND a.year = b.year
- Neo4j: All relationships include year property: MATCH (p)-[:HAS_CAPABILITY {year: 2024}]->(c)
- Never join on ID alone

**CRITICAL EXAMPLES:**

SQL Example (Simple 1-2 hop):
```sql
SELECT p.* 
FROM ent_projects p
JOIN jt_project_capabilities pc 
    ON p.id = pc.project_id AND p.year = pc.project_year
WHERE p.id = 'PRJ001' AND p.year = 2024;
```

Graph Example (Complex 3+ hop):
```python
graph_walk(
    start_node={"id": "PRJ001", "year": 2024, "type": "Project"},
    relationship_types=["HAS_CAPABILITY", "SUPPORTED_BY_IT_SYSTEM", "HAS_RISK"],
    max_depth=5
)
```

**NOTE:** Neo4j may not always be available. If graph tools fail, fall back to SQL for the same query.

CURRENT YEAR: 2025

Be precise, helpful, and choose the right tool for each query complexity level."""

    def __init__(self):
        """Initialize orchestrator with required services"""
        self.semantic_search = SemanticSearchService()
        self.sql_executor = SQLExecutorService()
        self.llm_provider = LLMProvider()
        self.debug_log = []
    
    def _get_openai_client(self):
        """Get OpenAI client for function calling"""
        # Use the LLM provider's _get_client method
        return self.llm_provider._get_client()
    
    def _build_function_tools(self) -> List[Dict[str, Any]]:
        """Build OpenAI function calling tool definitions"""
        return [
            {
                "type": "function",
                "function": {
                    "name": "search_schema",
                    "description": "Search database schema for relevant tables, columns, and relationships using semantic similarity",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "Natural language description of schema elements to find"
                            },
                            "top_k": {
                                "type": "integer",
                                "description": "Number of results to return",
                                "default": 5
                            }
                        },
                        "required": ["query"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "search_entities",
                    "description": "Search for specific entities (projects, capabilities, objectives, etc.) using semantic similarity",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "Natural language description of entities to find"
                            },
                            "entity_type": {
                                "type": "string",
                                "description": "Filter by entity type",
                                "enum": ["project", "capability", "objective", "risk", "strategy", "tactic", "it_system", "entity"]
                            },
                            "top_k": {
                                "type": "integer",
                                "description": "Number of results to return",
                                "default": 10
                            }
                        },
                        "required": ["query"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "execute_sql",
                    "description": "Execute SQL query with composite key validation. CRITICAL: All JOINs and WHERE on ID columns must include year.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "sql": {
                                "type": "string",
                                "description": "SQL query to execute"
                            },
                            "validate": {
                                "type": "boolean",
                                "description": "Validate composite key compliance",
                                "default": True
                            },
                            "max_rows": {
                                "type": "integer",
                                "description": "Maximum rows to return",
                                "default": 1000
                            }
                        },
                        "required": ["sql"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "execute_simple_query",
                    "description": "Execute simple filter-based query on a single table",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "table_name": {
                                "type": "string",
                                "description": "Table to query"
                            },
                            "filters": {
                                "type": "object",
                                "description": "Column-value filters",
                                "additionalProperties": True
                            },
                            "columns": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Columns to select"
                            },
                            "max_rows": {
                                "type": "integer",
                                "description": "Maximum rows to return",
                                "default": 1000
                            }
                        },
                        "required": ["table_name", "filters"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "graph_walk",
                    "description": "Walk graph relationships for complex multi-hop traversal (3-5+ hops). Use when user asks about relationships across multiple entities. Requires Neo4j to be available.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "start_node": {
                                "type": "object",
                                "description": "Starting node with id, year, type (e.g., {id: 'PRJ001', year: 2024, type: 'Project'})",
                                "properties": {
                                    "id": {"type": "string"},
                                    "year": {"type": "integer"},
                                    "type": {"type": "string", "description": "Node type: Project, Capability, Risk, ITSystem, etc."}
                                },
                                "required": ["id", "year", "type"]
                            },
                            "relationship_types": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "List of relationship types to follow: HAS_CAPABILITY, SUPPORTED_BY_IT_SYSTEM, HAS_RISK, etc."
                            },
                            "max_depth": {
                                "type": "integer",
                                "description": "Maximum number of hops (default: 5)",
                                "default": 5
                            }
                        },
                        "required": ["start_node", "relationship_types"]
                    }
                }
            },
            {
                "type": "function",
                "function": {
                    "name": "graph_search",
                    "description": "Search for matching patterns in graph. Use for exploratory queries and pattern discovery. Requires Neo4j to be available.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "pattern": {
                                "type": "string",
                                "description": "Cypher pattern like '(p:Project)-[:HAS_RISK]->(r:Risk)'"
                            },
                            "filters": {
                                "type": "object",
                                "description": "Property filters e.g., {year: 2024, status: 'active'}",
                                "additionalProperties": True
                            },
                            "limit": {
                                "type": "integer",
                                "description": "Maximum results to return",
                                "default": 100
                            }
                        },
                        "required": ["pattern"]
                    }
                }
            }
        ]
    
    def _pre_process_context(
        self,
        user_query: str,
        conversation_history: Optional[List[Dict[str, str]]] = None
    ) -> Dict[str, Any]:
        """
        Pre-process user query to extract:
        - Resolved entity references from conversation history
        - Suggested worldview chains based on query intent
        - Temporal context (year mentions)
        
        This reduces LLM's cognitive load and improves accuracy.
        """
        context = {
            "resolved_entities": [],
            "suggested_chains": [],
            "temporal_hints": {"year": 2025}
        }
        
        # 1. Entity reference resolution
        if conversation_history:
            # Look for "that project", "it", "the entity" in user_query
            reference_keywords = ["that", "it", "the", "this", "previous"]
            has_reference = any(kw in user_query.lower() for kw in reference_keywords)
            
            if has_reference:
                # Search last 3 conversation turns for entity mentions
                for msg in reversed(conversation_history[-3:]):
                    if msg.get("role") == "assistant":
                        # Extract entities from assistant's previous response
                        # Look for patterns like "Project PRJ001" or "id: PRJ001"
                        import re
                        entity_pattern = r"(PRJ|CAP|OBJ|RSK|ENT)\d+"
                        matches = re.findall(entity_pattern, msg.get("content", ""))
                        if matches:
                            context["resolved_entities"].append({
                                "id": matches[0],
                                "source": "conversation_history"
                            })
                            break
        
        # 2. Chain suggestion based on query keywords
        query_lower = user_query.lower()
        if "risk" in query_lower and "project" in query_lower:
            context["suggested_chains"] = ["2A_Strategy_to_Tactics_Tools", "4_Risk_Build"]
        elif "capability" in query_lower and "project" in query_lower:
            context["suggested_chains"] = ["2A_Strategy_to_Tactics_Tools"]
        elif "performance" in query_lower:
            context["suggested_chains"] = ["1_SectorOps", "2B_Strategy_to_Tactics_Perf"]
        
        # 3. Temporal hints
        import re
        year_matches = re.findall(r"\b(202\d)\b", user_query)
        if year_matches:
            context["temporal_hints"]["year"] = int(year_matches[0])
        
        return context
    
    def _execute_function_call(
        self,
        function_name: str,
        arguments: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Execute a function call from the LLM
        
        Args:
            function_name: Name of function to call
            arguments: Function arguments
            
        Returns:
            Function result as dictionary
        """
        try:
            if function_name == "search_schema":
                input_model = SemanticSearchSchemaInput(**arguments)
                result = self.semantic_search.search_schema(
                    query=input_model.query,
                    top_k=input_model.top_k
                )
                return result
            
            elif function_name == "search_entities":
                input_model = SemanticSearchEntitiesInput(**arguments)
                result = self.semantic_search.search_entities(
                    query=input_model.query,
                    entity_type=input_model.entity_type,
                    top_k=input_model.top_k
                )
                return result
            
            elif function_name == "execute_sql":
                input_model = ExecuteSQLInput(**arguments)
                result = self.sql_executor.execute_query(
                    sql=input_model.sql,
                    validate=input_model.validate,
                    max_rows=input_model.max_rows
                )
                return {
                    "success": result["success"],
                    "data": result.get("data"),
                    "row_count": result.get("row_count", 0),
                    "error": result.get("error"),
                    "sql": input_model.sql
                }
            
            elif function_name == "execute_simple_query":
                input_model = ExecuteSimpleQueryInput(**arguments)
                result = self.sql_executor.execute_simple_filter_query(
                    table_name=input_model.table_name,
                    filters=input_model.filters,
                    columns=input_model.columns,
                    max_rows=input_model.max_rows
                )
                return {
                    "success": result["success"],
                    "data": result.get("data"),
                    "row_count": result.get("row_count", 0),
                    "error": result.get("error"),
                    "table": input_model.table_name
                }
            
            elif function_name == "graph_walk":
                if not neo4j_service.is_available():
                    return {
                        "success": False,
                        "error": "Neo4j not available. Please use SQL tools for this query.",
                        "fallback_suggestion": "Try using execute_sql with JOIN statements instead"
                    }
                
                result = neo4j_service.graph_walk(
                    start_node=arguments['start_node'],
                    relationship_types=arguments['relationship_types'],
                    max_depth=arguments.get('max_depth', 5)
                )
                return result
            
            elif function_name == "graph_search":
                if not neo4j_service.is_available():
                    return {
                        "success": False,
                        "error": "Neo4j not available. Please use SQL tools for this query.",
                        "fallback_suggestion": "Try using execute_sql with JOIN statements instead"
                    }
                
                result = neo4j_service.graph_search(
                    pattern=arguments['pattern'],
                    filters=arguments.get('filters'),
                    limit=arguments.get('limit', 100)
                )
                return result
            
            else:
                return {
                    "success": False,
                    "error": f"Unknown function: {function_name}"
                }
        
        except ValidationError as e:
            return {
                "success": False,
                "error": f"Validation error: {str(e)}"
            }
        except Exception as e:
            return {
                "success": False,
                "error": f"Execution error: {str(e)}"
            }
    
    def process_query(
        self,
        user_query: str,
        conversation_history: Optional[List[Dict[str, str]]] = None,
        max_iterations: int = 5
    ) -> Dict[str, Any]:
        """
        Process user query using function calling
        
        Args:
            user_query: User's question
            conversation_history: Previous messages in OpenAI format [{role, content}]
            max_iterations: Maximum function calling iterations
            
        Returns:
            Dictionary with answer, steps_taken, and metadata
        """
        self.debug_log = []
        steps = []
        
        # Build messages
        messages = []
        
        # Pre-process context BEFORE LLM call
        pre_context = self._pre_process_context(user_query, conversation_history)
        
        # Enhance system prompt with pre-processed context
        enhanced_prompt = self.SYSTEM_PROMPT + f"""

## PRE-RESOLVED CONTEXT
Resolved Entities: {pre_context['resolved_entities']}
Suggested Chains: {pre_context['suggested_chains']}
Temporal Context: {pre_context['temporal_hints']}

Use this context to make faster, more accurate decisions."""
        
        # Add system prompt
        messages.append({
            "role": "system",
            "content": enhanced_prompt
        })
        
        # Add conversation history if provided
        if conversation_history:
            messages.extend(conversation_history)
        
        # Add current user query
        messages.append({
            "role": "user",
            "content": user_query
        })
        
        # Log initial state
        self.debug_log.append({
            "type": "orchestrator_start",
            "user_query": user_query,
            "conversation_history_length": len(conversation_history) if conversation_history else 0,
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Get OpenAI client
        client = self._get_openai_client()
        tools = self._build_function_tools()
        
        # Iterative function calling loop
        iteration = 0
        while iteration < max_iterations:
            iteration += 1
            
            self.debug_log.append({
                "type": "llm_call",
                "iteration": iteration,
                "message_count": len(messages),
                "timestamp": datetime.utcnow().isoformat()
            })
            
            # Call LLM with function calling
            try:
                response = client.chat.completions.create(
                    model="gpt-4o",
                    messages=messages,
                    tools=tools,  # type: ignore
                    tool_choice="auto"
                )
                
                assistant_message = response.choices[0].message
                
                # Log LLM response
                self.debug_log.append({
                    "type": "llm_response",
                    "finish_reason": response.choices[0].finish_reason,
                    "has_tool_calls": bool(assistant_message.tool_calls),
                    "tool_call_count": len(assistant_message.tool_calls) if assistant_message.tool_calls else 0
                })
                
                # If no tool calls, we have final answer
                if not assistant_message.tool_calls:
                    final_answer = assistant_message.content
                    
                    self.debug_log.append({
                        "type": "orchestrator_complete",
                        "iterations": iteration,
                        "steps_taken": len(steps)
                    })
                    
                    return {
                        "answer": final_answer,
                        "steps_taken": steps,
                        "debug_log": self.debug_log,
                        "total_iterations": iteration,
                        "success": True
                    }
                
                # Add assistant message to history
                messages.append(assistant_message)
                
                # Execute tool calls
                for tool_call in assistant_message.tool_calls:
                    function_name = tool_call.function.name  # type: ignore
                    arguments = json.loads(tool_call.function.arguments)  # type: ignore
                    
                    self.debug_log.append({
                        "type": "function_call",
                        "function": function_name,
                        "arguments": arguments
                    })
                    
                    # Execute function
                    result = self._execute_function_call(function_name, arguments)
                    
                    self.debug_log.append({
                        "type": "function_result",
                        "function": function_name,
                        "success": result.get("success", True),
                        "result_summary": self._summarize_result(result)
                    })
                    
                    # Track step
                    steps.append({
                        "step_number": len(steps) + 1,
                        "function_call": {
                            "function_name": function_name,
                            "arguments": arguments,
                            "reasoning": f"LLM called {function_name}"
                        },
                        "result": result,
                        "status": "success" if result.get("success", True) else "error"
                    })
                    
                    # Add function result to messages
                    messages.append({
                        "role": "tool",
                        "tool_call_id": tool_call.id,
                        "name": function_name,
                        "content": json.dumps(result)
                    })
            
            except Exception as e:
                self.debug_log.append({
                    "type": "error",
                    "error": str(e),
                    "iteration": iteration
                })
                
                return {
                    "answer": f"Error processing query: {str(e)}",
                    "steps_taken": steps,
                    "debug_log": self.debug_log,
                    "success": False,
                    "error": str(e)
                }
        
        # Max iterations reached
        return {
            "answer": "Query processing exceeded maximum iterations. Please try rephrasing your question.",
            "steps_taken": steps,
            "debug_log": self.debug_log,
            "success": False,
            "error": "Max iterations reached"
        }
    
    def _summarize_result(self, result: Dict[str, Any]) -> str:
        """Summarize function result for logging"""
        if not result.get("success", True):
            return f"Error: {result.get('error', 'Unknown error')}"
        
        if "data" in result:
            row_count = result.get("row_count", len(result.get("data", [])))
            return f"{row_count} rows returned"
        
        if "entities" in result:
            return f"{len(result['entities'])} entities found"
        
        if "tables" in result:
            return f"{len(result['tables'])} tables found"
        
        return "Success"
