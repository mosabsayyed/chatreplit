# DATABASE FOUNDATION

## META

**Dependencies:** None (foundation layer)  
**Provides:** Complete PostgreSQL schema, world-view map configuration, migration scripts  
**Integration Points:** All components depend on this database structure

---

## OVERVIEW

This document contains the complete database foundation for the JOSOOR platform. The schema is designed to support:

1. **Time-series organizational data** with composite keys (id, year)
2. **Hierarchical relationships** (L1/L2/L3 levels) with parent-child references
3. **Many-to-many relationships** via join tables (jt_*)
4. **Graph navigation constraints** via world-view map configuration
5. **User management** for auth and session tracking
6. **AI persona management** for multi-persona chat system
7. **Conversation and artifact persistence** for chat + canvas features

### Key Design Principles

- **Composite Primary Keys:** All entity/sector tables use `(id, year)` for historical tracking
- **Self-Referential Hierarchies:** Parent relationships maintain (parent_id, parent_year) foreign keys
- **Level Matching:** L1 entities can only link to L1 entities (enforced by world-view map)
- **Join Table Pattern:** Many-to-many relationships use `jt_[table1]_[table2]_join` naming convention
- **Immutable History:** Updates create new year entries, old data preserved

---

## ARCHITECTURE

### Entity-Relationship Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENTITY TABLES (ent_*)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Capabilities │  │   Projects   │  │  IT Systems  │          │
│  │  (id, year)  │  │  (id, year)  │  │  (id, year)  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Org Units   │  │   Processes  │  │     Risks    │          │
│  │  (id, year)  │  │  (id, year)  │  │  (id, year)  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Change Adopt │  │Culture Health│  │   Vendors    │          │
│  │  (id, year)  │  │  (id, year)  │  │  (id, year)  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              ↕ (via join tables)
┌─────────────────────────────────────────────────────────────────┐
│                    SECTOR TABLES (sec_*)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Objectives  │  │ Performance  │  │Policy Tools  │          │
│  │  (id, year)  │  │  (id, year)  │  │  (id, year)  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Citizens   │  │  Businesses  │  │ Gov Entities │          │
│  │  (id, year)  │  │  (id, year)  │  │  (id, year)  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│  ┌──────────────┐  ┌──────────────┐                             │
│  │Data Transact │  │Admin Records │                             │
│  │  (id, year)  │  │  (id, year)  │                             │
│  └──────────────┘  └──────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                  USER & SESSION MANAGEMENT                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │    Users     │  │Conversations │  │   Messages   │          │
│  │     (id)     │  │     (id)     │  │     (id)     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                     AI PERSONA MANAGEMENT                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Personas   │  │ Tool Configs │  │Knowledge Files│         │
│  │     (id)     │  │     (id)     │  │     (id)     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────┐
│                      CANVAS ARTIFACTS                            │
│  ┌──────────────┐  ┌──────────────┐                             │
│  │  Artifacts   │  │Artifact Vers │                             │
│  │     (id)     │  │     (id)     │                             │
│  └──────────────┘  └──────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## DATABASE SCHEMA

### Part 1: Entity Tables (ent_*)

