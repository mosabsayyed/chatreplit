# JOSOOR - Transformation Analytics Platform with Living Digital Twin

## Project Overview
JOSOOR is an enterprise transformation analytics platform featuring an **autonomous AI agent fused with a living Digital Twin (DTDL)**. The platform combines structured enterprise data, knowledge graph relationships, and semantic understanding to provide intelligent transformation intelligence.

## Architecture - Digital Twin + GenAI Fusion

### The Innovation: Living Digital Twin
Your system implements a **graph-based Digital Twin** that animates enterprise transformation data using GenAI:

**Digital Twin Definition Language (DTDL) via Knowledge Graph:**
- **kg_nodes** (34,409 nodes): Entities in the digital twin with temporal validity
  - Types: ent_projects, ent_capabilities, ent_risks, sec_objectives, etc.
  - Properties stored as JSONB
  - Valid_from/valid_to for temporal knowledge
  
- **kg_edges** (42,084 edges): Relationships between entities
  - 10,224 edges: capabilities ↔ processes
  - 8,460 edges: capabilities ↔ org units
  - 7,848 edges: org units ↔ culture health
  - 5,112 edges: projects ↔ change adoption
  - Rich relationship metadata

- **vec_chunks**: Vector embeddings (1536-dim OpenAI) for semantic search
  - Links to kg_nodes for context-aware RAG
  - Enables semantic queries over the digital twin

### Backend (FastAPI + Python)
- **FastAPI Application**: REST API with automatic OpenAPI documentation at `/docs`
- **PostgreSQL Database**: 51 tables total
  - 9 Entity tables (ent_*): capabilities, projects, it_systems, org_units, processes, risks, change_adoption, culture_health, vendors
  - 8 Sector tables (sec_*): objectives, performance, policy_tools, citizens, businesses, gov_entities, data_transactions, admin_records
  - 28 Join tables (jt_*): Many-to-many relationships
  - **3 Knowledge Graph tables**: kg_nodes, kg_edges, vec_chunks (Digital Twin!)
  
- **Real Enterprise Data Loaded**:
  - 284 projects (from 2026-2028)
  - 391 capabilities across 3 levels (L1, L2, L3)
  - 930 IT systems
  - 25 strategic objectives
  - Hierarchical IDs: VARCHAR(10) format like "1.0", "2.1", "3.2.1"

### AI Agent Architecture (Dual Implementation)

#### Legacy: 4-Layer Autonomous Analytical Agent
1. **IntentUnderstandingMemory**: Extracts intent, entities, and time period from questions
2. **HybridRetrievalMemory**: Retrieves data from:
   - Structured tables (ent_*, sec_*, jt_*)
   - Knowledge graph nodes (kg_nodes)
   - Knowledge graph relationships (kg_edges)
   - Vector similarity search (vec_chunks) - when populated
3. **AnalyticalReasoningMemory**: Generates insights and recommendations using LLM
4. **VisualizationGenerationMemory**: Creates visualizations (matplotlib charts)

**Endpoint:** `POST /api/v1/chat/message`

#### NEW: Single-Layer Orchestrator with pgvector (V2) ⚡
**75% cost reduction** - Replaces 4 LLM calls with 1 LLM call using pgvector semantic search

**Architecture:**
```
User Query → Single LLM with Function Calling
  ├→ Tool: search_schema(query) → pgvector similarity on tables/columns
  ├→ Tool: search_entities(query, type) → pgvector similarity on entities
  ├→ Tool: execute_sql(sql) → Validated SQL execution
  └→ Returns: Natural language answer
```

**Key Features:**
- **OpenAI Function Calling**: LLM orchestrates semantic search and SQL execution
- **pgvector Semantic Search**: 1536-dim embeddings with IVFFlat indexes
- **Composite Key Validation**: Ensures all JOINs include (id, year)
- **Conversation History**: Multi-turn conversations with database persistence
- **Debug Logging**: Function calls, tool results, iteration tracking

**Endpoint:** `POST /api/v1/chat/message/v2`

**Infrastructure:**
- `schema_embeddings` table: Tables, columns, worldview relationships
- `entity_embeddings` table: All entities (projects, capabilities, objectives, etc.)
- `SemanticSearchService`: Unified search interface
- `SQLExecutorService`: Validated query execution
- `OrchestratorV2`: Single LLM with function calling loop

### Switchable LLM Provider
- **Replit AI Integrations** (default) - pre-configured
- **OpenAI** - requires OPENAI_API_KEY
- **Anthropic** - requires ANTHROPIC_API_KEY

### Frontend (HTML/CSS/JavaScript)
- Purple gradient chat interface matching JOSOOR brand
- Suggestion buttons for common queries
- Real-time responses from autonomous agent
- Visualization rendering (base64 encoded images)

## API Endpoints

### Agent Endpoint
**POST /api/v1/agent/ask**
```json
{
  "question": "What are the transformation projects for 2028?",
  "context": null
}
```

Response includes:
- `narrative`: Detailed analytical narrative generated from real data
- `visualizations`: Array of charts (base64 encoded)
- `confidence`: Confidence level and score
- `metadata`: Intent, data sources (including kg_nodes, kg_edges), timestamp

### Health Check
**GET /api/v1/health/check**

Returns system health status and database connectivity.

## LLM Provider Configuration

### Replit AI Integrations (Default)
```bash
LLM_PROVIDER=replit
# Uses AI_INTEGRATIONS_OPENAI_API_KEY and AI_INTEGRATIONS_OPENAI_BASE_URL (auto-configured)
```

