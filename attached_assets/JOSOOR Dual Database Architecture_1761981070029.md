
# JOSOOR Dual Database Architecture - Complete Migration Plan

**Version:** 2.0  
**Date:** January 2025  
**Status:** Ready for Implementation  
**Architecture:** Supabase PostgreSQL + Neo4j Graph (Hybrid)

---

## EXECUTIVE SUMMARY

This plan outlines the migration to a **dual database architecture** where:
- **Supabase PostgreSQL** (existing) handles all SQL tables, pgvector embeddings, transactions
- **Neo4j** (new) handles graph-based relationship queries, multi-hop traversal, analytics

**Key Innovation:** The application performs "prep work" BEFORE LLM calls to pre-query both databases, then sends enriched context to the LLM for better decision-making.

---

## ARCHITECTURE OVERVIEW

### Current State (What You Have)
```
User Query → OrchestratorV2 → LLM (GPT-4) → Function Calling
                                    ↓
                          ┌─────────┴─────────┐
                          ↓                   ↓
                   SemanticSearch      SQLExecutor
                   (pgvector)          (Supabase)
```

### Target State (Dual Database)
```
User Query → Pre-Processing Layer → OrchestratorV2 → LLM → Function Calling
                    ↓                                         ↓
            ┌───────┴────────┐                    ┌──────────┴──────────┐
            ↓                ↓                    ↓          ↓          ↓
      VectorSearch    GraphPreQuery      execute_sql  graph_walk  graph_search
      (pgvector)      (Neo4j)           (Supabase)   (Neo4j)     (Neo4j)
            ↓                ↓                    ↓          ↓          ↓
            └────────────────┴────────────────────┴──────────┴──────────┘
                                       ↓
                              Enriched Context → LLM
```

---

## CRITICAL DESIGN PRINCIPLES

### 1. **Prep Work Before LLM Call**

**Problem:** LLM doesn't know what data exists until it queries  
**Solution:** Application pre-queries vector/graph stores BEFORE calling LLM

```python
# BEFORE (Current - LLM decides blind)
user_query = "Show risks affecting Project Atlas"
→ LLM calls search_entities("Project Atlas")
→ LLM calls execute_sql(...)

# AFTER (New - App prepares context)
user_query = "Show risks affecting Project Atlas"
→ App pre-queries:
    - Vector: Find "Project Atlas" → PRJ001, 2024
    - Graph: Find connected risks → [RSK001, RSK005]
→ LLM receives: "User mentions 'Project Atlas' (PRJ001, 2024) which has 2 connected risks"
→ LLM makes better decision with full context
```

### 2. **Tool Descriptions for LLM**

**The LLM needs to know:**
- WHAT each tool does
- WHEN to use it (simple vs complex queries)
- WHAT data it returns

```python
# Tool descriptions that go in SYSTEM_PROMPT
TOOLS = {
    "execute_sql": {
        "description": "Execute SQL on Supabase for simple queries (1-2 hops)",
        "use_when": "User asks for basic data: 'Show all projects', 'List risks'",
        "returns": "Structured rows from SQL tables"
    },
    "graph_walk": {
        "description": "Walk graph relationships in Neo4j for complex traversal (3-5+ hops)",
        "use_when": "User asks about relationships: 'What risks affect capabilities through projects'",
        "returns": "Path data: nodes + edges + properties"
    },
    "graph_search": {
        "description": "Find patterns in Neo4j graph",
        "use_when": "User asks exploratory questions: 'Find all projects connected to IT systems with high risk'",
        "returns": "Matching subgraphs with scores"
    }
}
```

### 3. **Context Enrichment Pattern**

**Application sends to LLM:**
```json
{
  "user_query": "Show risks affecting Project Atlas through IT systems",
  "pre_resolved_entities": [
    {"type": "project", "id": "PRJ001", "year": 2024, "name": "Project Atlas"}
  ],
  "suggested_tools": ["graph_walk"],
  "complexity_hint": "4-hop query (project→it_systems→risks)",
  "available_paths": [
    "ent_projects → jt_project_it_systems → ent_it_systems → jt_it_system_risks → ent_risks"
  ]
}
```

LLM sees this enriched context and makes better decisions.

### 4. **Maintain 4-Layer Advantages**

**The 4-layer system validation/routing stays intact:**

