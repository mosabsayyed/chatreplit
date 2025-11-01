# JOSOOR - Transformation Analytics Platform with Living Digital Twin

## Overview
JOSOOR is an enterprise transformation analytics platform designed to provide intelligent transformation insights. It features an autonomous AI agent integrated with a living Digital Twin Definition Language (DTDL) powered by a knowledge graph. The platform processes structured enterprise data, understands semantic relationships, and generates analytical narratives and visualizations to support organizational transformation initiatives. JOSOOR aims to provide a dynamic, queryable representation of enterprise transformation, enabling natural language interaction, temporal analysis, and on-demand visualization.

## User Preferences
- Real enterprise data loaded from Supabase dumps
- Hierarchical ID system (1.0, 2.1, 3.2.1) maintained
- Knowledge graph (DTDL) is **central to the design** - not optional
- Focus on autonomous agent chat interface for demo
- Use Replit AI Integrations for testing (default)

## System Architecture

### Core Design Principles
The platform is built around a **graph-based Digital Twin** that animates enterprise transformation data using Generative AI. This involves fusing structured data with knowledge graph relationships and semantic understanding.

### Digital Twin + GenAI Fusion
- **Digital Twin Definition Language (DTDL) via Knowledge Graph**:
    - `kg_nodes`: Entities with temporal validity (e.g., projects, capabilities, risks, objectives).
    - `kg_edges`: Relationships between entities with rich metadata.
    - `vec_chunks`: Vector embeddings (1536-dim OpenAI) for semantic search and context-aware RAG.

### Backend (FastAPI + Python)
- **FastAPI Application**: Provides RESTful APIs and automatic OpenAPI documentation.
- **PostgreSQL Database**: Stores 51 tables, including entity tables (`ent_*`), sector tables (`sec_*`), join tables (`jt_*`), and dedicated knowledge graph tables (`kg_nodes`, `kg_edges`, `vec_chunks`).
- **Dual Database Architecture**: Combines Supabase PostgreSQL for ACID transactions, complex aggregations, and `pgvector` embeddings with Neo4j for multi-hop graph traversal, relationship analytics, and pattern matching.
    - **PostgreSQL (Primary)**: All core enterprise data, `pgvector` for semantic search.
    - **Neo4j (Additive)**: Mirrors entities and relationships for optimized graph operations.
    - **Data Sync**: Batch and incremental sync mechanisms between PostgreSQL and Neo4j.
    - **Graceful Degradation**: System functions even if Neo4j is unavailable, falling back to SQL-only mode.

### AI Agent Architecture (OrchestratorV2)
A single-layer orchestrator utilizing OpenAI Function Calling for efficient tool orchestration and reduced LLM calls.
- **Tools**:
    - **Vector Search (pgvector)**: `search_schema()`, `search_entities()` for semantic discovery.
    - **SQL Tools (Supabase)**: `execute_sql()`, `execute_simple_query()` for structured data queries.
    - **Graph Tools (Neo4j)**: `graph_walk()`, `graph_search()` for complex multi-hop traversal and pattern discovery.
- **Query Preprocessor**: Enriches context (entity resolution, graph pre-queries) before LLM calls.
- **Composite Key Validation**: Ensures all JOINs include `(id, year)`.
- **Conversation History**: Multi-turn conversation management.

### Frontend (HTML/CSS/JavaScript)
- **Chat Interface**: Purple gradient design, suggestion buttons, real-time responses.
- **Canvas Workspace**: A 3-mode responsive layout (Hidden, Collapsed, Expanded, Fullscreen) for enterprise artifacts.
    - **ChartRenderer**: Integrates Highcharts for 6 chart types (Spider/Radar, Bubble, Bullet, Column, Line, Combo) with export functionality.
    - **Artifact Types**: Supports CHART, REPORT, TABLE, DOCUMENT.

### API Endpoints
- `POST /api/v1/agent/ask`: Primary agent endpoint for questions, returning narrative, visualizations, and metadata.
- `POST /api/v1/chat/message/v2`: V2 agent endpoint for questions.
- `GET /api/v1/health/check`: System health status.
- `POST /api/v1/sync/neo4j/all`, `POST /api/v1/sync/neo4j/incremental`: Data synchronization endpoints for Neo4j.
- `POST /api/v1/embeddings/populate/all`: Populates `pgvector` embeddings.

## External Dependencies
- **PostgreSQL**: Primary database for all enterprise data and `pgvector` embeddings.
- **Neo4j**: Graph database for complex relationship traversal and graph analytics.
- **Replit AI Integrations / OpenAI / Anthropic**: Configurable Large Language Model providers.
- **Highcharts**: JavaScript library for rendering interactive charts in the frontend.
- **Supabase**: Used for database hosting (PostgreSQL) and potentially other services in the future.