```sql
-- =====================================================
-- ENTITY TABLES: Internal organizational components
-- All use composite key (id, year) for time-series tracking
-- =====================================================

-- Enterprise Capabilities (business capabilities)
CREATE TABLE ent_capabilities (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),  -- Q1, Q2, Q3, Q4
    level VARCHAR(2) NOT NULL,  -- L1, L2, L3 (hierarchy level)
    parent_id INTEGER,
    parent_year INTEGER,
    capability_name VARCHAR(255) NOT NULL,
    maturity_level INTEGER CHECK (maturity_level BETWEEN 1 AND 5),
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_capabilities(id, year)
);

-- Projects (transformation initiatives)
CREATE TABLE ent_projects (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    project_name VARCHAR(255) NOT NULL,
    project_type VARCHAR(100),  -- 'digital', 'cloud_migration', 'process_reengineering'
    status VARCHAR(50),  -- 'planning', 'in_progress', 'completed', 'on_hold', 'cancelled'
    start_date DATE,
    completion_date DATE,
    budget_allocated DECIMAL(15,2),
    budget_spent DECIMAL(15,2),
    progress_percentage INTEGER CHECK (progress_percentage BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_projects(id, year)
);

-- IT Systems (technology infrastructure)
CREATE TABLE ent_it_systems (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    system_name VARCHAR(255) NOT NULL,
    system_type VARCHAR(100),  -- 'cloud', 'legacy', 'hybrid', 'saas'
    system_category VARCHAR(100),  -- 'erp', 'crm', 'data_platform', 'infrastructure'
    deployment_date DATE,
    uptime_percentage DECIMAL(5,2),
    health_score INTEGER CHECK (health_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_it_systems(id, year)
);

-- Organizational Units (departments, teams)
CREATE TABLE ent_org_units (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    unit_name VARCHAR(255) NOT NULL,
    unit_type VARCHAR(100),  -- 'department', 'division', 'team', 'office'
    headcount INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_org_units(id, year)
);

-- Processes (business processes)
CREATE TABLE ent_processes (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    process_name VARCHAR(255) NOT NULL,
    process_category VARCHAR(100),  -- 'core', 'support', 'management'
    automation_level VARCHAR(50),  -- 'manual', 'semi_automated', 'fully_automated'
    efficiency_score INTEGER CHECK (efficiency_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_processes(id, year)
);

-- Risks (transformation risks)
CREATE TABLE ent_risks (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    risk_name VARCHAR(255) NOT NULL,
    risk_category VARCHAR(100),  -- 'technical', 'organizational', 'financial', 'external'
    risk_score INTEGER CHECK (risk_score BETWEEN 1 AND 10),
    capability_id INTEGER NOT NULL,
    mitigation_status VARCHAR(50),  -- 'identified', 'mitigating', 'mitigated', 'accepted'
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (capability_id, year) REFERENCES ent_capabilities(id, year)
);

-- Change Adoption (organizational change metrics)
CREATE TABLE ent_change_adoption (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    change_domain VARCHAR(255) NOT NULL,  -- 'digital_literacy', 'new_processes', 'culture'
    adoption_rate DECIMAL(5,2) CHECK (adoption_rate BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_change_adoption(id, year)
);

-- Culture Health (organizational health index)
CREATE TABLE ent_culture_health (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    ohi_category VARCHAR(255) NOT NULL,  -- McKinsey OHI dimensions
    ohi_score INTEGER CHECK (ohi_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_culture_health(id, year)
);

-- Vendors (external service providers)
CREATE TABLE ent_vendors (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    vendor_name VARCHAR(255) NOT NULL,
    service_domain VARCHAR(100),  -- 'it', 'consulting', 'training', 'infrastructure'
    performance_score INTEGER CHECK (performance_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_vendors(id, year)
);
```

### Part 2: Sector Tables (sec_*)

```sql
-- =====================================================
-- SECTOR TABLES: External outcomes and stakeholders
-- All use composite key (id, year) for time-series tracking
-- =====================================================

-- Objectives (strategic objectives)
CREATE TABLE sec_objectives (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,  -- L1 (strategic), L2 (tactical), L3 (operational)
    parent_id INTEGER,
    parent_year INTEGER,
    objective_name VARCHAR(255) NOT NULL,
    target_value DECIMAL(15,2),
    actual_value DECIMAL(15,2),
    achievement_rate DECIMAL(5,2),  -- percentage of target achieved
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_objectives(id, year)
);

-- Performance (sector KPIs)
CREATE TABLE sec_performance (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    kpi_name VARCHAR(255) NOT NULL,
    kpi_value DECIMAL(15,2),
    target_value DECIMAL(15,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_performance(id, year)
);

-- Policy Tools (policy instruments)
CREATE TABLE sec_policy_tools (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    tool_name VARCHAR(255) NOT NULL,
    tool_type VARCHAR(100),  -- 'regulation', 'incentive', 'service', 'infrastructure'
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_policy_tools(id, year)
);

-- Citizens (citizen segments)
CREATE TABLE sec_citizens (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    segment_name VARCHAR(255) NOT NULL,
    satisfaction_score INTEGER CHECK (satisfaction_score BETWEEN 0 AND 100),
    population_size INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_citizens(id, year)
);

-- Businesses (business segments)
CREATE TABLE sec_businesses (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    segment_name VARCHAR(255) NOT NULL,
    satisfaction_score INTEGER CHECK (satisfaction_score BETWEEN 0 AND 100),
    business_count INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_businesses(id, year)
);

-- Government Entities (partner government organizations)
CREATE TABLE sec_gov_entities (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    entity_name VARCHAR(255) NOT NULL,
    entity_type VARCHAR(100),  -- 'ministry', 'agency', 'authority', 'municipality'
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_gov_entities(id, year)
);

-- Data Transactions (digital service transactions)
CREATE TABLE sec_data_transactions (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    transaction_type VARCHAR(255) NOT NULL,
    transaction_count INTEGER,
    avg_response_time DECIMAL(10,2),  -- milliseconds
    success_rate DECIMAL(5,2),  -- percentage
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_data_transactions(id, year)
);

-- Admin Records (administrative records/documents)
CREATE TABLE sec_admin_records (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    record_type VARCHAR(255) NOT NULL,
    record_count INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_admin_records(id, year)
);
```

### Part 3: Join Tables (jt_*)