### OpenAI
```bash
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1  # optional
```

### Anthropic
```bash
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
# Note: pip install anthropic required
```

## Example Queries (Using Real Data)

**2028 Transformation Projects:**
- "What are the transformation projects for 2028?"
  - Response: Sustainability & compliance, Capability Building, Digital platforms for environmental monitoring
  
**Capabilities Analysis:**
- "Show me capabilities with low maturity levels"
- "Which capabilities need the most improvement?"

**Strategic Insights:**
- "What are the key strategic objectives?"
- "How are projects aligned with objectives?"

**Knowledge Graph Queries:**
- "Show me relationships between projects and change adoption"
- "Which processes are linked to specific capabilities?"

## Real Data Statistics
- **Projects**: 284 (hierarchical structure with L1, L2, L3 levels)
- **Capabilities**: 391 (with maturity levels 1-5)
- **IT Systems**: 930
- **Strategic Objectives**: 25
- **Knowledge Graph Nodes**: 34,409
- **Knowledge Graph Edges**: 42,084
- **Years Covered**: 2024-2028

## Project Structure
```
backend/
├── app/
│   ├── main.py              # FastAPI application
│   ├── config.py            # Configuration management
│   ├── models/
│   │   └── schemas.py       # Pydantic schemas
│   ├── db/
│   │   └── postgres_client.py  # Database client + KG queries
│   ├── services/
│   │   ├── llm_provider.py     # Switchable LLM provider
│   │   └── autonomous_agent.py # 4-layer agent with KG integration
│   └── api/v1/
│       ├── agent.py         # Agent endpoints
│       └── health.py        # Health check
└── requirements.txt         # Python dependencies

frontend/
└── index.html               # Chat interface

db_dump/
├── remote_supabase_dump.sql # Original schema (51 tables)
└── remote_supabase_data.sql # Real data (33MB)
```

## Recent Changes (October 25, 2025)
- ✅ **Loaded complete real database** (51 tables, 33MB of data)
- ✅ **Installed pgvector extension** for vector similarity search
- ✅ **Knowledge graph integration**: 34k+ nodes, 42k+ edges
- ✅ **Updated backend** to use actual schema (VARCHAR IDs, correct column names)
- ✅ **Enhanced autonomous agent** with KG queries
- ✅ **Tested with real 2028 data** - generating intelligent insights from actual transformation projects
- ✅ **Configured Replit workflow** on port 5000
- ✅ **Switchable LLM provider** (Replit AI/OpenAI/Anthropic)

## The Digital Twin Vision

Your architecture represents a **paradigm shift** in enterprise transformation analytics:

1. **Structured Data**: Traditional entity tables (ent_*, sec_*)
2. **Graph Relationships**: Knowledge graph connecting 34k+ nodes via 42k+ edges
3. **Semantic Layer**: Vector embeddings for natural language understanding
4. **GenAI Intelligence**: Autonomous agent that "animates" the digital twin
5. **Temporal Knowledge**: Valid_from/valid_to tracking for historical analysis

This fusion creates a **living, queryable representation** of your enterprise transformation that:
- Understands natural language questions
- Traces relationships across dimensions
- Provides temporal insights
- Generates visualizations on-demand
- Learns from interactions

## User Preferences
- Real enterprise data loaded from Supabase dumps
- Hierarchical ID system (1.0, 2.1, 3.2.1) maintained
- Knowledge graph (DTDL) is **central to the design** - not optional
- Focus on autonomous agent chat interface for demo
- Use Replit AI Integrations for testing (default)

## V2 Architecture Next Steps

**Current Status:** ✅ Core implementation complete, architect-reviewed

**To activate the V2 single-layer orchestrator:**

1. **Populate Embeddings** (Required before testing):
   ```bash
   # Configure OpenAI API key (or use Replit AI Integrations)
   # Then call the embedding population endpoint:
   curl -X POST http://localhost:5000/api/v1/embeddings/populate/all
   ```
   
   This will:
   - Generate embeddings for all schema elements (tables, columns, worldview)
   - Generate embeddings for all entities (projects, capabilities, objectives, etc.)
   - Insert ~1000+ vectors into pgvector tables
   - Enable semantic search functionality

2. **Test the V2 Endpoint**:
   ```bash
   curl -X POST http://localhost:5000/api/v1/chat/message/v2 \
     -H "Content-Type: application/json" \
     -d '{"query": "What projects are planned for 2027?"}'
   ```

3. **Migration Path**:
   - V1 (4-layer): `/api/v1/chat/message` (legacy, stays active)
   - V2 (1-layer): `/api/v1/chat/message/v2` (new, parallel implementation)
   - Both endpoints use same database and conversation management
   - Easy rollback if issues arise

**Benefits of V2:**
- 75% cost reduction (1 LLM call vs 4)
- Faster response times (single round-trip)
- Better handling of fuzzy entity references
- Automatic schema discovery
- Structured outputs guaranteed via Pydantic

## Future Enhancements
- **Dashboard generation**: 4-zone visualization (spider charts, bubble charts, bullet charts, combo charts)
- **Enhanced KG queries**: More sophisticated relationship traversal
- **Predictive analytics**: Leverage temporal data for forecasting
- **Real-time data ingestion**: API endpoints for continuous updates
- **Vector search optimization**: HNSW index for faster similarity queries
- **V2 visualization support**: Extract data from function call results for charts
- **Advanced debug panel**: Interactive function call inspection