```python
# Layer 1: Intent Understanding + Reference Resolution
→ Detects composite keys, resolves "that project" → (PRJ001, 2024)

# Layer 2: Hybrid Retrieval (NEW - uses both DBs)
→ Simple query? → Supabase SQL
→ Complex query? → Neo4j graph_walk

# Layer 3: Analytical Reasoning
→ Combines results from SQL + Graph
→ Validates against worldview map

# Layer 4: Visualization
→ Charts from structured data
```

**Validation Rules Still Apply:**
- Composite key enforcement (id, year)
- Worldview map constraints (valid paths only)
- SQL validation before execution

### 5. **Parallel Migration (No Breaking Changes)**

**You can migrate incrementally:**

```
Week 1: Set up Neo4j (empty), test connection
Week 2: Sync entities to Neo4j (ent_projects, ent_capabilities)
Week 3: Add graph tools to OrchestratorV2
Week 4: Test dual queries (SQL + Graph)
Week 5: Production rollout
```

**System works during migration:**
- Neo4j empty? → Falls back to SQL
- Neo4j sync fails? → SQL still works
- New graph tools? → LLM still calls SQL tools

### 6. **One-Prompt Architecture Integration**

**OrchestratorV2 stays one-prompt, just more tools:**

```python
# BEFORE (3 tools)
tools = [search_schema, search_entities, execute_sql]

# AFTER (6 tools)
tools = [
    search_schema,      # Vector search (pgvector)
    search_entities,    # Vector search (pgvector)
    execute_sql,        # SQL queries (Supabase)
    execute_simple_query, # SQL queries (Supabase)
    graph_walk,         # NEW - Graph traversal (Neo4j)
    graph_search        # NEW - Graph pattern match (Neo4j)
]

# Still ONE LLM call, just picks from more tools
```

---

## DATABASE ARCHITECTURE

### Supabase PostgreSQL (Keeps ALL Existing Data)

**What Stays in Supabase:**
- All 18+ entity tables (ent_*)
- All 8 sector tables (sec_*)
- All join tables (jt_*)
- User auth (users, conversations, messages)
- pgvector embeddings (vec_chunks, kg_nodes)

**Why Keep SQL:**
- Transactional integrity (ACID)
- Complex aggregations (SUM, AVG, GROUP BY)
- Temporal queries (year comparisons)
- Existing workflows (no migration risk)

### Neo4j Graph Database (New - Additive)

**What Goes in Neo4j:**
- **Nodes:** Mirror of entity/sector tables
  ```cypher
  CREATE (p:Project {id: 'PRJ001', year: 2024, name: 'Project Atlas'})
  CREATE (c:Capability {id: 'CAP001', year: 2024, name: 'Digital Ops'})
  CREATE (r:Risk {id: 'RSK001', year: 2024, name: 'IT System Failure'})
  ```

- **Relationships:** Mirror of join tables
  ```cypher
  CREATE (p)-[:HAS_CAPABILITY {year: 2024}]->(c)
  CREATE (c)-[:SUPPORTED_BY_IT_SYSTEM {year: 2024}]->(its)
  CREATE (its)-[:HAS_RISK {year: 2024}]->(r)
  ```

- **Properties:** Key attributes only (id, year, name, status)

**Why Add Graph:**
- Multi-hop traversal (3-5+ hops) is 10x faster
- Relationship analytics (pagerank, centrality)
- Pattern matching ("find all risky paths")
- Visual exploration (graph UI)

---

## DATA SYNC STRATEGY

### Option A: Real-Time Sync (Recommended)

**PostgreSQL triggers → Neo4j updates:**

```sql
-- Trigger on ent_projects
CREATE TRIGGER sync_project_to_neo4j
AFTER INSERT OR UPDATE ON ent_projects
FOR EACH ROW
EXECUTE FUNCTION sync_to_neo4j('Project');

-- Function calls Neo4j API
CREATE FUNCTION sync_to_neo4j(node_type TEXT)
RETURNS TRIGGER AS $$
BEGIN
    PERFORM http_post(
        'http://neo4j:7474/sync',
        json_build_object(
            'type', node_type,
            'id', NEW.id,
            'year', NEW.year,
            'data', row_to_json(NEW)
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Pros:** Always in sync, no lag  
**Cons:** Requires pg_http extension

### Option B: Batch Sync (Simpler)

**Nightly sync script:**

```python
# sync_to_neo4j.py
from neo4j import GraphDatabase
import psycopg2