```sql
-- =====================================================
-- JOIN TABLES: Many-to-many relationships
-- All include (year) for composite key joins
-- =====================================================

-- Objectives → Policy Tools
CREATE TABLE jt_sec_objectives_sec_policy_tools_join (
    id SERIAL PRIMARY KEY,
    objectives_id INTEGER NOT NULL,
    policy_tools_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (objectives_id, year) REFERENCES sec_objectives(id, year) ON DELETE CASCADE,
    FOREIGN KEY (policy_tools_id, year) REFERENCES sec_policy_tools(id, year) ON DELETE CASCADE,
    UNIQUE (objectives_id, policy_tools_id, year)
);

-- Policy Tools → Capabilities
CREATE TABLE jt_sec_policy_tools_ent_capabilities_join (
    id SERIAL PRIMARY KEY,
    policy_tools_id INTEGER NOT NULL,
    capabilities_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (policy_tools_id, year) REFERENCES sec_policy_tools(id, year) ON DELETE CASCADE,
    FOREIGN KEY (capabilities_id, year) REFERENCES ent_capabilities(id, year) ON DELETE CASCADE,
    UNIQUE (policy_tools_id, capabilities_id, year)
);

-- Capabilities → Projects
CREATE TABLE jt_ent_capabilities_ent_projects_join (
    id SERIAL PRIMARY KEY,
    capabilities_id INTEGER NOT NULL,
    projects_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (capabilities_id, year) REFERENCES ent_capabilities(id, year) ON DELETE CASCADE,
    FOREIGN KEY (projects_id, year) REFERENCES ent_projects(id, year) ON DELETE CASCADE,
    UNIQUE (capabilities_id, projects_id, year)
);

-- Projects → IT Systems
CREATE TABLE jt_ent_projects_ent_it_systems_join (
    id SERIAL PRIMARY KEY,
    projects_id INTEGER NOT NULL,
    it_systems_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (projects_id, year) REFERENCES ent_projects(id, year) ON DELETE CASCADE,
    FOREIGN KEY (it_systems_id, year) REFERENCES ent_it_systems(id, year) ON DELETE CASCADE,
    UNIQUE (projects_id, it_systems_id, year)
);

-- Projects → Org Units
CREATE TABLE jt_ent_projects_ent_org_units_join (
    id SERIAL PRIMARY KEY,
    projects_id INTEGER NOT NULL,
    org_units_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (projects_id, year) REFERENCES ent_projects(id, year) ON DELETE CASCADE,
    FOREIGN KEY (org_units_id, year) REFERENCES ent_org_units(id, year) ON DELETE CASCADE,
    UNIQUE (projects_id, org_units_id, year)
);

-- Org Units → Processes
CREATE TABLE jt_ent_org_units_ent_processes_join (
    id SERIAL PRIMARY KEY,
    org_units_id INTEGER NOT NULL,
    processes_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (org_units_id, year) REFERENCES ent_org_units(id, year) ON DELETE CASCADE,
    FOREIGN KEY (processes_id, year) REFERENCES ent_processes(id, year) ON DELETE CASCADE,
    UNIQUE (org_units_id, processes_id, year)
);

-- Processes → IT Systems
CREATE TABLE jt_ent_processes_ent_it_systems_join (
    id SERIAL PRIMARY KEY,
    processes_id INTEGER NOT NULL,
    it_systems_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (processes_id, year) REFERENCES ent_processes(id, year) ON DELETE CASCADE,
    FOREIGN KEY (it_systems_id, year) REFERENCES ent_it_systems(id, year) ON DELETE CASCADE,
    UNIQUE (processes_id, it_systems_id, year)
);

-- Projects → Objectives
CREATE TABLE jt_ent_projects_sec_objectives_join (
    id SERIAL PRIMARY KEY,
    projects_id INTEGER NOT NULL,
    objectives_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (projects_id, year) REFERENCES ent_projects(id, year) ON DELETE CASCADE,
    FOREIGN KEY (objectives_id, year) REFERENCES sec_objectives(id, year) ON DELETE CASCADE,
    UNIQUE (projects_id, objectives_id, year)
);

-- Citizens → Data Transactions
CREATE TABLE jt_sec_citizens_sec_data_transactions_join (
    id SERIAL PRIMARY KEY,
    citizens_id INTEGER NOT NULL,
    data_transactions_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (citizens_id, year) REFERENCES sec_citizens(id, year) ON DELETE CASCADE,
    FOREIGN KEY (data_transactions_id, year) REFERENCES sec_data_transactions(id, year) ON DELETE CASCADE,
    UNIQUE (citizens_id, data_transactions_id, year)
);

-- Businesses → Data Transactions
CREATE TABLE jt_sec_businesses_sec_data_transactions_join (
    id SERIAL PRIMARY KEY,
    businesses_id INTEGER NOT NULL,
    data_transactions_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (businesses_id, year) REFERENCES sec_businesses(id, year) ON DELETE CASCADE,
    FOREIGN KEY (data_transactions_id, year) REFERENCES sec_data_transactions(id, year) ON DELETE CASCADE,
    UNIQUE (businesses_id, data_transactions_id, year)
);

-- Gov Entities → Policy Tools
CREATE TABLE jt_sec_gov_entities_sec_policy_tools_join (
    id SERIAL PRIMARY KEY,
    gov_entities_id INTEGER NOT NULL,
    policy_tools_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (gov_entities_id, year) REFERENCES sec_gov_entities(id, year) ON DELETE CASCADE,
    FOREIGN KEY (policy_tools_id, year) REFERENCES sec_policy_tools(id, year) ON DELETE CASCADE,
    UNIQUE (gov_entities_id, policy_tools_id, year)
);
```

