"""
Pydantic Models for LLM Function Calling
Defines strict schemas for OpenAI structured outputs
"""
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any, Literal

# =============================================================================
# FUNCTION TOOL INPUT MODELS
# =============================================================================

class SemanticSearchSchemaInput(BaseModel):
    """Input for searching database schema"""
    query: str = Field(description="Natural language description of what schema elements to find (e.g., 'tables related to projects and capabilities')")
    top_k: int = Field(default=5, description="Number of results to return")


class SemanticSearchEntitiesInput(BaseModel):
    """Input for searching entities"""
    query: str = Field(description="Natural language description of entities to find (e.g., 'digital transformation projects', 'high-risk security issues')")
    entity_type: Optional[str] = Field(default=None, description="Filter by entity type: project, capability, objective, risk, strategy, tactic, it_system, entity")
    top_k: int = Field(default=10, description="Number of results to return")


class ExecuteSQLInput(BaseModel):
    """Input for executing SQL queries"""
    sql: str = Field(description="SQL query to execute. Must follow composite key rules: all JOINs and WHERE clauses on ID columns must include year.")
    validate: bool = Field(default=True, description="Whether to validate composite key compliance before execution")
    max_rows: int = Field(default=1000, description="Maximum number of rows to return")


class ExecuteSimpleQueryInput(BaseModel):
    """Input for simple filter-based queries"""
    table_name: str = Field(description="Table to query")
    filters: Dict[str, Any] = Field(description="Column-value filters (e.g., {'year': 2027, 'status': 'active'})")
    columns: Optional[List[str]] = Field(default=None, description="Columns to select (defaults to all)")
    max_rows: int = Field(default=1000, description="Maximum rows to return")


# =============================================================================
# FUNCTION TOOL OUTPUT MODELS  
# =============================================================================

class TableInfo(BaseModel):
    """Information about a database table"""
    table_name: str
    description: str
    domain: Optional[str] = None
    columns: List[str] = []
    similarity: float


class RelationshipChain(BaseModel):
    """A relationship chain from the worldview"""
    chain_id: str
    path: List[str]
    hops: int
    source: Optional[str] = None
    target: Optional[str] = None
    similarity: float


class SchemaSearchResult(BaseModel):
    """Result from schema search"""
    query: str
    tables: List[TableInfo]
    relationship_chains: List[RelationshipChain]
    total_results: int


class EntityInfo(BaseModel):
    """Information about an entity"""
    entity_type: str
    entity_id: str
    entity_year: int
    name: str
    description: Optional[str] = None
    similarity: float
    table_name: Optional[str] = None


class EntitySearchResult(BaseModel):
    """Result from entity search"""
    query: str
    entity_type_filter: Optional[str]
    entities: List[EntityInfo]
    total_results: int


class SQLExecutionResult(BaseModel):
    """Result from SQL execution"""
    success: bool
    data: Optional[List[Dict[str, Any]]] = None
    row_count: int
    error: Optional[str] = None
    sql: str


# =============================================================================
# LLM ORCHESTRATOR MODELS
# =============================================================================

class FunctionCall(BaseModel):
    """A function call made by the LLM"""
    function_name: Literal["search_schema", "search_entities", "execute_sql", "execute_simple_query"]
    arguments: Dict[str, Any]
    reasoning: str = Field(description="Why this function is being called")


class OrchestratorStep(BaseModel):
    """A single step in the orchestration"""
    step_number: int
    function_call: FunctionCall
    result: Optional[Dict[str, Any]] = None
    status: Literal["pending", "success", "error"] = "pending"
    error_message: Optional[str] = None


class OrchestratorResponse(BaseModel):
    """Final response from the orchestrator"""
    answer: str = Field(description="Natural language answer to the user's question")
    steps_taken: List[OrchestratorStep] = Field(description="Function calls made to answer the question")
    data_summary: Optional[Dict[str, Any]] = Field(default=None, description="Summary of data retrieved")
    total_results: int = Field(default=0, description="Total number of results returned")
    confidence: Literal["high", "medium", "low"] = Field(default="medium", description="Confidence in the answer")


# =============================================================================
# CONVERSATION HISTORY MODELS
# =============================================================================

class Message(BaseModel):
    """A message in the conversation"""
    role: Literal["system", "user", "assistant"]
    content: str


class ConversationTurn(BaseModel):
    """A single turn in the conversation"""
    turn_number: int
    user_message: str
    assistant_response: OrchestratorResponse
    timestamp: str


class ConversationHistory(BaseModel):
    """Complete conversation history"""
    conversation_id: str
    turns: List[ConversationTurn]
    created_at: str
    updated_at: str