# Connect to both DBs
pg_conn = psycopg2.connect(os.getenv('DATABASE_URL'))
neo4j_driver = GraphDatabase.driver(
    os.getenv('NEO4J_URI'),
    auth=(os.getenv('NEO4J_USER'), os.getenv('NEO4J_PASSWORD'))
)

# Sync projects
projects = pg_conn.execute("SELECT * FROM ent_projects WHERE year = 2024")
for proj in projects:
    neo4j_driver.execute_query("""
        MERGE (p:Project {id: $id, year: $year})
        SET p.name = $name, p.status = $status
    """, id=proj['id'], year=proj['year'], name=proj['name'], status=proj['status'])

# Sync relationships
joins = pg_conn.execute("""
    SELECT project_id, project_year, capability_id, capability_year
    FROM jt_project_capabilities
""")
for j in joins:
    neo4j_driver.execute_query("""
        MATCH (p:Project {id: $pid, year: $pyear})
        MATCH (c:Capability {id: $cid, year: $cyear})
        MERGE (p)-[:HAS_CAPABILITY {year: $pyear}]->(c)
    """, pid=j['project_id'], pyear=j['project_year'], cid=j['capability_id'], cyear=j['capability_year'])
```

**Pros:** Simple, no triggers  
**Cons:** Max 5-minute lag

---

## ENHANCED ORCHESTRATOR V2

### New System Prompt (with Graph Tools)

```python
SYSTEM_PROMPT = """You are JOSOOR, an enterprise transformation analytics assistant.

AVAILABLE TOOLS:

**Vector Search Tools (pgvector on Supabase):**
1. search_schema(query, top_k) - Find database tables/columns
2. search_entities(query, entity_type, top_k) - Find entities semantically

**SQL Tools (Supabase PostgreSQL):**
3. execute_sql(sql, validate, max_rows) - Execute SQL queries
   - USE FOR: Simple queries (1-2 hops), aggregations, filtering
   - EXAMPLE: "Show all projects in 2024"

4. execute_simple_query(table, filters, columns) - Filter single table
   - USE FOR: Basic lookups
   - EXAMPLE: "List active projects"

**Graph Tools (Neo4j):**
5. graph_walk(start_node, relationship_types, max_depth) - Walk graph relationships
   - USE FOR: Complex traversal (3-5+ hops)
   - EXAMPLE: "Find all risks affecting capabilities through projects and IT systems"
   - RETURNS: Paths with nodes and edges

6. graph_search(pattern, filters) - Find matching patterns
   - USE FOR: Exploratory queries
   - EXAMPLE: "Find all projects with high-risk IT systems"
   - RETURNS: Matching subgraphs

**DECISION RULES:**

Simple Query (1-2 hops)? → execute_sql or execute_simple_query
Complex Query (3+ hops)? → graph_walk
Pattern Discovery? → graph_search
Schema Discovery? → search_schema
Entity Resolution? → search_entities

**COMPOSITE KEY RULES:**
- All SQL JOINs must use (id, year)
- All Neo4j relationships include year property
- Example SQL: JOIN ent_capabilities c ON p.id = c.project_id AND p.year = c.year
- Example Cypher: MATCH (p)-[:HAS_CAPABILITY {year: 2024}]->(c)

CURRENT YEAR: 2025
"""
```

### New Graph Service Layer

```python
# backend/app/services/neo4j_service.py
from neo4j import GraphDatabase
from typing import List, Dict, Any, Optional
import os