### Part 4: User & Session Management

```sql
-- =====================================================
-- USER MANAGEMENT: Authentication and authorization
-- =====================================================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'user',  -- 'user', 'admin', 'analyst'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Conversations (chat sessions)
CREATE TABLE conversations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    persona_id INTEGER NOT NULL,  -- FK to personas table (defined later)
    title VARCHAR(255),  -- auto-generated or user-defined
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (persona_id) REFERENCES personas(id) ON DELETE RESTRICT
);

CREATE INDEX idx_conversations_user ON conversations(user_id);
CREATE INDEX idx_conversations_persona ON conversations(persona_id);

-- Messages (chat messages)
CREATE TABLE messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,  -- 'user', 'assistant', 'system'
    content TEXT NOT NULL,
    artifact_ids INTEGER[],  -- Array of artifact IDs generated in this message
    metadata JSONB,  -- Tool calls, confidence scores, etc.
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_messages_conversation ON messages(conversation_id);
CREATE INDEX idx_messages_role ON messages(role);
```

### Part 5: AI Persona Management

```sql
-- =====================================================
-- PERSONA MANAGEMENT: Multi-persona AI system
-- =====================================================

CREATE TABLE personas (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,  -- 'transformation_analyst', 'digital_twin_designer'
    display_name VARCHAR(255) NOT NULL,
    description TEXT,
    system_prompt TEXT NOT NULL,  -- Base system prompt template
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tool Configurations (which tools each persona can use)
CREATE TABLE tool_configs (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    tool_name VARCHAR(100) NOT NULL,  -- 'execute_sql', 'search_vectors', 'create_chart', etc.
    is_enabled BOOLEAN DEFAULT TRUE,
    config JSONB,  -- Tool-specific configuration
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (persona_id, tool_name)
);

CREATE INDEX idx_tool_configs_persona ON tool_configs(persona_id);

-- Knowledge Files (knowledge base per persona)
CREATE TABLE knowledge_files (
    id SERIAL PRIMARY KEY,
    persona_id INTEGER REFERENCES personas(id) ON DELETE CASCADE,  -- NULL = global knowledge
    filename VARCHAR(255) NOT NULL,
    file_type VARCHAR(50),  -- 'json', 'pdf', 'sql', 'md'
    storage_path VARCHAR(500) NOT NULL,  -- Path in blob storage or local filesystem
    vector_indexed BOOLEAN DEFAULT FALSE,  -- Whether embedded in vector DB
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_knowledge_files_persona ON knowledge_files(persona_id);
```

### Part 6: Canvas Artifacts

```sql
-- =====================================================
-- CANVAS ARTIFACTS: Charts, reports, DTDL models, SQL queries
-- =====================================================

CREATE TABLE artifacts (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    message_id INTEGER REFERENCES messages(id) ON DELETE SET NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    artifact_type VARCHAR(50) NOT NULL,  -- 'chart', 'report', 'dtdl_model', 'sql_query'
    title VARCHAR(255),
    content JSONB NOT NULL,  -- Artifact configuration (chart config, report template, etc.)
    rendered_output TEXT,  -- Static output (base64 PNG, PDF URL, etc.)
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_artifacts_conversation ON artifacts(conversation_id);
CREATE INDEX idx_artifacts_user ON artifacts(user_id);
CREATE INDEX idx_artifacts_type ON artifacts(artifact_type);

-- Artifact Versions (version history for canvas artifacts)
CREATE TABLE artifact_versions (
    id SERIAL PRIMARY KEY,
    artifact_id INTEGER NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    content JSONB NOT NULL,
    rendered_output TEXT,
    created_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (artifact_id, version)
);

CREATE INDEX idx_artifact_versions_artifact ON artifact_versions(artifact_id);
```

### Part 7: Admin Configuration

