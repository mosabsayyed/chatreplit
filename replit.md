# JOSOOR - Transformation Analytics Platform

## Project Overview
JOSOOR is an enterprise transformation analytics platform with an autonomous AI agent for intelligent data analysis over structured enterprise data. The platform provides a 4-layer autonomous analytical agent that processes natural language questions and generates insights with visualizations.

## Architecture

### Backend (FastAPI + Python)
- **FastAPI Application**: REST API with automatic OpenAPI documentation at `/docs`
- **PostgreSQL Database**: 18+ entity tables (ent_*), 8 sector tables (sec_*), join tables for relationships
- **Autonomous AI Agent**: 4-layer architecture:
  1. **IntentUnderstandingMemory**: Extracts intent, entities, and time period from questions
  2. **HybridRetrievalMemory**: Retrieves relevant data from PostgreSQL
  3. **AnalyticalReasoningMemory**: Generates insights and recommendations using LLM
  4. **VisualizationGenerationMemory**: Creates visualizations (matplotlib charts)
- **Switchable LLM Provider**: Supports Replit AI Integrations (default), OpenAI, and Anthropic

### Frontend (HTML/CSS/JavaScript)
- Beautiful purple gradient chat interface
- Suggestion buttons for common queries
- Real-time responses from autonomous agent
- Visualization rendering (base64 encoded images)

### Database Schema
Located in `backend/db_schema.sql`:
- **Entity Tables**: ent_capabilities, ent_projects, ent_it_systems, ent_org_units, ent_processes, ent_risks, ent_change_adoption, ent_culture_health, ent_vendors
- **Sector Tables**: sec_objectives, sec_performance, sec_policy_tools, sec_citizens, sec_businesses, sec_gov_entities, sec_data_transactions, sec_admin_records
- **Join Tables**: For many-to-many relationships between entities
- **Indices**: Performance optimization on year, level, status, score fields

## API Endpoints

### Agent Endpoint
**POST /api/v1/agent/ask**
```json
{
  "question": "What is the project progress for 2024?",
  "context": null
}
```

Response includes:
- `narrative`: Detailed analytical narrative
- `visualizations`: Array of charts (base64 encoded)
- `confidence`: Confidence level and score
- `metadata`: Intent, data sources, timestamp

### Health Check
**GET /api/v1/health/check**

Returns system health status and database connectivity.

## LLM Provider Configuration

The system supports multiple LLM providers, configurable via the `LLM_PROVIDER` environment variable:

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

## Sample Data
The database includes sample data for 2024:
- 5 projects (Digital Transformation Initiative, Cloud Migration Phase 3, etc.)
- 5 capabilities (Digital Strategy, Data Management, Cloud Infrastructure, etc.)
- 3 strategic objectives (Digital Service Adoption, Reduce Manual Processes, etc.)

## Development

### Local Setup
1. Install dependencies: `pip install -r backend/requirements.txt`
2. Database is auto-configured via Replit PostgreSQL
3. Run server: `cd backend && uvicorn app.main:app --host 0.0.0.0 --port 5000 --reload`
4. Access UI at: http://localhost:5000

### Testing the Agent
Example questions:
- "What is the overall transformation health for 2024?"
- "Show me project progress for digital initiatives"
- "Which capabilities have the lowest maturity?"
- "What are the strategic objectives for 2024?"

## Project Structure
```
backend/
├── app/
│   ├── main.py              # FastAPI application
│   ├── config.py            # Configuration management
│   ├── models/
│   │   └── schemas.py       # Pydantic schemas
│   ├── db/
│   │   └── postgres_client.py  # Database client
│   ├── services/
│   │   ├── llm_provider.py     # Switchable LLM provider
│   │   └── autonomous_agent.py # 4-layer agent
│   └── api/v1/
│       ├── agent.py         # Agent endpoints
│       └── health.py        # Health check
├── db_schema.sql            # Database schema
└── requirements.txt         # Python dependencies

frontend/
└── index.html               # Chat interface
```

## Recent Changes (October 25, 2025)
- ✅ Implemented complete database schema with 18+ tables
- ✅ Built 4-layer autonomous analytical agent
- ✅ Implemented switchable LLM provider (Replit AI/OpenAI/Anthropic)
- ✅ Created beautiful chat interface
- ✅ Populated sample data for testing
- ✅ Configured Replit workflow
- ✅ Tested end-to-end functionality with Replit AI Integrations

## User Preferences
- Use Replit AI Integrations for testing (default)
- Make LLM provider switchable to any other model (OpenAI, Anthropic)
- Focus on immediate prototype/demo deployment
- Autonomous analytical agent chat interface is top priority

## Future Enhancements
- Dashboard generation service with 4 zones (Zone 1: Transformation Health spider chart, Zone 2: Strategic Insights bubble chart, Zone 3: Internal Outputs bullet charts, Zone 4: Sector Outcomes combo chart)
- Drill-down capabilities
- Vector search integration for unstructured documents
- Enhanced visualization generation
- Real-time data ingestion endpoints