class Neo4jService:
    """
    Neo4j graph database service for relationship traversal
    """
    
    def __init__(self):
        self.driver = GraphDatabase.driver(
            os.getenv('NEO4J_URI', 'bolt://localhost:7687'),
            auth=(
                os.getenv('NEO4J_USER', 'neo4j'),
                os.getenv('NEO4J_PASSWORD', 'password')
            )
        )
    
    def close(self):
        self.driver.close()
    
    def graph_walk(
        self,
        start_node: Dict[str, Any],  # {id: 'PRJ001', year: 2024, type: 'Project'}
        relationship_types: List[str],  # ['HAS_CAPABILITY', 'SUPPORTED_BY_IT_SYSTEM', 'HAS_RISK']
        max_depth: int = 5
    ) -> Dict[str, Any]:
        """
        Walk graph relationships from start node
        
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
                }
            }
        """
        query = """
        MATCH path = (start {id: $start_id, year: $start_year})
        -[r*1..$max_depth]->(end)
        WHERE ALL(rel in r WHERE type(rel) IN $rel_types AND rel.year = $start_year)
        RETURN path
        LIMIT 100
        """
        
        with self.driver.session() as session:
            result = session.run(
                query,
                start_id=start_node['id'],
                start_year=start_node['year'],
                rel_types=relationship_types,
                max_depth=max_depth
            )
            
            paths = []
            for record in result:
                path = record['path']
                paths.append({
                    "nodes": [dict(node) for node in path.nodes],
                    "relationships": [dict(rel) for rel in path.relationships],
                    "length": len(path)
                })
            
            return {
                "paths": paths,
                "summary": {
                    "total_paths": len(paths),
                    "max_depth_reached": max([p['length'] for p in paths]) if paths else 0,
                    "unique_end_nodes": len(set(p['nodes'][-1]['id'] for p in paths))
                }
            }
    
    def graph_search(
        self,
        pattern: str,  # Cypher pattern like "(p:Project)-[:HAS_RISK]->(r:Risk)"
        filters: Dict[str, Any] = None,  # {year: 2024, status: 'active'}
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        Search for matching patterns in graph
        
        Returns:
            [
                {
                    "match": {...},
                    "score": 0.95
                }
            ]
        """
        # Build WHERE clause from filters
        where_clauses = []
        params = {"limit": limit}
        
        if filters:
            for key, value in filters.items():
                where_clauses.append(f"p.{key} = ${key}")
                params[key] = value
        
        where_str = " AND ".join(where_clauses) if where_clauses else "true"
        
        query = f"""
        MATCH {pattern}
        WHERE {where_str}
        RETURN *
        LIMIT $limit
        """
        
        with self.driver.session() as session:
            result = session.run(query, **params)
            return [dict(record) for record in result]
    
    def get_node_degree(
        self,
        node_id: str,
        year: int,
        direction: str = 'both'  # 'in', 'out', 'both'
    ) -> int:
        """
        Get degree (number of connections) for a node
        """
        if direction == 'in':
            query = "MATCH (n {id: $id, year: $year})<-[r]-() RETURN count(r) as degree"
        elif direction == 'out':
            query = "MATCH (n {id: $id, year: $year})-[r]->() RETURN count(r) as degree"
        else:
            query = "MATCH (n {id: $id, year: $year})-[r]-() RETURN count(r) as degree"
        
        with self.driver.session() as session:
            result = session.run(query, id=node_id, year=year)
            record = result.single()
            return record['degree'] if record else 0
```

### Enhanced OrchestratorV2 with Graph Tools

```python
# backend/app/services/orchestrator_v2.py (ENHANCED)

from app.services.neo4j_service import Neo4jService

class OrchestratorV2:
    """
    ENHANCED - Now with dual database support (Supabase + Neo4j)
    """
    
    def __init__(self):
        self.semantic_search = SemanticSearchService()
        self.sql_executor = SQLExecutorService()
        self.neo4j_service = Neo4jService()  # NEW
        self.llm_provider = LLMProvider()
        self.debug_log = []
    
    def _build_function_tools(self) -> List[Dict[str, Any]]:
        """Build function tools - NOW INCLUDES GRAPH TOOLS"""
        return [
            # Existing tools (vector + SQL)
            self._build_search_schema_tool(),
            self._build_search_entities_tool(),
            self._build_execute_sql_tool(),
            self._build_execute_simple_query_tool(),
            
            # NEW graph tools
            {
                "type": "function",
                "function": {
                    "name": "graph_walk",
                    "description": "Walk graph relationships for complex multi-hop traversal (3-5+ hops). Use when user asks about relationships across multiple entities.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "start_node": {
                                "type": "object",
                                "description": "Starting node with id, year, type",
                                "properties": {
                                    "id": {"type": "string"},
                                    "year": {"type": "integer"},
                                    "type": {"type": "string"}
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
                                "description": "Maximum hops (default: 5)",
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
                    "description": "Search for matching patterns in graph. Use for exploratory queries.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "pattern": {
                                "type": "string",
                                "description": "Cypher pattern like '(p:Project)-[:HAS_RISK]->(r:Risk)'"
                            },
                            "filters": {
                                "type": "object",
                                "description": "Property filters",
                                "additionalProperties": True
                            },
                            "limit": {
                                "type": "integer",
                                "default": 100
                            }
                        },
                        "required": ["pattern"]
                    }
                }
            }
        ]
    
    def _execute_function_call(
        self,
        function_name: str,
        arguments: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Execute function - NOW HANDLES GRAPH TOOLS"""
        
        if function_name in ["search_schema", "search_entities", "execute_sql", "execute_simple_query"]:
            # Existing tools (no changes)
            return super()._execute_function_call(function_name, arguments)
        
        elif function_name == "graph_walk":
            # NEW - Graph traversal
            result = self.neo4j_service.graph_walk(
                start_node=arguments['start_node'],
                relationship_types=arguments['relationship_types'],
                max_depth=arguments.get('max_depth', 5)
            )
            return {
                "success": True,
                "data": result,
                "tool": "graph_walk"
            }
        
        elif function_name == "graph_search":
            # NEW - Graph pattern search
            result = self.neo4j_service.graph_search(
                pattern=arguments['pattern'],
                filters=arguments.get('filters', {}),
                limit=arguments.get('limit', 100)
            )
            return {
                "success": True,
                "data": result,
                "tool": "graph_search"
            }
        
        else:
            return {
                "success": False,
                "error": f"Unknown function: {function_name}"
            }
```

### Pre-Processing Layer (Prep Work)

```python
# backend/app/services/query_preprocessor.py (NEW)

class QueryPreprocessor:
    """
    Pre-processes user queries to enrich context BEFORE LLM call
    
    This is the "prep work" that makes LLM smarter
    """
    
    def __init__(
        self,
        semantic_search: SemanticSearchService,
        neo4j_service: Neo4jService,
        conversation_manager: ConversationManager
    ):
        self.semantic_search = semantic_search
        self.neo4j = neo4j_service
        self.conv_manager = conversation_manager
    
    async def preprocess(
        self,
        user_query: str,
        conversation_id: str
    ) -> Dict[str, Any]:
        """
        Pre-process query to build enriched context
        
        Returns:
            {
                "entities_found": [...],
                "suggested_tools": ["graph_walk"],
                "complexity_score": 4,
                "available_paths": [...],
                "conversation_context": "..."
            }
        """
        enriched_context = {
            "entities_found": [],
            "suggested_tools": [],
            "complexity_score": 0,
            "available_paths": [],
            "conversation_context": ""
        }
        
        # 1. Entity resolution via vector search
        entity_results = await self.semantic_search.search_entities(
            query=user_query,
            top_k=3
        )
        
        for ent in entity_results.get('entities', []):
            enriched_context['entities_found'].append({
                "id": ent['id'],
                "year": ent['year'],
                "type": ent['type'],
                "name": ent['name'],
                "similarity": ent['similarity']
            })
        
        # 2. Graph degree check (how connected are these entities?)
        if enriched_context['entities_found']:
            first_entity = enriched_context['entities_found'][0]
            degree = self.neo4j.get_node_degree(
                node_id=first_entity['id'],
                year=first_entity['year']
            )
            enriched_context['complexity_score'] = min(degree // 2, 5)  # Rough estimate
        
        # 3. Suggest tools based on complexity
        if enriched_context['complexity_score'] >= 3:
            enriched_context['suggested_tools'] = ["graph_walk"]
        else:
            enriched_context['suggested_tools'] = ["execute_sql"]
        
        # 4. Conversation context
        enriched_context['conversation_context'] = await self.conv_manager.build_conversation_context(
            conversation_id=conversation_id,
            max_messages=5
        )
        
        return enriched_context
```

### Enhanced Process Flow

```python
# backend/app/services/orchestrator_v2.py (process_query method)

async def process_query(
    self,
    user_query: str,
    conversation_id: str,
    user_id: int,
    persona: str = "transformation_analyst"
):
    """
    ENHANCED - With pre-processing and enriched context
    """
    
    # STEP 0: Store user message
    await self.conversation_manager.add_message(
        conversation_id=conversation_id,
        role="user",
        content=user_query
    )
    
    # STEP 1: PRE-PROCESS (THE PREP WORK)
    preprocessor = QueryPreprocessor(
        self.semantic_search,
        self.neo4j_service,
        self.conversation_manager
    )
    
    enriched_context = await preprocessor.preprocess(
        user_query=user_query,
        conversation_id=conversation_id
    )
    
    # STEP 2: Build enhanced messages for LLM
    messages = [
        {
            "role": "system",
            "content": self.SYSTEM_PROMPT + f"""

## PRE-RESOLVED CONTEXT
Entities Found: {enriched_context['entities_found']}
Suggested Tools: {enriched_context['suggested_tools']}
Query Complexity: {enriched_context['complexity_score']} hops
Conversation History: {enriched_context['conversation_context']}

Use this context to make better tool selection decisions."""
        },
        {
            "role": "user",
            "content": user_query
        }
    ]
    
    # STEP 3: Call LLM with function calling (existing code)
    client = self._get_openai_client()
    tools = self._build_function_tools()
    
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        tools=tools,
        tool_choice="auto"
    )
    
    # STEP 4-6: Execute tools, format response, store (existing code)
    # ... rest of process_query logic unchanged ...
```

---

## MIGRATION TIMELINE

### Week 1: Setup & Infrastructure
- **Day 1-2:** Set up Neo4j instance (local or cloud)
- **Day 3:** Install Neo4j Python driver, test connection
- **Day 4-5:** Create `neo4j_service.py` with basic operations

### Week 2: Data Sync
- **Day 1-2:** Implement batch sync script
- **Day 3:** Sync entity tables (ent_projects, ent_capabilities)
- **Day 4:** Sync relationships (jt_* tables)
- **Day 5:** Verify data integrity (node counts, relationship counts)

### Week 3: Orchestrator Enhancement
- **Day 1-2:** Add graph tools to OrchestratorV2
- **Day 3:** Update SYSTEM_PROMPT with tool descriptions
- **Day 4:** Implement QueryPreprocessor
- **Day 5:** Test dual queries (SQL + Graph)

### Week 4: Testing & Optimization
- **Day 1-2:** Test multi-hop queries (3-5 hops)
- **Day 3:** Performance benchmarks (SQL vs Graph)
- **Day 4:** Fix bugs, optimize queries
- **Day 5:** Documentation updates

### Week 5: Production Rollout
- **Day 1-2:** Deploy to staging
- **Day 3:** User acceptance testing
- **Day 4:** Production deployment
- **Day 5:** Monitor, iterate

---

## TESTING STRATEGY

### Test Case 1: Simple Query (SQL)
```
User: "Show all projects in 2024"
Expected: LLM calls execute_sql (not graph_walk)
```

### Test Case 2: Complex Query (Graph)
```
User: "Find all risks affecting capabilities through projects and IT systems"
Expected: LLM calls graph_walk with 4-hop depth
```

### Test Case 3: Hybrid Query (Both)
```
User: "Show project budgets and their connected risks"
Expected: 
  1. execute_sql for budget data (aggregation)
  2. graph_walk for connected risks
  3. Combine results
```

### Test Case 4: Pre-Processing
```
User: "What risks does that project have?"
Expected:
  1. QueryPreprocessor resolves "that project" from conversation
  2. Finds PRJ001, 2024 via vector search
  3. LLM receives enriched context: "User refers to Project Atlas (PRJ001, 2024)"
```

---

## SUCCESS METRICS

| Metric | Before (SQL Only) | Target (Dual DB) | Measurement |
|--------|-------------------|------------------|-------------|
| Multi-hop query success (3+ hops) | <10% | >95% | Test suite |
| Query response time (complex) | 5-10s | 1-2s | Benchmarks |
| LLM tool selection accuracy | 60% | 90% | Manual review |
| Composite key compliance | 100% | 100% | SQL validator |
| Reference resolution accuracy | 85% | 95% | Test suite |

---

## ROLLBACK PLAN

If migration fails, rollback is simple:

```python
# In orchestrator_v2.py
USE_GRAPH = os.getenv('ENABLE_NEO4J', 'false') == 'true'

if USE_GRAPH:
    # Use graph tools
    self.neo4j_service = Neo4jService()
else:
    # Fall back to SQL only
    self.neo4j_service = None

# In _execute_function_call
if function_name == "graph_walk" and not self.neo4j_service:
    # Fallback to SQL-based multi-hop query
    return self._fallback_sql_multihop(arguments)
```

Set `ENABLE_NEO4J=false` → System reverts to SQL-only mode.

---

## COST ANALYSIS

### Neo4j Hosting Options

**Option 1: Neo4j Aura (Cloud)**
- Free tier: 200K nodes, 400K relationships
- Pro tier: $65/month (starts at 2M nodes)
- Enterprise: $360/month (unlimited)

**Option 2: Self-Hosted (Docker)**
- Replit VM: Free (resource-limited)
- AWS EC2: ~$50/month (t3.medium)
- Cost: Only compute, no storage fees

**Recommendation:** Start with Aura Free, migrate to Pro when you hit limits.

### Total Cost Impact

| Component | Current | With Neo4j | Delta |
|-----------|---------|------------|-------|
| Supabase | $25/month | $25/month | $0 |
| OpenAI | ~$100/month | ~$100/month | $0 |
| Neo4j | $0 | $0-$65/month | +$0-$65 |
| **Total** | **$125/month** | **$125-$190/month** | **+$0-$65** |

**ROI:** 10x faster complex queries, better user experience → Worth the investment.

---

## APPENDIX A: Neo4j Setup Guide

### Local Setup (Docker)

```bash
# Pull Neo4j image
docker pull neo4j:5.15

# Run Neo4j container
docker run \
    --name josoor-neo4j \
    -p 7474:7474 -p 7687:7687 \
    -e NEO4J_AUTH=neo4j/your_password \
    -v $PWD/neo4j-data:/data \
    neo4j:5.15

# Access browser: http://localhost:7474
```

### Replit Setup

```python
# .replit
[env]
NEO4J_URI = "bolt://localhost:7687"
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = "your_password"

# requirements.txt
neo4j==5.15.0
```

---

## APPENDIX B: Sample Graph Queries

### Query 1: Find All Risks for Project Atlas

```cypher
MATCH path = (p:Project {id: 'PRJ001', year: 2024})
-[:HAS_CAPABILITY]->(:Capability)
-[:SUPPORTED_BY_IT_SYSTEM]->(:ITSystem)
-[:HAS_RISK]->(r:Risk)
RETURN path
```

### Query 2: Find High-Risk Projects

```cypher
MATCH (p:Project)-[*1..5]->(r:Risk)
WHERE r.risk_score > 0.7
RETURN p.id, p.name, count(r) as risk_count
ORDER BY risk_count DESC
LIMIT 10
```

### Query 3: Find Shortest Path Between Entities

```cypher
MATCH path = shortestPath(
  (start:Project {id: 'PRJ001'})-[*]-(end:Performance {id: 'PERF001'})
)
RETURN path
```

---

## APPENDIX C: Composite Key Handling in Neo4j

**Challenge:** Neo4j doesn't have native composite keys  
**Solution:** Use year as relationship property

```cypher
// WRONG (no year tracking)
CREATE (p:Project {id: 'PRJ001'})
CREATE (c:Capability {id: 'CAP001'})
CREATE (p)-[:HAS_CAPABILITY]->(c)

// CORRECT (year in relationship)
CREATE (p:Project {id: 'PRJ001', year: 2024})
CREATE (c:Capability {id: 'CAP001', year: 2024})
CREATE (p)-[:HAS_CAPABILITY {year: 2024}]->(c)

// Query with year filter
MATCH (p:Project {id: 'PRJ001', year: 2024})
-[r:HAS_CAPABILITY {year: 2024}]->(c:Capability)
RETURN c
```

---

## SUMMARY

**What This Plan Delivers:**

1. ✅ **Dual Database Architecture** - Supabase (SQL) + Neo4j (Graph)
2. ✅ **Prep Work Pattern** - Application pre-queries data before LLM call
3. ✅ **Enhanced Tool Descriptions** - LLM knows WHEN to use each tool
4. ✅ **Context Enrichment** - LLM receives pre-resolved entities + graph hints
5. ✅ **4-Layer Advantages Preserved** - Validation + routing still work
6. ✅ **Parallel Migration** - Incremental, no breaking changes
7. ✅ **One-Prompt Architecture** - OrchestratorV2 stays single LLM call

**Next Steps:**

1. Review this plan
2. Confirm Neo4j hosting choice (Aura Free vs self-hosted)
3. Implement Week 1 (infrastructure setup)
4. Test dual queries
5. Measure success metrics

---

**Document Status:** ✅ COMPLETE - Ready for implementation

**Version:** 2.0  
**Last Updated:** January 2025