```sql
-- =====================================================
-- ADMIN CONFIGURATION: System-wide settings
-- =====================================================

CREATE TABLE admin_config (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    value_type VARCHAR(50) NOT NULL,  -- 'string', 'number', 'boolean', 'json'
    description TEXT,
    updated_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Example config entries:
-- INSERT INTO admin_config VALUES 
-- ('llm_provider', '"openai"', 'string', 'Active LLM provider'),
-- ('llm_model', '"gpt-4-turbo"', 'string', 'Active LLM model'),
-- ('llm_temperature', '0.7', 'number', 'LLM temperature parameter'),
-- ('llm_max_tokens', '4096', 'number', 'Max tokens per request'),
-- ('web_search_enabled', 'true', 'boolean', 'Enable web search tool');
```

### Part 8: Indices for Performance

```sql
-- =====================================================
-- PERFORMANCE INDICES
-- =====================================================

-- Entity tables
CREATE INDEX idx_ent_capabilities_year ON ent_capabilities(year);
CREATE INDEX idx_ent_capabilities_level ON ent_capabilities(level);
CREATE INDEX idx_ent_capabilities_maturity ON ent_capabilities(maturity_level);

CREATE INDEX idx_ent_projects_year ON ent_projects(year);
CREATE INDEX idx_ent_projects_status ON ent_projects(status);
CREATE INDEX idx_ent_projects_progress ON ent_projects(progress_percentage);

CREATE INDEX idx_ent_it_systems_year ON ent_it_systems(year);
CREATE INDEX idx_ent_it_systems_type ON ent_it_systems(system_type);
CREATE INDEX idx_ent_it_systems_health ON ent_it_systems(health_score);

CREATE INDEX idx_ent_risks_year ON ent_risks(year);
CREATE INDEX idx_ent_risks_score ON ent_risks(risk_score);
CREATE INDEX idx_ent_risks_status ON ent_risks(mitigation_status);

-- Sector tables
CREATE INDEX idx_sec_objectives_year ON sec_objectives(year);
CREATE INDEX idx_sec_objectives_level ON sec_objectives(level);
CREATE INDEX idx_sec_objectives_achievement ON sec_objectives(achievement_rate);

CREATE INDEX idx_sec_performance_year ON sec_performance(year);
CREATE INDEX idx_sec_citizens_year ON sec_citizens(year);
CREATE INDEX idx_sec_citizens_satisfaction ON sec_citizens(satisfaction_score);
```

### Part 9: Materialized Views for Dashboard

```sql
-- =====================================================
-- MATERIALIZED VIEWS: Pre-calculated dashboard data
-- Refresh strategy: Daily batch or on-demand via API
-- =====================================================

-- Dashboard dimension scores (8 health dimensions)
CREATE MATERIALIZED VIEW mv_dashboard_dimensions AS
WITH latest_year AS (
    SELECT MAX(year) as year FROM ent_capabilities
)
SELECT 
    ly.year,
    'Q4' as quarter,  -- Or calculate current quarter
    'Strategic Alignment' as dimension_name,
    (
        -- Strategic Alignment: % of L1 objectives that have L2/L3 objectives
        SELECT (COUNT(DISTINCT CASE WHEN o.level IN ('L2', 'L3') THEN o.parent_id END)::FLOAT / 
                NULLIF(COUNT(DISTINCT CASE WHEN o.level = 'L1' THEN o.id END), 0)) * 100
        FROM sec_objectives o
        WHERE o.year = ly.year
    ) as score,
    90.0 as target
FROM latest_year ly

UNION ALL

SELECT 
    ly.year,
    'Q4' as quarter,
    'Project Delivery' as dimension_name,
    (
        -- Project Delivery: Avg progress of active/completed projects
        SELECT AVG(CASE 
            WHEN status IN ('completed', 'in_progress') THEN progress_percentage 
            ELSE 0 
        END)
        FROM ent_projects p
        WHERE p.year = ly.year
    ) as score,
    85.0 as target
FROM latest_year ly

UNION ALL

SELECT 
    ly.year,
    'Q4' as quarter,
    'Change Adoption' as dimension_name,
    (
        -- Change Adoption: Avg adoption rate across all change domains
        SELECT AVG(adoption_rate)
        FROM ent_change_adoption ca
        WHERE ca.year = ly.year
    ) as score,
    80.0 as target
FROM latest_year ly

UNION ALL

SELECT 
    ly.year,
    'Q4' as quarter,
    'IT Modernization' as dimension_name,
    (
        -- IT Modernization: % of systems that are cloud/hybrid with health score > 70
        SELECT (COUNT(CASE WHEN system_type IN ('cloud', 'hybrid') AND health_score > 70 THEN 1 END)::FLOAT / 
                NULLIF(COUNT(*), 0)) * 100
        FROM ent_it_systems its
        WHERE its.year = ly.year
    ) as score,
    75.0 as target
FROM latest_year ly

UNION ALL

SELECT 
    ly.year,
    'Q4' as quarter,
    'Capability Maturity' as dimension_name,
    (
        -- Capability Maturity: Avg maturity level (target is 4 out of 5)
        SELECT AVG(maturity_level) * 20  -- Convert 1-5 scale to 0-100
        FROM ent_capabilities c
        WHERE c.year = ly.year AND c.level = 'L1'
    ) as score,
    80.0 as target  -- 4/5 = 80%
FROM latest_year ly

UNION ALL

SELECT 
    ly.year,
    'Q4' as quarter,
    'Risk Management' as dimension_name,
    (
        -- Risk Management: % of risks that are mitigated or accepted
        SELECT (COUNT(CASE WHEN mitigation_status IN ('mitigated', 'accepted') THEN 1 END)::FLOAT / 
                NULLIF(COUNT(*), 0)) * 100
        FROM ent_risks r
        WHERE r.year = ly.year
    ) as score,
    95.0 as target
FROM latest_year ly

UNION ALL

SELECT 
    ly.year,
    'Q4' as quarter,
    'Culture Health' as dimension_name,
    (
        -- Culture Health: Avg OHI score
        SELECT AVG(ohi_score)
        FROM ent_culture_health ch
        WHERE ch.year = ly.year
    ) as score,
    70.0 as target
FROM latest_year ly

UNION ALL

SELECT 
    ly.year,
    'Q4' as quarter,
    'Citizen Impact' as dimension_name,
    (
        -- Citizen Impact: Avg citizen satisfaction score
        SELECT AVG(satisfaction_score)
        FROM sec_citizens c
        WHERE c.year = ly.year
    ) as score,
    80.0 as target
FROM latest_year ly;

-- Create unique index for CONCURRENT refresh
CREATE UNIQUE INDEX idx_mv_dashboard_dimensions ON mv_dashboard_dimensions(year, quarter, dimension_name);

-- Refresh function
CREATE OR REPLACE FUNCTION refresh_dashboard_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_dimensions;
END;
$$ LANGUAGE plpgsql;
```

