-- =====================================================
-- JOSOOR DATABASE SCHEMA
-- =====================================================

-- =====================================================
-- ENTITY TABLES (ent_*)
-- =====================================================

-- Enterprise Capabilities
CREATE TABLE IF NOT EXISTS ent_capabilities (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,  -- L1, L2, L3
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

-- Projects
CREATE TABLE IF NOT EXISTS ent_projects (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    project_name VARCHAR(255) NOT NULL,
    project_type VARCHAR(100),  -- e.g., 'digital', 'cloud_migration'
    status VARCHAR(50),  -- 'planning', 'in_progress', 'completed', 'on_hold'
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

-- IT Systems
CREATE TABLE IF NOT EXISTS ent_it_systems (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    system_name VARCHAR(255) NOT NULL,
    system_type VARCHAR(100),  -- 'cloud', 'legacy', 'hybrid'
    system_category VARCHAR(100),
    deployment_date DATE,
    uptime_percentage DECIMAL(5,2),
    health_score INTEGER CHECK (health_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_it_systems(id, year)
);

-- Organizational Units
CREATE TABLE IF NOT EXISTS ent_org_units (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    unit_name VARCHAR(255) NOT NULL,
    unit_type VARCHAR(100),
    headcount INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_org_units(id, year)
);

-- Processes
CREATE TABLE IF NOT EXISTS ent_processes (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    process_name VARCHAR(255) NOT NULL,
    process_category VARCHAR(100),
    automation_level VARCHAR(50),  -- 'manual', 'semi_automated', 'fully_automated'
    efficiency_score INTEGER CHECK (efficiency_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_processes(id, year)
);

-- Risks
CREATE TABLE IF NOT EXISTS ent_risks (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    risk_name VARCHAR(255) NOT NULL,
    risk_category VARCHAR(100),
    risk_score INTEGER CHECK (risk_score BETWEEN 1 AND 10),
    capability_id INTEGER NOT NULL,  -- FK to ent_capabilities
    mitigation_status VARCHAR(50),  -- 'identified', 'mitigating', 'mitigated', 'accepted'
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (capability_id, year) REFERENCES ent_capabilities(id, year)
);

-- Change Adoption
CREATE TABLE IF NOT EXISTS ent_change_adoption (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    change_domain VARCHAR(255) NOT NULL,
    adoption_rate DECIMAL(5,2) CHECK (adoption_rate BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_change_adoption(id, year)
);

-- Culture Health
CREATE TABLE IF NOT EXISTS ent_culture_health (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    ohi_category VARCHAR(255) NOT NULL,
    ohi_score INTEGER CHECK (ohi_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_culture_health(id, year)
);

-- Vendors
CREATE TABLE IF NOT EXISTS ent_vendors (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    vendor_name VARCHAR(255) NOT NULL,
    service_domain VARCHAR(100),
    performance_score INTEGER CHECK (performance_score BETWEEN 0 AND 100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES ent_vendors(id, year)
);

-- =====================================================
-- SECTOR TABLES (sec_*)
-- =====================================================

-- Objectives
CREATE TABLE IF NOT EXISTS sec_objectives (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    objective_name VARCHAR(255) NOT NULL,
    target_value DECIMAL(15,2),
    actual_value DECIMAL(15,2),
    achievement_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_objectives(id, year)
);

-- Performance
CREATE TABLE IF NOT EXISTS sec_performance (
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

-- Policy Tools
CREATE TABLE IF NOT EXISTS sec_policy_tools (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    tool_name VARCHAR(255) NOT NULL,
    tool_type VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_policy_tools(id, year)
);

-- Citizens
CREATE TABLE IF NOT EXISTS sec_citizens (
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

-- Businesses
CREATE TABLE IF NOT EXISTS sec_businesses (
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

-- Government Entities
CREATE TABLE IF NOT EXISTS sec_gov_entities (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    entity_name VARCHAR(255) NOT NULL,
    entity_type VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_gov_entities(id, year)
);

-- Data Transactions
CREATE TABLE IF NOT EXISTS sec_data_transactions (
    id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    quarter VARCHAR(2),
    level VARCHAR(2) NOT NULL,
    parent_id INTEGER,
    parent_year INTEGER,
    transaction_type VARCHAR(255) NOT NULL,
    transaction_count INTEGER,
    avg_response_time DECIMAL(10,2),
    success_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, year),
    FOREIGN KEY (parent_id, parent_year) REFERENCES sec_data_transactions(id, year)
);

-- Admin Records
CREATE TABLE IF NOT EXISTS sec_admin_records (
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

-- =====================================================
-- JOIN TABLES (jt_*)
-- =====================================================

CREATE TABLE IF NOT EXISTS jt_sec_objectives_sec_policy_tools_join (
    id SERIAL PRIMARY KEY,
    objectives_id INTEGER NOT NULL,
    policy_tools_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (objectives_id, year) REFERENCES sec_objectives(id, year),
    FOREIGN KEY (policy_tools_id, year) REFERENCES sec_policy_tools(id, year),
    UNIQUE (objectives_id, policy_tools_id, year)
);

CREATE TABLE IF NOT EXISTS jt_sec_policy_tools_ent_capabilities_join (
    id SERIAL PRIMARY KEY,
    policy_tools_id INTEGER NOT NULL,
    capabilities_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (policy_tools_id, year) REFERENCES sec_policy_tools(id, year),
    FOREIGN KEY (capabilities_id, year) REFERENCES ent_capabilities(id, year),
    UNIQUE (policy_tools_id, capabilities_id, year)
);

CREATE TABLE IF NOT EXISTS jt_ent_projects_ent_it_systems_join (
    id SERIAL PRIMARY KEY,
    projects_id INTEGER NOT NULL,
    it_systems_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (projects_id, year) REFERENCES ent_projects(id, year),
    FOREIGN KEY (it_systems_id, year) REFERENCES ent_it_systems(id, year),
    UNIQUE (projects_id, it_systems_id, year)
);

CREATE TABLE IF NOT EXISTS jt_ent_projects_ent_org_units_join (
    id SERIAL PRIMARY KEY,
    projects_id INTEGER NOT NULL,
    org_units_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (projects_id, year) REFERENCES ent_projects(id, year),
    FOREIGN KEY (org_units_id, year) REFERENCES ent_org_units(id, year),
    UNIQUE (projects_id, org_units_id, year)
);

CREATE TABLE IF NOT EXISTS jt_ent_org_units_ent_processes_join (
    id SERIAL PRIMARY KEY,
    org_units_id INTEGER NOT NULL,
    processes_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (org_units_id, year) REFERENCES ent_org_units(id, year),
    FOREIGN KEY (processes_id, year) REFERENCES ent_processes(id, year),
    UNIQUE (org_units_id, processes_id, year)
);

CREATE TABLE IF NOT EXISTS jt_ent_processes_ent_it_systems_join (
    id SERIAL PRIMARY KEY,
    processes_id INTEGER NOT NULL,
    it_systems_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (processes_id, year) REFERENCES ent_processes(id, year),
    FOREIGN KEY (it_systems_id, year) REFERENCES ent_it_systems(id, year),
    UNIQUE (processes_id, it_systems_id, year)
);

CREATE TABLE IF NOT EXISTS jt_sec_citizens_sec_data_transactions_join (
    id SERIAL PRIMARY KEY,
    citizens_id INTEGER NOT NULL,
    data_transactions_id INTEGER NOT NULL,
    year INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (citizens_id, year) REFERENCES sec_citizens(id, year),
    FOREIGN KEY (data_transactions_id, year) REFERENCES sec_data_transactions(id, year),
    UNIQUE (citizens_id, data_transactions_id, year)
);

-- =====================================================
-- INDICES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_ent_capabilities_year ON ent_capabilities(year);
CREATE INDEX IF NOT EXISTS idx_ent_capabilities_level ON ent_capabilities(level);
CREATE INDEX IF NOT EXISTS idx_ent_projects_year ON ent_projects(year);
CREATE INDEX IF NOT EXISTS idx_ent_projects_status ON ent_projects(status);
CREATE INDEX IF NOT EXISTS idx_ent_it_systems_year ON ent_it_systems(year);
CREATE INDEX IF NOT EXISTS idx_ent_risks_year ON ent_risks(year);
CREATE INDEX IF NOT EXISTS idx_ent_risks_score ON ent_risks(risk_score);
CREATE INDEX IF NOT EXISTS idx_sec_objectives_year ON sec_objectives(year);
CREATE INDEX IF NOT EXISTS idx_sec_performance_year ON sec_performance(year);