---

## WORLD-VIEW MAP CONFIGURATION

The world-view map enforces navigation constraints for SQL generation. Store this in `worldviewmap.json`:

```json
{
  "nodes": [
    {"id": "sec_objectives", "type": "sector", "table": "sec_objectives"},
    {"id": "sec_policy_tools", "type": "sector", "table": "sec_policy_tools"},
    {"id": "ent_capabilities", "type": "entity", "table": "ent_capabilities"},
    {"id": "ent_projects", "type": "entity", "table": "ent_projects"},
    {"id": "ent_it_systems", "type": "entity", "table": "ent_it_systems"},
    {"id": "ent_org_units", "type": "entity", "table": "ent_org_units"},
    {"id": "ent_processes", "type": "entity", "table": "ent_processes"},
    {"id": "ent_risks", "type": "entity", "table": "ent_risks"},
    {"id": "ent_change_adoption", "type": "entity", "table": "ent_change_adoption"},
    {"id": "ent_culture_health", "type": "entity", "table": "ent_culture_health"},
    {"id": "ent_vendors", "type": "entity", "table": "ent_vendors"},
    {"id": "sec_performance", "type": "sector", "table": "sec_performance"},
    {"id": "sec_citizens", "type": "sector", "table": "sec_citizens"},
    {"id": "sec_businesses", "type": "sector", "table": "sec_businesses"},
    {"id": "sec_gov_entities", "type": "sector", "table": "sec_gov_entities"},
    {"id": "sec_data_transactions", "type": "sector", "table": "sec_data_transactions"},
    {"id": "sec_admin_records", "type": "sector", "table": "sec_admin_records"}
  ],
  "edges": [
    {
      "from": "sec_objectives",
      "to": "sec_policy_tools",
      "via": "jt_sec_objectives_sec_policy_tools_join",
      "routing_rules": ["level_match_only", "composite_key_required"]
    },
    {
      "from": "sec_policy_tools",
      "to": "ent_capabilities",
      "via": "jt_sec_policy_tools_ent_capabilities_join",
      "routing_rules": ["level_match_only", "composite_key_required"]
    },
    {
      "from": "ent_capabilities",
      "to": "ent_projects",
      "via": "jt_ent_capabilities_ent_projects_join",
      "routing_rules": ["level_match_only", "composite_key_required"]
    },
    {
      "from": "ent_projects",
      "to": "ent_it_systems",
      "via": "jt_ent_projects_ent_it_systems_join",
      "routing_rules": ["composite_key_required"]
    },
    {
      "from": "ent_projects",
      "to": "ent_org_units",
      "via": "jt_ent_projects_ent_org_units_join",
      "routing_rules": ["composite_key_required"]
    },
    {
      "from": "ent_org_units",
      "to": "ent_processes",
      "via": "jt_ent_org_units_ent_processes_join",
      "routing_rules": ["composite_key_required"]
    },
    {
      "from": "ent_processes",
      "to": "ent_it_systems",
      "via": "jt_ent_processes_ent_it_systems_join",
      "routing_rules": ["composite_key_required"]
    },
    {
      "from": "ent_projects",
      "to": "sec_objectives",
      "via": "jt_ent_projects_sec_objectives_join",
      "routing_rules": ["level_match_only", "composite_key_required"]
    },
    {
      "from": "sec_citizens",
      "to": "sec_data_transactions",
      "via": "jt_sec_citizens_sec_data_transactions_join",
      "routing_rules": ["composite_key_required"]
    },
    {
      "from": "sec_businesses",
      "to": "sec_data_transactions",
      "via": "jt_sec_businesses_sec_data_transactions_join",
      "routing_rules": ["composite_key_required"]
    },
    {
      "from": "sec_gov_entities",
      "to": "sec_policy_tools",
      "via": "jt_sec_gov_entities_sec_policy_tools_join",
      "routing_rules": ["composite_key_required"]
    },
    {
      "from": "ent_capabilities",
      "to": "ent_risks",
      "via": "direct",
      "routing_rules": ["composite_key_required"]
    }
  ],
  "operational_chains": {
    "SectorOps": [
      "sec_objectives",
      "sec_policy_tools",
      "ent_capabilities",
      "ent_projects",
      "ent_it_systems",
      "ent_processes"
    ],
    "Strategy_to_Tactics": [
      "sec_objectives",
      "sec_policy_tools",
      "ent_capabilities"
    ],
    "Tactical_to_Strategy": [
      "ent_projects",
      "ent_capabilities",
      "sec_policy_tools",
      "sec_objectives"
    ],
    "Risk_Build": [
      "ent_capabilities",
      "ent_risks"
    ],
    "Risk_Execute": [
      "ent_projects",
      "ent_risks"
    ],
    "Internal_Efficiency": [
      "ent_org_units",
      "ent_processes",
      "ent_it_systems"
    ]
  },
  "routing_rules_definitions": {
    "level_match_only": "L1 entities can only join with L1 entities, L2 with L2, L3 with L3",
    "composite_key_required": "All joins MUST include both (id, year) in ON clause",
    "use_jt_only": "Many-to-many relationships MUST use specified join table, no direct joins",
    "no_alternates": "If a path is defined via specific join table, no alternative paths allowed"
  }
}
```

---

## MIGRATION SCRIPTS

### Create Migration Script

```bash
#!/bin/bash
# migrate.sh - Run database migrations

set -e

echo "Running JOSOOR database migrations..."

psql $DATABASE_URL <<EOF

-- Step 1: Create entity tables
\i 01_entity_tables.sql

-- Step 2: Create sector tables
\i 02_sector_tables.sql

-- Step 3: Create join tables
\i 03_join_tables.sql

-- Step 4: Create user management tables
\i 04_user_management.sql

-- Step 5: Create persona management tables
\i 05_persona_management.sql

-- Step 6: Create canvas artifact tables
\i 06_canvas_artifacts.sql

-- Step 7: Create admin config tables
\i 07_admin_config.sql

-- Step 8: Create indices
\i 08_indices.sql

-- Step 9: Create materialized views
\i 09_materialized_views.sql

-- Step 10: Insert default data
\i 10_seed_data.sql

EOF

echo "Migrations completed successfully!"
```

### Seed Default Personas

```sql
-- 10_seed_data.sql

-- Insert default personas
INSERT INTO personas (name, display_name, description, system_prompt, is_active) VALUES
('transformation_analyst', 'Transformation Analyst', 
 'Analyzes organizational transformation data, generates insights, and creates visualizations.',
 'You are an expert Transformation Analyst for public sector organizations. Your role is to analyze transformation data, identify trends, and provide actionable insights. You have access to execute SQL queries, search documents, create charts, and generate reports.',
 TRUE),
('digital_twin_designer', 'Digital Twin Designer',
 'Helps design DTDL v2 digital twin models for organizational use cases.',
 'You are an expert Digital Twin Designer specializing in DTDL v2. Your role is to help users design digital twin models that represent their organizational structure, processes, and transformation initiatives. You guide users through use case definition, entity identification, relationship mapping, and schema generation.',
 TRUE);

-- Insert default tool configurations for Transformation Analyst
INSERT INTO tool_configs (persona_id, tool_name, is_enabled, config) VALUES
((SELECT id FROM personas WHERE name = 'transformation_analyst'), 'execute_sql', TRUE, '{}'),
((SELECT id FROM personas WHERE name = 'transformation_analyst'), 'search_vectors', TRUE, '{}'),
((SELECT id FROM personas WHERE name = 'transformation_analyst'), 'create_chart', TRUE, '{}'),
((SELECT id FROM personas WHERE name = 'transformation_analyst'), 'generate_report', TRUE, '{}');

-- Insert default tool configurations for Digital Twin Designer
INSERT INTO tool_configs (persona_id, tool_name, is_enabled, config) VALUES
((SELECT id FROM personas WHERE name = 'digital_twin_designer'), 'create_dtdl_model', TRUE, '{}'),
((SELECT id FROM personas WHERE name = 'digital_twin_designer'), 'validate_dtdl', TRUE, '{}'),
((SELECT id FROM personas WHERE name = 'digital_twin_designer'), 'generate_schema', TRUE, '{}'),
((SELECT id FROM personas WHERE name = 'digital_twin_designer'), 'preview_model', TRUE, '{}');

-- Insert default admin config
INSERT INTO admin_config (key, value, value_type, description) VALUES
('llm_provider', '"openai"', 'string', 'Active LLM provider (openai, gemini, deepseek, custom)'),
('llm_model', '"gpt-4-turbo"', 'string', 'Active LLM model name'),
('llm_temperature', '0.7', 'number', 'LLM temperature (0.0-1.0)'),
('llm_max_tokens', '4096', 'number', 'Max tokens per LLM request'),
('llm_top_p', '0.9', 'number', 'Top-p sampling parameter'),
('web_search_enabled', 'false', 'boolean', 'Enable web search tool'),
('vector_db_provider', '"qdrant"', 'string', 'Vector database provider'),
('cache_ttl_dashboard', '900', 'number', 'Dashboard cache TTL in seconds (15 minutes)'),
('cache_ttl_query', '3600', 'number', 'Query cache TTL in seconds (1 hour)');
```

---

## CONFIGURATION

### Environment Variables

```bash
# .env.example

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/josoor
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-anon-key

# Vector Database
QDRANT_URL=http://localhost:6333
QDRANT_API_KEY=your-qdrant-api-key

# Redis Cache
REDIS_URL=redis://localhost:6379/0

# LLM Providers (configure all, switch via admin_config table)
OPENAI_API_KEY=sk-...
GEMINI_API_KEY=...
DEEPSEEK_API_KEY=...
CUSTOM_LLM_ENDPOINT=https://your-custom-llm.com/api

# Auth
JWT_SECRET=your-jwt-secret-key-change-this
JWT_ALGORITHM=HS256
JWT_EXPIRATION_MINUTES=1440

# Storage
BLOB_STORAGE_CONNECTION_STRING=...
ARTIFACTS_STORAGE_PATH=/var/app/artifacts
```

---

## TESTING

### Database Connection Test

```python
# test_db_connection.py
import os
from sqlalchemy import create_engine, text

def test_connection():
    engine = create_engine(os.getenv("DATABASE_URL"))
    with engine.connect() as conn:
        result = conn.execute(text("SELECT COUNT(*) FROM users"))
        count = result.scalar()
        print(f"✅ Database connected. Users count: {count}")

if __name__ == "__main__":
    test_connection()
```

### World-View Map Validation

```python
# test_worldview_map.py
import json

def validate_worldview_map():
    with open('worldviewmap.json') as f:
        wvm = json.load(f)
    
    # Check all edge references exist as nodes
    node_ids = {n['id'] for n in wvm['nodes']}
    for edge in wvm['edges']:
        assert edge['from'] in node_ids, f"Unknown node: {edge['from']}"
        assert edge['to'] in node_ids, f"Unknown node: {edge['to']}"
    
    # Check chain references
    for chain_name, chain_nodes in wvm['operational_chains'].items():
        for node in chain_nodes:
            assert node in node_ids, f"Unknown node in chain {chain_name}: {node}"
    
    print("✅ World-view map validated")

if __name__ == "__main__":
    validate_worldview_map()
```

---

## CHECKLIST FOR CODING AGENT

### Database Setup

- [ ] Create PostgreSQL database
- [ ] Run migration scripts in sequence (01-10)
- [ ] Verify all tables created: `\dt` in psql
- [ ] Verify indices created: `\di` in psql
- [ ] Verify materialized views: `\dm` in psql
- [ ] Run seed data script
- [ ] Verify default personas exist: `SELECT * FROM personas;`
- [ ] Verify default tools exist: `SELECT * FROM tool_configs;`
- [ ] Verify admin config exists: `SELECT * FROM admin_config;`
- [ ] Test database connection with Python script
- [ ] Validate world-view map JSON
- [ ] Store worldviewmap.json in accessible location

### Environment Configuration

- [ ] Copy .env.example to .env
- [ ] Configure DATABASE_URL
- [ ] Configure SUPABASE_URL and SUPABASE_KEY
- [ ] Configure QDRANT_URL
- [ ] Configure REDIS_URL
- [ ] Configure OPENAI_API_KEY
- [ ] Generate JWT_SECRET (use `openssl rand -hex 32`)
- [ ] Test all connections

### Next Steps

- [ ] Proceed to **02_CORE_DATA_MODELS.md** for Pydantic schemas
- [ ] Proceed to **03_AUTH_AND_USERS.md** for authentication implementation
