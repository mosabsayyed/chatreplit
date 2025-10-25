# **COMPREHENSIVE TECHNICAL SPECIFICATION**

## **TABLE OF CONTENTS**

* [System Architecture Overview](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#1-system-architecture-overview)  
* [Technology Stack](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#2-technology-stack)  
* [Database Schema & Setup](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#3-database-schema--setup)  
* [Backend API Specification](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#4-backend-api-specification)  
* [Autonomous Analytical Agent Implementation](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#5-autonomous-analytical-agent-implementation)  
* [Dashboard Data Generation Service](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#6-dashboard-data-generation-service)  
* [Frontend Dashboard Component](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#7-frontend-dashboard-component)  
* [Drill-Down System Implementation](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#8-drill-down-system-implementation)  
* [Deployment Architecture](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#9-deployment-architecture)  
* [Testing Strategy](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#10-testing-strategy)  
* [File Structure & Code Organization](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#11-file-structure--code-organization)  
* [Step-by-Step Implementation Guide](https://www.genspark.ai/agents?id=55b50871-30e0-4364-b469-541d0cafaaa9#12-step-by-step-implementation-guide)

---

## **1\. SYSTEM ARCHITECTURE OVERVIEW**

┌─────────────────────────────────────────────────────────────────────────┐  
│  PRESENTATION LAYER                                                     │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  React Dashboard (Micro-frontend)                                 │ │  
│  │  ├─ Zone 1: Transformation Health (Spider Chart)                  │ │  
│  │  ├─ Zone 2: Strategic Insights (Bubble Chart)                     │ │  
│  │  ├─ Zone 3: Internal Outputs (Bullet Charts)                      │ │  
│  │  └─ Zone 4: Sector Outcomes (Combo Chart)                         │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  Host Application (Parent Window)                                 │ │  
│  │  ├─ Drill-Down Panel Component                                    │ │  
│  │  ├─ Chat Interface Component                                      │ │  
│  │  └─ Export/Report Components                                      │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
└─────────────────────────────────────────────────────────────────────────┘  
                              ↓ ↑ REST API / WebSocket  
┌─────────────────────────────────────────────────────────────────────────┐  
│  APPLICATION LAYER (FastAPI Backend)                                    │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  API Gateway                                                       │ │  
│  │  ├─ /api/v1/dashboard/generate (Master Dashboard Data)            │ │  
│  │  ├─ /api/v1/dashboard/drill-down (Drill-Down Analysis)            │ │  
│  │  ├─ /api/v1/agent/ask (Chat Q\&A)                                  │ │  
│  │  ├─ /api/v1/ingest/structured (Agent Data Feed)                   │ │  
│  │  ├─ /api/v1/ingest/unstructured (Document Feed)                   │ │  
│  │  └─ /api/v1/health (System Health Check)                          │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  Dashboard Generation Service                                      │ │  
│  │  ├─ DimensionCalculator (8 health dimensions)                     │ │  
│  │  ├─ InsightsGenerator (Strategic bubble data)                     │ │  
│  │  ├─ OutputsGenerator (Internal metrics)                           │ │  
│  │  └─ OutcomesGenerator (Sector performance)                        │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  Autonomous Analytical Agent                                       │ │  
│  │  ├─ Layer 1: IntentUnderstandingMemory                            │ │  
│  │  ├─ Layer 2: HybridRetrievalMemory                                │ │  
│  │  ├─ Layer 3: AnalyticalReasoningMemory                            │ │  
│  │  └─ Layer 4: VisualizationGenerationMemory                        │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  Data Ingestion Pipeline                                           │ │  
│  │  ├─ AgentFeedPipeline (Batch \+ Real\-time)                         │ │  
│  │  ├─ DataQualityMonitor                                            │ │  
│  │  └─ ConfidenceTracker                                             │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
└─────────────────────────────────────────────────────────────────────────┘  
                              ↓ ↑ SQL / Vector Search  
┌─────────────────────────────────────────────────────────────────────────┐  
│  DATA LAYER                                                             │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  Supabase PostgreSQL                                               │ │  
│  │  ├─ Entity Tables (ent\_\*): 10 tables                              │ │  
│  │  ├─ Sector Tables (sec\_\*): 8 tables                               │ │  
│  │  ├─ Join Tables (jt\_\*): 20\+ tables                                │ │  
│  │  └─ World-View Map Config (worldviewmap.json)                     │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  Vector Database (Qdrant/Pinecone)                                │ │  
│  │  ├─ Index: transformation\_documents                               │ │  
│  │  └─ Index: dtdl\_schema\_metadata                                   │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
│  ┌───────────────────────────────────────────────────────────────────┐ │  
│  │  Redis Cache                                                       │ │  
│  │  ├─ Dashboard data cache (TTL: 15 minutes)                        │ │  
│  │  ├─ Query results cache (TTL: 1 hour)                             │ │  
│  │  └─ User session cache                                            │ │  
│  └───────────────────────────────────────────────────────────────────┘ │  
└─────────────────────────────────────────────────────────────────────────┘

---

## **2\. TECHNOLOGY STACK**

### **Backend:**

* **Python 3.11+** \- Primary language  
* **FastAPI** \- REST API framework  
* **Pydantic** \- Data validation  
* **SQLAlchemy** \- ORM for PostgreSQL  
* **Supabase Python Client** \- Database connector  
* **Qdrant Python Client** \- Vector database  
* **Redis-py** \- Caching  
* **Scipy** \- Statistical analysis  
* **Matplotlib** \- Static chart generation  
* **OpenAI Python SDK** \- LLM integration (GPT-4)  
* **Asyncio** \- Async operations

### **Frontend:**

* **React 18+** with TypeScript  
* **Highcharts** \- Visualization library  
* **Tailwind CSS** \- Styling  
* **Zustand** \- State management  
* **React Query** \- API data fetching  
* **Axios** \- HTTP client

### **Infrastructure:**

* **Docker** \+ **Docker Compose** \- Containerization  
* **Nginx** \- Reverse proxy  
* **PostgreSQL 15** (Supabase)  
* **Redis 7** \- Caching layer  
* **Qdrant** \- Vector database

### **DevOps:**

* **GitHub Actions** \- CI/CD  
* **pytest** \- Backend testing  
* **Jest** \- Frontend testing  
* **ESLint** \+ **Black** \- Code formatting

---

## **3\. DATABASE SCHEMA & SETUP**

### **3.1 Supabase PostgreSQL Schema**

Copy  
\-- \=====================================================  
\-- ENTITY TABLES (ent\_\*)  
\-- \=====================================================

\-- Enterprise Capabilities  
CREATE TABLE ent\_capabilities (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  \-- L1, L2, L3  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    capability\_name VARCHAR(255) NOT NULL,  
    maturity\_level INTEGER CHECK (maturity\_level BETWEEN 1 AND 5),  
    description TEXT,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_capabilities(id, year)  
);

\-- Projects  
CREATE TABLE ent\_projects (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    project\_name VARCHAR(255) NOT NULL,  
    project\_type VARCHAR(100),  \-- e.g., 'digital', 'cloud\_migration'  
    status VARCHAR(50),  \-- 'planning', 'in\_progress', 'completed', 'on\_hold'  
    start\_date DATE,  
    completion\_date DATE,  
    budget\_allocated DECIMAL(15,2),  
    budget\_spent DECIMAL(15,2),  
    progress\_percentage INTEGER CHECK (progress\_percentage BETWEEN 0 AND 100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_projects(id, year)  
);

\-- IT Systems  
CREATE TABLE ent\_it\_systems (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    system\_name VARCHAR(255) NOT NULL,  
    system\_type VARCHAR(100),  \-- 'cloud', 'legacy', 'hybrid'  
    system\_category VARCHAR(100),  
    deployment\_date DATE,  
    uptime\_percentage DECIMAL(5,2),  
    health\_score INTEGER CHECK (health\_score BETWEEN 0 AND 100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_it\_systems(id, year)  
);

\-- Organizational Units  
CREATE TABLE ent\_org\_units (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    unit\_name VARCHAR(255) NOT NULL,  
    unit\_type VARCHAR(100),  
    headcount INTEGER,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_org\_units(id, year)  
);

\-- Processes  
CREATE TABLE ent\_processes (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    process\_name VARCHAR(255) NOT NULL,  
    process\_category VARCHAR(100),  
    automation\_level VARCHAR(50),  \-- 'manual', 'semi\_automated', 'fully\_automated'  
    efficiency\_score INTEGER CHECK (efficiency\_score BETWEEN 0 AND 100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_processes(id, year)  
);

\-- Risks  
CREATE TABLE ent\_risks (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    risk\_name VARCHAR(255) NOT NULL,  
    risk\_category VARCHAR(100),  
    risk\_score INTEGER CHECK (risk\_score BETWEEN 1 AND 10),  
    capability\_id INTEGER NOT NULL,  \-- FK to ent\_capabilities  
    mitigation\_status VARCHAR(50),  \-- 'identified', 'mitigating', 'mitigated', 'accepted'  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (capability\_id, year) REFERENCES ent\_capabilities(id, year)  
);

\-- Change Adoption  
CREATE TABLE ent\_change\_adoption (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    change\_domain VARCHAR(255) NOT NULL,  
    adoption\_rate DECIMAL(5,2) CHECK (adoption\_rate BETWEEN 0 AND 100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_change\_adoption(id, year)  
);

\-- Culture Health  
CREATE TABLE ent\_culture\_health (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    ohi\_category VARCHAR(255) NOT NULL,  
    ohi\_score INTEGER CHECK (ohi\_score BETWEEN 0 AND 100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_culture\_health(id, year)  
);

\-- Vendors  
CREATE TABLE ent\_vendors (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    vendor\_name VARCHAR(255) NOT NULL,  
    service\_domain VARCHAR(100),  
    performance\_score INTEGER CHECK (performance\_score BETWEEN 0 AND 100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES ent\_vendors(id, year)  
);

\-- \=====================================================  
\-- SECTOR TABLES (sec\_\*)  
\-- \=====================================================

\-- Objectives  
CREATE TABLE sec\_objectives (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    objective\_name VARCHAR(255) NOT NULL,  
    target\_value DECIMAL(15,2),  
    actual\_value DECIMAL(15,2),  
    achievement\_rate DECIMAL(5,2),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_objectives(id, year)  
);

\-- Performance  
CREATE TABLE sec\_performance (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    kpi\_name VARCHAR(255) NOT NULL,  
    kpi\_value DECIMAL(15,2),  
    target\_value DECIMAL(15,2),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_performance(id, year)  
);

\-- Policy Tools  
CREATE TABLE sec\_policy\_tools (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    tool\_name VARCHAR(255) NOT NULL,  
    tool\_type VARCHAR(100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_policy\_tools(id, year)  
);

\-- Citizens  
CREATE TABLE sec\_citizens (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    segment\_name VARCHAR(255) NOT NULL,  
    satisfaction\_score INTEGER CHECK (satisfaction\_score BETWEEN 0 AND 100),  
    population\_size INTEGER,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_citizens(id, year)  
);

\-- Businesses  
CREATE TABLE sec\_businesses (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    segment\_name VARCHAR(255) NOT NULL,  
    satisfaction\_score INTEGER CHECK (satisfaction\_score BETWEEN 0 AND 100),  
    business\_count INTEGER,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_businesses(id, year)  
);

\-- Government Entities  
CREATE TABLE sec\_gov\_entities (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    entity\_name VARCHAR(255) NOT NULL,  
    entity\_type VARCHAR(100),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_gov\_entities(id, year)  
);

\-- Data Transactions  
CREATE TABLE sec\_data\_transactions (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    transaction\_type VARCHAR(255) NOT NULL,  
    transaction\_count INTEGER,  
    avg\_response\_time DECIMAL(10,2),  
    success\_rate DECIMAL(5,2),  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_data\_transactions(id, year)  
);

\-- Admin Records  
CREATE TABLE sec\_admin\_records (  
    id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    quarter VARCHAR(2),  
    level VARCHAR(2) NOT NULL,  
    parent\_id INTEGER,  
    parent\_year INTEGER,  
    record\_type VARCHAR(255) NOT NULL,  
    record\_count INTEGER,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    updated\_at TIMESTAMP DEFAULT NOW(),  
    PRIMARY KEY (id, year),  
    FOREIGN KEY (parent\_id, parent\_year) REFERENCES sec\_admin\_records(id, year)  
);

\-- \=====================================================  
\-- JOIN TABLES (jt\_\*) \- Selected Examples  
\-- \=====================================================

CREATE TABLE jt\_sec\_objectives\_sec\_policy\_tools\_join (  
    id SERIAL PRIMARY KEY,  
    objectives\_id INTEGER NOT NULL,  
    policy\_tools\_id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    FOREIGN KEY (objectives\_id, year) REFERENCES sec\_objectives(id, year),  
    FOREIGN KEY (policy\_tools\_id, year) REFERENCES sec\_policy\_tools(id, year),  
    UNIQUE (objectives\_id, policy\_tools\_id, year)  
);

CREATE TABLE jt\_sec\_policy\_tools\_ent\_capabilities\_join (  
    id SERIAL PRIMARY KEY,  
    policy\_tools\_id INTEGER NOT NULL,  
    capabilities\_id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    FOREIGN KEY (policy\_tools\_id, year) REFERENCES sec\_policy\_tools(id, year),  
    FOREIGN KEY (capabilities\_id, year) REFERENCES ent\_capabilities(id, year),  
    UNIQUE (policy\_tools\_id, capabilities\_id, year)  
);

CREATE TABLE jt\_ent\_projects\_ent\_it\_systems\_join (  
    id SERIAL PRIMARY KEY,  
    projects\_id INTEGER NOT NULL,  
    it\_systems\_id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    FOREIGN KEY (projects\_id, year) REFERENCES ent\_projects(id, year),  
    FOREIGN KEY (it\_systems\_id, year) REFERENCES ent\_it\_systems(id, year),  
    UNIQUE (projects\_id, it\_systems\_id, year)  
);

CREATE TABLE jt\_ent\_projects\_ent\_org\_units\_join (  
    id SERIAL PRIMARY KEY,  
    projects\_id INTEGER NOT NULL,  
    org\_units\_id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    FOREIGN KEY (projects\_id, year) REFERENCES ent\_projects(id, year),  
    FOREIGN KEY (org\_units\_id, year) REFERENCES ent\_org\_units(id, year),  
    UNIQUE (projects\_id, org\_units\_id, year)  
);

CREATE TABLE jt\_ent\_org\_units\_ent\_processes\_join (  
    id SERIAL PRIMARY KEY,  
    org\_units\_id INTEGER NOT NULL,  
    processes\_id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    FOREIGN KEY (org\_units\_id, year) REFERENCES ent\_org\_units(id, year),  
    FOREIGN KEY (processes\_id, year) REFERENCES ent\_processes(id, year),  
    UNIQUE (org\_units\_id, processes\_id, year)  
);

CREATE TABLE jt\_ent\_processes\_ent\_it\_systems\_join (  
    id SERIAL PRIMARY KEY,  
    processes\_id INTEGER NOT NULL,  
    it\_systems\_id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    FOREIGN KEY (processes\_id, year) REFERENCES ent\_processes(id, year),  
    FOREIGN KEY (it\_systems\_id, year) REFERENCES ent\_it\_systems(id, year),  
    UNIQUE (processes\_id, it\_systems\_id, year)  
);

CREATE TABLE jt\_sec\_citizens\_sec\_data\_transactions\_join (  
    id SERIAL PRIMARY KEY,  
    citizens\_id INTEGER NOT NULL,  
    data\_transactions\_id INTEGER NOT NULL,  
    year INTEGER NOT NULL,  
    created\_at TIMESTAMP DEFAULT NOW(),  
    FOREIGN KEY (citizens\_id, year) REFERENCES sec\_citizens(id, year),  
    FOREIGN KEY (data\_transactions\_id, year) REFERENCES sec\_data\_transactions(id, year),  
    UNIQUE (citizens\_id, data\_transactions\_id, year)  
);

\-- \=====================================================  
\-- INDICES FOR PERFORMANCE  
\-- \=====================================================

CREATE INDEX idx\_ent\_capabilities\_year ON ent\_capabilities(year);  
CREATE INDEX idx\_ent\_capabilities\_level ON ent\_capabilities(level);  
CREATE INDEX idx\_ent\_projects\_year ON ent\_projects(year);  
CREATE INDEX idx\_ent\_projects\_status ON ent\_projects(status);  
CREATE INDEX idx\_ent\_it\_systems\_year ON ent\_it\_systems(year);  
CREATE INDEX idx\_ent\_risks\_year ON ent\_risks(year);  
CREATE INDEX idx\_ent\_risks\_score ON ent\_risks(risk\_score);  
CREATE INDEX idx\_sec\_objectives\_year ON sec\_objectives(year);  
CREATE INDEX idx\_sec\_performance\_year ON sec\_performance(year);

\-- \=====================================================  
\-- MATERIALIZED VIEWS FOR DASHBOARD PERFORMANCE  
\-- \=====================================================

\-- Dashboard dimension scores (pre-calculated)  
CREATE MATERIALIZED VIEW mv\_dashboard\_dimensions AS  
SELECT   
    year,  
    quarter,  
    'Strategic Alignment' as dimension\_name,  
    \-- Calculate score logic here  
    (SELECT COUNT(\*) FROM sec\_objectives o WHERE o.year \= e.year AND o.level IN ('L2', 'L3'))::FLOAT /   
    NULLIF((SELECT COUNT(\*) FROM sec\_objectives o WHERE o.year \= e.year AND o.level \= 'L1'), 0) \* 100 as score  
FROM (SELECT DISTINCT year, quarter FROM ent\_capabilities) e  
UNION ALL  
SELECT   
    year,  
    quarter,  
    'Project Delivery' as dimension\_name,  
    AVG(CASE WHEN status IN ('completed', 'in\_progress') THEN progress\_percentage ELSE 0 END) as score  
FROM ent\_projects  
GROUP BY year, quarter  
\-- Add other dimensions...  
WITH DATA;

CREATE UNIQUE INDEX idx\_mv\_dashboard\_dimensions ON mv\_dashboard\_dimensions(year, quarter, dimension\_name);

\-- Refresh function  
CREATE OR REPLACE FUNCTION refresh\_dashboard\_materialized\_views()  
RETURNS void AS $$  
BEGIN  
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv\_dashboard\_dimensions;  
END;

$$ LANGUAGE plpgsql;

### **3.2 Vector Database Schema (Qdrant)**

Copy  
\# Vector DB Collection Configuration  
from qdrant\_client import QdrantClient  
from qdrant\_client.models import Distance, VectorParams, PointStruct

client \= QdrantClient(url="http://localhost:6333")

\# Create collection for transformation documents  
client.create\_collection(  
    collection\_name="transformation\_documents",  
    vectors\_config=VectorParams(  
        size=3072,  \# text-embedding-3-large dimension  
        distance=Distance.COSINE  
    )  
)

\# Document metadata structure  
"""  
{  
    "id": "doc\_123\_chunk\_5",  
    "vector": \[0.123, 0.456, ...\],  \# 3072 dimensions  
    "payload": {  
        "doc\_type": "strategy" | "assessment" | "study" | "meeting\_minutes" | "email" | "text\_update",  
        "project\_id": 101,  
        "year": 2024,  
        "quarter": "Q2",  
        "author": "user@domain.com",  
        "date": "2024-01-15",  
        "related\_entities": \["ent\_projects", "ent\_capabilities"\],  
        "chunk\_index": 5,  
        "chunk\_text": "Full text of this chunk...",  
        "source\_file": "strategy\_2024.pdf"  
    }  
}  
"""

\# Create collection for DTDL schema metadata  
client.create\_collection(  
    collection\_name="dtdl\_schema\_metadata",  
    vectors\_config=VectorParams(  
        size=3072,  
        distance=Distance.COSINE  
    )  
)

\# Schema metadata structure  
"""  
{  
    "id": "ent\_it\_systems\_system\_name",  
    "vector": \[0.789, 0.234, ...\],  
    "payload": {  
        "table": "ent\_it\_systems",  
        "column": "system\_name",  
        "entity\_name": "IT Systems",  
        "dtdl\_description": "Information technology systems supporting business operations",  
        "business\_friendly\_name": "IT Systems",  
        "data\_type": "string"  
    }  
}  
"""

---

## **4\. BACKEND API SPECIFICATION**

### **4.1 FastAPI Project Structure**

backend/  
├── app/  
│   ├── \_\_init\_\_.py  
│   ├── main.py                          \# FastAPI app entry point  
│   ├── config.py                        \# Configuration management  
│   ├── dependencies.py                  \# Dependency injection  
│   │  
│   ├── api/  
│   │   ├── \_\_init\_\_.py  
│   │   ├── v1/  
│   │   │   ├── \_\_init\_\_.py  
│   │   │   ├── dashboard.py             \# Dashboard endpoints  
│   │   │   ├── agent.py                 \# Agent Q\&A endpoints  
│   │   │   ├── ingest.py                \# Data ingestion endpoints  
│   │   │   └── health.py                \# Health check endpoints  
│   │  
│   ├── services/  
│   │   ├── \_\_init\_\_.py  
│   │   ├── dashboard\_generator.py       \# Dashboard data generation  
│   │   ├── dimension\_calculator.py      \# 8 dimension calculations  
│   │   ├── autonomous\_agent.py          \# Agent orchestrator  
│   │   ├── intent\_memory.py             \# Layer 1: Intent understanding  
│   │   ├── retrieval\_memory.py          \# Layer 2: Data retrieval  
│   │   ├── analytical\_memory.py         \# Layer 3: Analysis  
│   │   ├── visualization\_memory.py      \# Layer 4: Visualization  
│   │   ├── agent\_feed\_pipeline.py       \# Data ingestion  
│   │   └── confidence\_tracker.py        \# Data quality tracking  
│   │  
│   ├── models/  
│   │   ├── \_\_init\_\_.py  
│   │   ├── database.py                  \# SQLAlchemy models  
│   │   ├── schemas.py                   \# Pydantic schemas  
│   │   └── world\_view\_map.py            \# World-view map dataclass  
│   │  
│   ├── db/  
│   │   ├── \_\_init\_\_.py  
│   │   ├── supabase\_client.py           \# Supabase connector  
│   │   ├── vector\_client.py             \# Vector DB connector  
│   │   └── redis\_client.py              \# Redis cache connector  
│   │  
│   └── utils/  
│       ├── \_\_init\_\_.py  
│       ├── statistical\_analyzer.py      \# Statistics utilities  
│       ├── query\_builder.py             \# SQL query builder  
│       └── chart\_generator.py           \# Matplotlib charts  
│  
├── tests/  
│   ├── test\_dashboard.py  
│   ├── test\_agent.py  
│   └── test\_ingestion.py  
│  
├── data/  
│   ├── worldviewmap.json                \# World-view map config  
│   └── gov-model-v2.json                \# DTDL v2 schema  
│  
├── requirements.txt  
├── Dockerfile  
└── docker-compose.yml

### **4.2 API Endpoints**

Copy  
\# app/main.py  
from fastapi import FastAPI  
from fastapi.middleware.cors import CORSMiddleware  
from app.api.v1 import dashboard, agent, ingest, health

app \= FastAPI(  
    title="Transformation Analytics Platform",  
    version="1.0.0",  
    description="Autonomous analytical agent with master dashboard"  
)

\# CORS middleware  
app.add\_middleware(  
    CORSMiddleware,  
    allow\_origins=\["\*"\],  \# Configure for production  
    allow\_credentials=True,  
    allow\_methods=\["\*"\],  
    allow\_headers=\["\*"\],  
)

\# Include routers  
app.include\_router(dashboard.router, prefix="/api/v1/dashboard", tags=\["dashboard"\])  
app.include\_router(agent.router, prefix="/api/v1/agent", tags=\["agent"\])  
app.include\_router(ingest.router, prefix="/api/v1/ingest", tags=\["ingestion"\])  
app.include\_router(health.router, prefix="/api/v1/health", tags=\["health"\])

@app.get("/")  
async def root():  
    return {"message": "Transformation Analytics Platform API", "version": "1.0.0"}

Copy  
\# app/api/v1/dashboard.py  
from fastapi import APIRouter, Depends, HTTPException, Query  
from typing import Optional  
from app.services.dashboard\_generator import DashboardGenerator  
from app.models.schemas import DashboardResponse, DrillDownRequest, DrillDownResponse  
from app.dependencies import get\_dashboard\_generator

router \= APIRouter()

@router.get("/generate", response\_model=DashboardResponse)  
async def generate\_dashboard(  
    year: int \= Query(..., description="Target year"),  
    quarter: Optional\[str\] \= Query(None, description="Target quarter (Q1-Q4)"),  
    generator: DashboardGenerator \= Depends(get\_dashboard\_generator)  
):  
    """  
    Generate complete master dashboard data for all 4 zones.  
      
    Returns:  
        \- Zone 1: Transformation Health (8 dimensions)  
        \- Zone 2: Strategic Insights (objectives-projects bubble chart)  
        \- Zone 3: Internal Outputs (capabilities, processes, IT systems)  
        \- Zone 4: Sector Outcomes (performance metrics)  
    """  
    try:  
        dashboard\_data \= await generator.generate\_dashboard(year=year, quarter=quarter)  
        return dashboard\_data  
    except Exception as e:  
        raise HTTPException(status\_code=500, detail=str(e))

@router.post("/drill-down", response\_model=DrillDownResponse)  
async def drill\_down\_analysis(  
    request: DrillDownRequest,  
    generator: DashboardGenerator \= Depends(get\_dashboard\_generator)  
):  
    """  
    Perform drill-down analysis for specific dashboard element.  
      
    Request body:  
        {  
            "zone": "transformation\_health" | "strategic\_insights" | "internal\_outputs" | "sector\_outcomes",  
            "target": "IT Systems" | "Project 101" | etc.,  
            "context": {  
                "dimension": "IT Systems",  
                "entity\_table": "ent\_it\_systems",  
                "entity\_id": 123,  
                "year": 2024,  
                "level": "L1"  
            }  
        }  
      
    Returns:  
        \- Narrative insights  
        \- Visualizations (base64 encoded PNG)  
        \- Confidence score  
        \- Related entities  
        \- Recommended actions  
    """  
    try:  
        drill\_down\_data \= await generator.drill\_down(request)  
        return drill\_down\_data  
    except Exception as e:  
        raise HTTPException(status\_code=500, detail=str(e))

@router.get("/dimensions/{dimension\_name}")  
async def get\_dimension\_details(  
    dimension\_name: str,  
    year: int \= Query(...),  
    quarter: Optional\[str\] \= Query(None),  
    generator: DashboardGenerator \= Depends(get\_dashboard\_generator)  
):  
    """  
    Get detailed breakdown of a specific dimension.  
    Used for dimension drill-down from Zone 1\.  
    """  
    try:  
        dimension\_data \= await generator.get\_dimension\_details(  
            dimension\_name=dimension\_name,  
            year=year,  
            quarter=quarter  
        )  
        return dimension\_data  
    except Exception as e:  
        raise HTTPException(status\_code=404, detail=f"Dimension not found: {dimension\_name}")

Copy  
\# app/api/v1/agent.py  
from fastapi import APIRouter, Depends, HTTPException  
from app.services.autonomous\_agent import AutonomousAnalyticalAgent  
from app.models.schemas import AgentRequest, AgentResponse  
from app.dependencies import get\_autonomous\_agent

router \= APIRouter()

@router.post("/ask", response\_model=AgentResponse)  
async def ask\_agent(  
    request: AgentRequest,  
    agent: AutonomousAnalyticalAgent \= Depends(get\_autonomous\_agent)  
):  
    """  
    Ask autonomous agent a natural language question.  
      
    Request body:  
        {  
            "question": "How are IT modernization efforts impacting citizen satisfaction?",  
            "context": {  \# Optional: context from dashboard drill-down  
                "entity\_table": "ent\_it\_systems",  
                "year": 2024  
            }  
        }  
      
    Returns:  
        {  
            "narrative": "Natural language insights...",  
            "visualizations": \[  
                {  
                    "type": "line\_chart\_dual\_axis",  
                    "title": "Correlation Analysis",  
                    "image\_base64": "iVBORw0KGg...",  
                    "description": "Shows relationship..."  
                }  
            \],  
            "confidence": {  
                "level": "high",  
                "score": 0.92,  
                "warnings": \[\]  
            },  
            "metadata": {  
                "analysis\_type": "causal\_correlation",  
                "execution\_time\_ms": 2847,  
                "records\_analyzed": 48  
            }  
        }  
    """  
    try:  
        response \= await agent.answer\_question(  
            question=request.question,  
            context=request.context  
        )  
        return response  
    except Exception as e:  
        raise HTTPException(status\_code=500, detail=str(e))

Copy  
\# app/api/v1/ingest.py  
from fastapi import APIRouter, Depends, HTTPException  
from app.services.agent\_feed\_pipeline import AgentFeedPipeline  
from app.models.schemas import StructuredDataRequest, UnstructuredDataRequest, IngestionResponse  
from app.dependencies import get\_feed\_pipeline

router \= APIRouter()

@router.post("/structured", response\_model=IngestionResponse)  
async def ingest\_structured\_data(  
    request: StructuredDataRequest,  
    pipeline: AgentFeedPipeline \= Depends(get\_feed\_pipeline)  
):  
    """  
    Ingest structured data from agentic AIs.  
      
    Request body:  
        {  
            "table": "ent\_projects",  
            "records": \[  
                {  
                    "id": 101,  
                    "year": 2024,  
                    "quarter": "Q4",  
                    "level": "L1",  
                    "project\_name": "Cloud Migration Phase 3",  
                    "status": "in\_progress"  
                }  
            \],  
            "operation": "insert" | "update" | "upsert"  
        }  
    """  
    try:  
        result \= await pipeline.ingest\_structured\_data(  
            table=request.table,  
            records=request.records,  
            operation=request.operation  
        )  
        return result  
    except Exception as e:  
        raise HTTPException(status\_code=400, detail=str(e))

@router.post("/unstructured", response\_model=IngestionResponse)  
async def ingest\_unstructured\_documents(  
    request: UnstructuredDataRequest,  
    pipeline: AgentFeedPipeline \= Depends(get\_feed\_pipeline)  
):  
    """  
    Ingest unstructured documents into vector database.  
      
    Request body:  
        {  
            "documents": \[  
                {  
                    "doc\_type": "strategy",  
                    "content": "Digital Transformation Strategy 2024-2026...",  
                    "metadata": {  
                        "project\_id": 101,  
                        "year": 2024,  
                        "author": "strategy-team@gov.entity",  
                        "date": "2024-01-15"  
                    }  
                }  
            \]  
        }  
    """  
    try:  
        result \= await pipeline.ingest\_unstructured\_documents(request.documents)  
        return result  
    except Exception as e:  
        raise HTTPException(status\_code=400, detail=str(e))

Copy  
\# app/api/v1/health.py  
from fastapi import APIRouter, Depends  
from app.services.confidence\_tracker import ConfidenceTracker  
from app.models.schemas import HealthCheckResponse  
from app.dependencies import get\_confidence\_tracker

router \= APIRouter()

@router.get("/check", response\_model=HealthCheckResponse)  
async def health\_check(  
    tracker: ConfidenceTracker \= Depends(get\_confidence\_tracker)  
):  
    """  
    System health check.  
    Returns data quality metrics and system status.  
    """  
    health \= tracker.check\_system\_health()  
    return health

---

## **5\. AUTONOMOUS ANALYTICAL AGENT IMPLEMENTATION**

**Note:** This is the complete Python implementation from Part 3 & 4 of my previous response. For brevity, I'll reference the key files:

### **5.1 Main Agent Orchestrator**

Copy  
\# app/services/autonomous\_agent.py  
\# \[COMPLETE CODE FROM PREVIOUS RESPONSE \- AutonomousAnalyticalAgent class\]  
\# Includes all 4 layers:  
\# \- Layer 1: IntentUnderstandingMemory  
\# \- Layer 2: HybridRetrievalMemory  
\# \- Layer 3: AnalyticalReasoningMemory  
\# \- Layer 4: VisualizationGenerationMemory

### **5.2 Pydantic Schemas**

Copy  
\# app/models/schemas.py  
from pydantic import BaseModel, Field  
from typing import Optional, List, Dict, Any  
from datetime import datetime

\# \========== DASHBOARD SCHEMAS \==========

class DimensionScore(BaseModel):  
    name: str  
    score: float \= Field(..., ge=0, le=100)  
    target: float  
    description: str  
    entity\_tables: List\[str\]  
    trend: str  \# "improving", "declining", "stable"  
      
class Zone1Data(BaseModel):  
    """Transformation Health \- Spider Chart"""  
    dimensions: List\[DimensionScore\]  
    overall\_health: float  
      
class BubblePoint(BaseModel):  
    id: int  
    name: str  
    x: float  \# Progress %  
    y: float  \# Impact score  
    z: float  \# Budget size  
    objective\_id: int  
    project\_id: int  
      
class Zone2Data(BaseModel):  
    """Strategic Insights \- Bubble Chart"""  
    bubbles: List\[BubblePoint\]  
      
class MetricBar(BaseModel):  
    entity\_type: str  \# "capabilities", "processes", "it\_systems"  
    current\_value: float  
    target\_value: float  
    performance\_percentage: float  
      
class Zone3Data(BaseModel):  
    """Internal Outputs \- Bullet Charts"""  
    metrics: List\[MetricBar\]  
      
class OutcomeMetric(BaseModel):  
    sector: str  \# "citizens", "businesses", "gov\_entities"  
    kpi\_name: str  
    value: float  
    target: float  
    trend: List\[float\]  \# Time series  
      
class Zone4Data(BaseModel):  
    """Sector Outcomes \- Combo Chart"""  
    outcomes: List\[OutcomeMetric\]

class DashboardResponse(BaseModel):  
    year: int  
    quarter: Optional\[str\]  
    zone1: Zone1Data  
    zone2: Zone2Data  
    zone3: Zone3Data  
    zone4: Zone4Data  
    generated\_at: datetime  
    cache\_hit: bool

\# \========== DRILL-DOWN SCHEMAS \==========

class DrillDownContext(BaseModel):  
    dimension: Optional\[str\]  
    entity\_table: Optional\[str\]  
    entity\_id: Optional\[int\]  
    year: int  
    quarter: Optional\[str\]  
    level: Optional\[str\]

class DrillDownRequest(BaseModel):  
    zone: str  \# "transformation\_health", "strategic\_insights", etc.  
    target: str  
    context: DrillDownContext

class Visualization(BaseModel):  
    type: str  
    title: str  
    image\_base64: str  
    description: str

class ConfidenceInfo(BaseModel):  
    level: str  \# "high", "medium", "low"  
    score: float \= Field(..., ge=0, le=1)  
    warnings: List\[str\]

class RelatedEntity(BaseModel):  
    entity\_type: str  
    entity\_id: int  
    entity\_name: str  
    relationship: str

class DrillDownResponse(BaseModel):  
    narrative: str  
    visualizations: List\[Visualization\]  
    confidence: ConfidenceInfo  
    related\_entities: List\[RelatedEntity\]  
    recommended\_actions: List\[str\]  
    metadata: Dict\[str, Any\]

\# \========== AGENT SCHEMAS \==========

class AgentRequest(BaseModel):  
    question: str  
    context: Optional\[Dict\[str, Any\]\]

class AgentResponse(BaseModel):  
    narrative: str  
    visualizations: List\[Visualization\]  
    confidence: ConfidenceInfo  
    metadata: Dict\[str, Any\]

\# \========== INGESTION SCHEMAS \==========

class StructuredRecord(BaseModel):  
    id: int  
    year: int  
    quarter: Optional\[str\]  
    level: str  
    \# Additional fields are dynamic

class StructuredDataRequest(BaseModel):  
    table: str  
    records: List\[Dict\[str, Any\]\]  
    operation: str  \# "insert", "update", "upsert"

class DocumentMetadata(BaseModel):  
    project\_id: Optional\[int\]  
    year: int  
    quarter: Optional\[str\]  
    author: str  
    date: str  
    related\_entities: List\[str\]

class UnstructuredDocument(BaseModel):  
    doc\_type: str  
    content: str  
    metadata: DocumentMetadata

class UnstructuredDataRequest(BaseModel):  
    documents: List\[UnstructuredDocument\]

class IngestionResponse(BaseModel):  
    status: str  
    message: str  
    validated\_count: int  
    inserted\_count: int  
    errors: Optional\[List\[str\]\]

\# \========== HEALTH CHECK SCHEMAS \==========

class HealthCheckResponse(BaseModel):  
    status: str  \# "healthy", "degraded", "critical"  
    health\_score: int  
    warnings: Dict\[str, int\]  
    data\_completeness: Dict\[str, Any\]  
    last\_check: datetime

---

## **6\. DASHBOARD DATA GENERATION SERVICE**

This is the **core service** that calculates all 4 zones' data.

Copy  
\# app/services/dashboard\_generator.py  
from typing import Optional, Dict, List, Any  
from datetime import datetime  
from app.db.supabase\_client import SupabaseClient  
from app.db.redis\_client import RedisClient  
from app.services.dimension\_calculator import DimensionCalculator  
from app.services.autonomous\_agent import AutonomousAnalyticalAgent  
from app.models.schemas import (  
    DashboardResponse, DrillDownRequest, DrillDownResponse,  
    Zone1Data, Zone2Data, Zone3Data, Zone4Data  
)  
import json

class DashboardGenerator:  
    """  
    Generates master dashboard data for all 4 zones.  
    Handles caching and drill-down orchestration.  
    """  
      
    def \_\_init\_\_(  
        self,  
        supabase: SupabaseClient,  
        redis: RedisClient,  
        dimension\_calculator: DimensionCalculator,  
        autonomous\_agent: AutonomousAnalyticalAgent  
    ):  
        self.supabase \= supabase  
        self.redis \= redis  
        self.dimension\_calc \= dimension\_calculator  
        self.agent \= autonomous\_agent  
          
        \# Cache TTL: 15 minutes for dashboard data  
        self.dashboard\_cache\_ttl \= 900  
      
    async def generate\_dashboard(self, year: int, quarter: Optional\[str\] \= None) \-\> DashboardResponse:  
        """  
        Generate complete dashboard data for all 4 zones.  
        Uses Redis cache to avoid redundant calculations.  
        """  
          
        \# Check cache first  
        cache\_key \= f"dashboard:{year}:{quarter or 'all'}"  
        cached\_data \= self.redis.get(cache\_key)  
          
        if cached\_data:  
            print(f"\[Dashboard\] Cache hit for {cache\_key}")  
            data \= json.loads(cached\_data)  
            data\["cache\_hit"\] \= True  
            return DashboardResponse(\*\*data)  
          
        print(f"\[Dashboard\] Generating fresh data for year={year}, quarter={quarter}")  
          
        \# Generate each zone in parallel  
        import asyncio  
          
        zone1\_task \= asyncio.create\_task(self.\_generate\_zone1(year, quarter))  
        zone2\_task \= asyncio.create\_task(self.\_generate\_zone2(year, quarter))  
        zone3\_task \= asyncio.create\_task(self.\_generate\_zone3(year, quarter))  
        zone4\_task \= asyncio.create\_task(self.\_generate\_zone4(year, quarter))  
          
        zone1, zone2, zone3, zone4 \= await asyncio.gather(  
            zone1\_task, zone2\_task, zone3\_task, zone4\_task  
        )  
          
        dashboard\_data \= DashboardResponse(  
            year=year,  
            quarter=quarter,  
            zone1=zone1,  
            zone2=zone2,  
            zone3=zone3,  
            zone4=zone4,  
            generated\_at=datetime.now(),  
            cache\_hit=False  
        )  
          
        \# Cache the result  
        self.redis.set(  
            cache\_key,  
            dashboard\_data.json(),  
            ex=self.dashboard\_cache\_ttl  
        )  
          
        return dashboard\_data  
      
    async def \_generate\_zone1(self, year: int, quarter: Optional\[str\]) \-\> Zone1Data:  
        """  
        Zone 1: Transformation Health (Spider Chart with 8 Dimensions)  
        """  
          
        dimensions \= await self.dimension\_calc.calculate\_all\_dimensions(year, quarter)  
        overall\_health \= sum(d\["score"\] for d in dimensions) / len(dimensions)  
          
        return Zone1Data(  
            dimensions=dimensions,  
            overall\_health=overall\_health  
        )  
      
    async def \_generate\_zone2(self, year: int, quarter: Optional\[str\]) \-\> Zone2Data:  
        """  
        Zone 2: Strategic Insights (Bubble Chart: Objectives vs Projects)  
        """  
          
        \# Query: Projects with their objectives  
        query \= """  
        SELECT   
            p.id as project\_id,  
            p.project\_name,  
            p.progress\_percentage,  
            p.budget\_allocated,  
            o.id as objective\_id,  
            o.objective\_name,  
            o.achievement\_rate,  
            \-- Impact score: weighted combination of progress and achievement  
            (p.progress\_percentage \* 0.6 \+ o.achievement\_rate \* 0.4) as impact\_score  
        FROM ent\_projects p  
        INNER JOIN jt\_ent\_projects\_sec\_objectives\_join jt  
            ON p.id \= jt.projects\_id AND p.year \= jt.year  
        INNER JOIN sec\_objectives o  
            ON jt.objectives\_id \= o.id AND jt.year \= o.year  
        WHERE p.year \= $1  
            AND p.level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND p.quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
          
        bubbles \= \[  
            {  
                "id": row\["project\_id"\],  
                "name": row\["project\_name"\],  
                "x": row\["progress\_percentage"\],  
                "y": row\["impact\_score"\],  
                "z": float(row\["budget\_allocated"\]) / 1\_000\_000,  \# Millions  
                "objective\_id": row\["objective\_id"\],  
                "project\_id": row\["project\_id"\]  
            }  
            for row in result.data  
        \]  
          
        return Zone2Data(bubbles=bubbles)  
      
    async def \_generate\_zone3(self, year: int, quarter: Optional\[str\]) \-\> Zone3Data:  
        """  
        Zone 3: Internal Outputs (Bullet Charts: Capabilities, Processes, IT Systems)  
        """  
          
        metrics \= \[\]  
          
        \# Capability Maturity  
        cap\_query \= """  
        SELECT   
            AVG(maturity\_level) as current\_value,  
            4.0 as target\_value  
        FROM ent\_capabilities  
        WHERE year \= $1 AND level \= 'L1'  
        """  
        cap\_result \= await self.supabase.execute\_query(cap\_query, \[year\])  
        if cap\_result.data:  
            row \= cap\_result.data\[0\]  
            metrics.append({  
                "entity\_type": "Capabilities",  
                "current\_value": row\["current\_value"\],  
                "target\_value": row\["target\_value"\],  
                "performance\_percentage": (row\["current\_value"\] / row\["target\_value"\]) \* 100  
            })  
          
        \# Process Efficiency  
        proc\_query \= """  
        SELECT   
            AVG(efficiency\_score) as current\_value,  
            85.0 as target\_value  
        FROM ent\_processes  
        WHERE year \= $1 AND level \= 'L1'  
        """  
        proc\_result \= await self.supabase.execute\_query(proc\_query, \[year\])  
        if proc\_result.data:  
            row \= proc\_result.data\[0\]  
            metrics.append({  
                "entity\_type": "Processes",  
                "current\_value": row\["current\_value"\],  
                "target\_value": row\["target\_value"\],  
                "performance\_percentage": (row\["current\_value"\] / row\["target\_value"\]) \* 100  
            })  
          
        \# IT System Health  
        it\_query \= """  
        SELECT   
            AVG(health\_score) as current\_value,  
            90.0 as target\_value  
        FROM ent\_it\_systems  
        WHERE year \= $1 AND level \= 'L1'  
        """  
        it\_result \= await self.supabase.execute\_query(it\_query, \[year\])  
        if it\_result.data:  
            row \= it\_result.data\[0\]  
            metrics.append({  
                "entity\_type": "IT Systems",  
                "current\_value": row\["current\_value"\],  
                "target\_value": row\["target\_value"\],  
                "performance\_percentage": (row\["current\_value"\] / row\["target\_value"\]) \* 100  
            })  
          
        return Zone3Data(metrics=metrics)  
      
    async def \_generate\_zone4(self, year: int, quarter: Optional\[str\]) \-\> Zone4Data:  
        """  
        Zone 4: Sector Outcomes (Combo Chart: Performance across sectors)  
        """  
          
        outcomes \= \[\]  
          
        \# Citizen Satisfaction Trend  
        citizen\_query \= """  
        SELECT   
            quarter,  
            AVG(satisfaction\_score) as avg\_score,  
            80.0 as target\_value  
        FROM sec\_citizens  
        WHERE year \= $1 AND level \= 'L1'  
        GROUP BY quarter  
        ORDER BY quarter  
        """  
        citizen\_result \= await self.supabase.execute\_query(citizen\_query, \[year\])  
        if citizen\_result.data:  
            trend \= \[row\["avg\_score"\] for row in citizen\_result.data\]  
            outcomes.append({  
                "sector": "Citizens",  
                "kpi\_name": "Satisfaction Score",  
                "value": trend\[-1\] if trend else 0,  
                "target": 80.0,  
                "trend": trend  
            })  
          
        \# Business Satisfaction Trend  
        business\_query \= """  
        SELECT   
            quarter,  
            AVG(satisfaction\_score) as avg\_score,  
            75.0 as target\_value  
        FROM sec\_businesses  
        WHERE year \= $1 AND level \= 'L1'  
        GROUP BY quarter  
        ORDER BY quarter  
        """  
        business\_result \= await self.supabase.execute\_query(business\_query, \[year\])  
        if business\_result.data:  
            trend \= \[row\["avg\_score"\] for row in business\_result.data\]  
            outcomes.append({  
                "sector": "Businesses",  
                "kpi\_name": "Satisfaction Score",  
                "value": trend\[-1\] if trend else 0,  
                "target": 75.0,  
                "trend": trend  
            })  
          
        \# Transaction Success Rate  
        transaction\_query \= """  
        SELECT   
            quarter,  
            AVG(success\_rate) as avg\_rate,  
            95.0 as target\_value  
        FROM sec\_data\_transactions  
        WHERE year \= $1 AND level \= 'L1'  
        GROUP BY quarter  
        ORDER BY quarter  
        """  
        transaction\_result \= await self.supabase.execute\_query(transaction\_query, \[year\])  
        if transaction\_result.data:  
            trend \= \[row\["avg\_rate"\] for row in transaction\_result.data\]  
            outcomes.append({  
                "sector": "Transactions",  
                "kpi\_name": "Success Rate",  
                "value": trend\[-1\] if trend else 0,  
                "target": 95.0,  
                "trend": trend  
            })  
          
        return Zone4Data(outcomes=outcomes)  
      
    async def drill\_down(self, request: DrillDownRequest) \-\> DrillDownResponse:  
        """  
        Orchestrate drill-down analysis by routing to autonomous agent.  
        """  
          
        \# Construct context-aware question for agent  
        question \= self.\_construct\_drill\_down\_question(request)  
          
        \# Call autonomous agent  
        agent\_response \= await self.agent.answer\_question(  
            question=question,  
            context=request.context.dict()  
        )  
          
        \# Get related entities  
        related\_entities \= await self.\_get\_related\_entities(request.context)  
          
        \# Generate recommended actions  
        recommended\_actions \= self.\_generate\_recommendations(request, agent\_response)  
          
        return DrillDownResponse(  
            narrative=agent\_response\["narrative"\],  
            visualizations=agent\_response\["visualizations"\],  
            confidence=agent\_response\["confidence"\],  
            related\_entities=related\_entities,  
            recommended\_actions=recommended\_actions,  
            metadata=agent\_response\["metadata"\]  
        )  
      
    def \_construct\_drill\_down\_question(self, request: DrillDownRequest) \-\> str:  
        """  
        Convert drill-down request into natural language question for agent.  
        """  
          
        ctx \= request.context  
        zone \= request.zone  
        target \= request.target  
          
        if zone \== "transformation\_health":  
            return f"Show me detailed analysis of {target} performance in {ctx.year}. Include trends over quarters, contributing factors, and specific entities that need attention. Provide recommendations for improvement."  
          
        elif zone \== "strategic\_insights":  
            if ctx.entity\_table \== "ent\_projects":  
                return f"Analyze project '{target}' in {ctx.year}. Show its progress, linked objectives, budget utilization, key risks, and recommendations."  
            else:  
                return f"Analyze objective '{target}' in {ctx.year}. Show linked projects, achievement status, and gaps."  
          
        elif zone \== "internal\_outputs":  
            return f"Analyze {target} in {ctx.year}. Show performance metrics, trends, related entities, and improvement opportunities."  
          
        elif zone \== "sector\_outcomes":  
            return f"Analyze {target} outcomes in {ctx.year}. Show KPI trends, stakeholder breakdown, and policy impact."  
          
        else:  
            return f"Provide detailed analysis of {target} for {ctx.year}."  
      
    async def \_get\_related\_entities(self, context: DrillDownContext) \-\> List\[Dict\[str, Any\]\]:  
        """  
        Find entities related to the drill-down target using world-view map chains.  
        """  
          
        \# Use world-view map to find connected entities  
        \# Example: If drilling into "ent\_it\_systems", find related:  
        \# \- ent\_projects (via jt\_ent\_projects\_ent\_it\_systems\_join)  
        \# \- ent\_vendors (via jt\_ent\_it\_systems\_ent\_vendors\_join)  
        \# \- ent\_processes (via jt\_ent\_processes\_ent\_it\_systems\_join)  
          
        related \= \[\]  
          
        if context.entity\_table \== "ent\_it\_systems" and context.entity\_id:  
            \# Get related projects  
            query \= """  
            SELECT p.id, p.project\_name, 'Delivers' as relationship  
            FROM ent\_projects p  
            INNER JOIN jt\_ent\_projects\_ent\_it\_systems\_join jt  
                ON p.id \= jt.projects\_id AND p.year \= jt.year  
            WHERE jt.it\_systems\_id \= $1 AND jt.year \= $2  
            """  
            result \= await self.supabase.execute\_query(query, \[context.entity\_id, context.year\])  
            for row in result.data:  
                related.append({  
                    "entity\_type": "Project",  
                    "entity\_id": row\["id"\],  
                    "entity\_name": row\["project\_name"\],  
                    "relationship": row\["relationship"\]  
                })  
          
        return related  
      
    def \_generate\_recommendations(self, request: DrillDownRequest, agent\_response: Dict) \-\> List\[str\]:  
        """  
        Generate actionable recommendations based on analysis.  
        """  
          
        \# Extract from agent's insights  
        insights \= agent\_response.get("metadata", {}).get("insights", {})  
        recommendations \= insights.get("recommendations", \[\])  
          
        \# Add drill-down specific actions  
        if request.zone \== "transformation\_health":  
            recommendations.append(f"Export detailed report for {request.target}")  
            recommendations.append(f"Schedule review meeting with stakeholders")  
          
        return recommendations\[:5\]  \# Limit to top 5  
      
    async def get\_dimension\_details(self, dimension\_name: str, year: int, quarter: Optional\[str\]) \-\> Dict\[str, Any\]:  
        """  
        Get detailed breakdown of a specific health dimension.  
        """  
          
        dimension\_data \= await self.dimension\_calc.calculate\_single\_dimension(  
            dimension\_name=dimension\_name,  
            year=year,  
            quarter=quarter  
        )  
          
        return dimension\_data

---

## **7\. DIMENSION CALCULATOR**

This calculates the 8 health dimensions for Zone 1\.

Copy  
\# app/services/dimension\_calculator.py  
from typing import List, Dict, Optional, Any  
from app.db.supabase\_client import SupabaseClient  
from app.models.schemas import DimensionScore

class DimensionCalculator:  
    """  
    Calculates the 8 transformation health dimensions for spider chart (Zone 1).  
    """  
      
    def \_\_init\_\_(self, supabase: SupabaseClient):  
        self.supabase \= supabase  
          
        \# Dimension definitions  
        self.dimensions \= {  
            "Strategic Alignment": {  
                "description": "Objectives cascaded to operations",  
                "entity\_tables": \["sec\_objectives", "ent\_capabilities"\],  
                "target": 90,  
                "calculator": self.\_calc\_strategic\_alignment  
            },  
            "Project Delivery": {  
                "description": "Projects on time & budget",  
                "entity\_tables": \["ent\_projects"\],  
                "target": 85,  
                "calculator": self.\_calc\_project\_delivery  
            },  
            "Change Adoption": {  
                "description": "Behavioral changes embedded",  
                "entity\_tables": \["ent\_change\_adoption"\],  
                "target": 80,  
                "calculator": self.\_calc\_change\_adoption  
            },  
            "IT Modernization": {  
                "description": "Systems modernized & reliable",  
                "entity\_tables": \["ent\_it\_systems"\],  
                "target": 75,  
                "calculator": self.\_calc\_it\_modernization  
            },  
            "Capability Maturity": {  
                "description": "Business capabilities developed",  
                "entity\_tables": \["ent\_capabilities"\],  
                "target": 4,  \# Out of 5  
                "calculator": self.\_calc\_capability\_maturity  
            },  
            "Risk Management": {  
                "description": "Risks identified & mitigated",  
                "entity\_tables": \["ent\_risks"\],  
                "target": 95,  
                "calculator": self.\_calc\_risk\_management  
            },  
            "Culture Health": {  
                "description": "Organizational health index",  
                "entity\_tables": \["ent\_culture\_health"\],  
                "target": 70,  
                "calculator": self.\_calc\_culture\_health  
            },  
            "Citizen Impact": {  
                "description": "Sector-level outcomes delivered",  
                "entity\_tables": \["sec\_performance", "sec\_citizens"\],  
                "target": 80,  
                "calculator": self.\_calc\_citizen\_impact  
            }  
        }  
      
    async def calculate\_all\_dimensions(self, year: int, quarter: Optional\[str\]) \-\> List\[DimensionScore\]:  
        """  
        Calculate all 8 dimensions in parallel.  
        """  
          
        import asyncio  
          
        tasks \= \[  
            asyncio.create\_task(self.calculate\_single\_dimension(dim\_name, year, quarter))  
            for dim\_name in self.dimensions.keys()  
        \]  
          
        results \= await asyncio.gather(\*tasks)  
          
        return \[DimensionScore(\*\*r) for r in results\]  
      
    async def calculate\_single\_dimension(self, dimension\_name: str, year: int, quarter: Optional\[str\]) \-\> Dict\[str, Any\]:  
        """  
        Calculate a single dimension score.  
        """  
          
        if dimension\_name not in self.dimensions:  
            raise ValueError(f"Unknown dimension: {dimension\_name}")  
          
        dim\_def \= self.dimensions\[dimension\_name\]  
          
        \# Call dimension-specific calculator  
        score \= await dim\_def\["calculator"\](year, quarter)  
          
        \# Determine trend (compare to previous period)  
        previous\_score \= await dim\_def\["calculator"\](year \- 1, quarter) if year \> 2020 else score  
          
        if score \> previous\_score \+ 5:  
            trend \= "improving"  
        elif score \< previous\_score \- 5:  
            trend \= "declining"  
        else:  
            trend \= "stable"  
          
        return {  
            "name": dimension\_name,  
            "score": round(score, 1),  
            "target": dim\_def\["target"\],  
            "description": dim\_def\["description"\],  
            "entity\_tables": dim\_def\["entity\_tables"\],  
            "trend": trend  
        }  
      
    \# \========== DIMENSION-SPECIFIC CALCULATORS \==========  
      
    async def \_calc\_strategic\_alignment(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Strategic Alignment \= % of L1 objectives with L2/L3 cascade  
        """  
          
        query \= """  
        WITH l1\_objectives AS (  
            SELECT id FROM sec\_objectives WHERE year \= $1 AND level \= 'L1'  
        ),  
        cascaded\_objectives AS (  
            SELECT DISTINCT parent\_id   
            FROM sec\_objectives   
            WHERE year \= $1 AND level IN ('L2', 'L3') AND parent\_id IS NOT NULL  
        )  
        SELECT   
            (COUNT(DISTINCT c.parent\_id)::FLOAT / NULLIF(COUNT(DISTINCT l1.id), 0)) \* 100 as score  
        FROM l1\_objectives l1  
        LEFT JOIN cascaded\_objectives c ON l1.id \= c.parent\_id  
        """  
          
        result \= await self.supabase.execute\_query(query, \[year\])  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_project\_delivery(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Project Delivery \= % of projects completed or on-track (progress \>= 80%)  
        """  
          
        query \= """  
        SELECT   
            (COUNT(CASE WHEN status \= 'completed' OR progress\_percentage \>= 80 THEN 1 END)::FLOAT /   
             NULLIF(COUNT(\*), 0)) \* 100 as score  
        FROM ent\_projects  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_change\_adoption(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Change Adoption \= Average adoption rate across all domains  
        """  
          
        query \= """  
        SELECT AVG(adoption\_rate) as score  
        FROM ent\_change\_adoption  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_it\_modernization(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        IT Modernization \= % cloud-enabled systems with uptime \> 99%  
        """  
          
        query \= """  
        SELECT   
            (COUNT(CASE WHEN system\_type \= 'cloud' AND uptime\_percentage \>= 99 THEN 1 END)::FLOAT /   
             NULLIF(COUNT(\*), 0)) \* 100 as score  
        FROM ent\_it\_systems  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_capability\_maturity(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Capability Maturity \= Average maturity level (1-5 scale) \* 20 to normalize to 0-100  
        """  
          
        query \= """  
        SELECT AVG(maturity\_level) \* 20 as score  
        FROM ent\_capabilities  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_risk\_management(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Risk Management \= % of high/critical risks (score \>= 6\) with active mitigation  
        """  
          
        query \= """  
        SELECT   
            (COUNT(CASE WHEN risk\_score \>= 6 AND mitigation\_status IN ('mitigating', 'mitigated') THEN 1 END)::FLOAT /   
             NULLIF(COUNT(CASE WHEN risk\_score \>= 6 THEN 1 END), 0)) \* 100 as score  
        FROM ent\_risks  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_culture\_health(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Culture Health \= Average OHI score across all units  
        """  
          
        query \= """  
        SELECT AVG(ohi\_score) as score  
        FROM ent\_culture\_health  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_citizen\_impact(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Citizen Impact \= Weighted average of:  
        \- 60%: % KPIs meeting target  
        \- 40%: Average citizen satisfaction  
        """  
          
        \# KPIs meeting target  
        kpi\_query \= """  
        SELECT   
            (COUNT(CASE WHEN kpi\_value \>= target\_value THEN 1 END)::FLOAT /   
             NULLIF(COUNT(\*), 0)) \* 100 as kpi\_score  
        FROM sec\_performance  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        \# Citizen satisfaction  
        citizen\_query \= """  
        SELECT AVG(satisfaction\_score) as citizen\_score  
        FROM sec\_citizens  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            kpi\_query \+= " AND quarter \= $2"  
            citizen\_query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        kpi\_result \= await self.supabase.execute\_query(kpi\_query, params)  
        citizen\_result \= await self.supabase.execute\_query(citizen\_query, params)  
          
        kpi\_score \= kpi\_result.data\[0\]\["kpi\_score"\] if kpi\_result.data else 0  
        citizen\_score \= citizen\_result.data\[0\]\["citizen\_score"\] if citizen\_result.data else 0  
          
        \# Weighted average  
        return (kpi\_score \* 0.6) \+ (citizen\_score \* 0.4)

## **7\. FRONTEND DASHBOARD COMPONENT (React \+ TypeScript)**

### **7.1 Frontend Project Structure**

frontend/  
├── public/  
│   └── index.html  
├── src/  
│   ├── App.tsx  
│   ├── index.tsx  
│   ├── types/  
│   │   ├── dashboard.types.ts  
│   │   └── api.types.ts  
│   │  
│   ├── components/  
│   │   ├── Dashboard/  
│   │   │   ├── Dashboard.tsx              \# Main dashboard container  
│   │   │   ├── Zone1Health.tsx            \# Spider chart  
│   │   │   ├── Zone2Insights.tsx          \# Bubble chart  
│   │   │   ├── Zone3Outputs.tsx           \# Bullet charts  
│   │   │   ├── Zone4Outcomes.tsx          \# Combo chart  
│   │   │   └── LoadingState.tsx  
│   │   │  
│   │   ├── DrillDown/  
│   │   │   ├── DrillDownPanel.tsx         \# Slide-in panel  
│   │   │   ├── DrillDownContent.tsx       \# Content renderer  
│   │   │   ├── VisualizationGallery.tsx   \# Image carousel  
│   │   │   └── RelatedEntities.tsx        \# Entity list  
│   │   │  
│   │   ├── Chat/  
│   │   │   ├── ChatInterface.tsx          \# Q\&A chat  
│   │   │   ├── ChatMessage.tsx  
│   │   │   └── ChatInput.tsx  
│   │   │  
│   │   └── Common/  
│   │       ├── ConfidenceBadge.tsx  
│   │       ├── Breadcrumbs.tsx  
│   │       └── ContextMenu.tsx  
│   │  
│   ├── services/  
│   │   ├── api.service.ts                 \# API client  
│   │   └── analytics.service.ts           \# Event tracking  
│   │  
│   ├── hooks/  
│   │   ├── useDashboard.ts  
│   │   ├── useDrillDown.ts  
│   │   └── useChat.ts  
│   │  
│   ├── store/  
│   │   └── dashboardStore.ts              \# Zustand store  
│   │  
│   ├── utils/  
│   │   ├── chartHelpers.ts  
│   │   └── formatters.ts  
│   │  
│   └── styles/  
│       ├── globals.css  
│       └── dashboard.css  
│  
├── package.json  
├── tsconfig.json  
└── tailwind.config.js

### **7.2 TypeScript Type Definitions**

Copy  
// src/types/dashboard.types.ts  
export interface DimensionScore {  
  name: string;  
  score: number;  
  target: number;  
  description: string;  
  entity\_tables: string\[\];  
  trend: 'improving' | 'declining' | 'stable';  
}

export interface Zone1Data {  
  dimensions: DimensionScore\[\];  
  overall\_health: number;  
}

export interface BubblePoint {  
  id: number;  
  name: string;  
  x: number;  
  y: number;  
  z: number;  
  objective\_id: number;  
  project\_id: number;  
}

export interface Zone2Data {  
  bubbles: BubblePoint\[\];  
}

export interface MetricBar {  
  entity\_type: string;  
  current\_value: number;  
  target\_value: number;  
  performance\_percentage: number;  
}

export interface Zone3Data {  
  metrics: MetricBar\[\];  
}

export interface OutcomeMetric {  
  sector: string;  
  kpi\_name: string;  
  value: number;  
  target: number;  
  trend: number\[\];  
}

export interface Zone4Data {  
  outcomes: OutcomeMetric\[\];  
}

export interface DashboardData {  
  year: number;  
  quarter: string | null;  
  zone1: Zone1Data;  
  zone2: Zone2Data;  
  zone3: Zone3Data;  
  zone4: Zone4Data;  
  generated\_at: string;  
  cache\_hit: boolean;  
}

export interface DrillDownContext {  
  dimension?: string;  
  entity\_table?: string;  
  entity\_id?: number;  
  year: number;  
  quarter?: string;  
  level?: string;  
}

export interface DrillDownRequest {  
  zone: 'transformation\_health' | 'strategic\_insights' | 'internal\_outputs' | 'sector\_outcomes';  
  target: string;  
  context: DrillDownContext;  
}

export interface Visualization {  
  type: string;  
  title: string;  
  image\_base64: string;  
  description: string;  
}

export interface ConfidenceInfo {  
  level: 'high' | 'medium' | 'low';  
  score: number;  
  warnings: string\[\];  
}

export interface RelatedEntity {  
  entity\_type: string;  
  entity\_id: number;  
  entity\_name: string;  
  relationship: string;  
}

export interface DrillDownData {  
  narrative: string;  
  visualizations: Visualization\[\];  
  confidence: ConfidenceInfo;  
  related\_entities: RelatedEntity\[\];  
  recommended\_actions: string\[\];  
  metadata: Record\<string, any\>;  
}

### **7.3 API Service**

Copy  
// src/services/api.service.ts  
import axios, { AxiosInstance } from 'axios';  
import { DashboardData, DrillDownRequest, DrillDownData } from '../types/dashboard.types';

class ApiService {  
  private client: AxiosInstance;

  constructor() {  
    this.client \= axios.create({  
      baseURL: process.env.REACT\_APP\_API\_URL || 'http://localhost:8000/api/v1',  
      timeout: 60000, // 60 seconds for complex queries  
      headers: {  
        'Content-Type': 'application/json',  
      },  
    });  
  }

  async getDashboard(year: number, quarter?: string): Promise\<DashboardData\> {  
    const params \= { year, ...(quarter && { quarter }) };  
    const response \= await this.client.get\<DashboardData\>('/dashboard/generate', { params });  
    return response.data;  
  }

  async drillDown(request: DrillDownRequest): Promise\<DrillDownData\> {  
    const response \= await this.client.post\<DrillDownData\>('/dashboard/drill-down', request);  
    return response.data;  
  }

  async askAgent(question: string, context?: Record\<string, any\>): Promise\<any\> {  
    const response \= await this.client.post('/agent/ask', { question, context });  
    return response.data;  
  }

  async getHealthCheck(): Promise\<any\> {  
    const response \= await this.client.get('/health/check');  
    return response.data;  
  }  
}

export const apiService \= new ApiService();

### **7.4 Zustand Store**

Copy  
// src/store/dashboardStore.ts  
import { create } from 'zustand';  
import { DashboardData, DrillDownData } from '../types/dashboard.types';

interface DashboardStore {  
  // State  
  dashboardData: DashboardData | null;  
  drillDownData: DrillDownData | null;  
  loading: boolean;  
  error: string | null;  
  currentYear: number;  
  currentQuarter: string | null;  
  drillDownStack: string\[\]; // Breadcrumb trail  
    
  // Actions  
  setDashboardData: (data: DashboardData) \=\> void;  
  setDrillDownData: (data: DrillDownData) \=\> void;  
  setLoading: (loading: boolean) \=\> void;  
  setError: (error: string | null) \=\> void;  
  setCurrentYear: (year: number) \=\> void;  
  setCurrentQuarter: (quarter: string | null) \=\> void;  
  pushDrillDown: (target: string) \=\> void;  
  popDrillDown: () \=\> void;  
  clearDrillDown: () \=\> void;  
}

export const useDashboardStore \= create\<DashboardStore\>((set) \=\> ({  
  // Initial state  
  dashboardData: null,  
  drillDownData: null,  
  loading: false,  
  error: null,  
  currentYear: new Date().getFullYear(),  
  currentQuarter: null,  
  drillDownStack: \[\],  
    
  // Actions  
  setDashboardData: (data) \=\> set({ dashboardData: data }),  
  setDrillDownData: (data) \=\> set({ drillDownData: data }),  
  setLoading: (loading) \=\> set({ loading }),  
  setError: (error) \=\> set({ error }),  
  setCurrentYear: (year) \=\> set({ currentYear: year }),  
  setCurrentQuarter: (quarter) \=\> set({ currentQuarter: quarter }),  
  pushDrillDown: (target) \=\> set((state) \=\> ({   
    drillDownStack: \[...state.drillDownStack, target\]   
  })),  
  popDrillDown: () \=\> set((state) \=\> ({   
    drillDownStack: state.drillDownStack.slice(0, \-1)   
  })),  
  clearDrillDown: () \=\> set({ drillDownStack: \[\], drillDownData: null }),  
}));

### **7.5 Custom Hooks**

Copy  
// src/hooks/useDashboard.ts  
import { useEffect } from 'react';  
import { useDashboardStore } from '../store/dashboardStore';  
import { apiService } from '../services/api.service';

export const useDashboard \= () \=\> {  
  const {   
    dashboardData,   
    loading,   
    error,   
    currentYear,   
    currentQuarter,  
    setDashboardData,  
    setLoading,  
    setError  
  } \= useDashboardStore();

  const loadDashboard \= async (year?: number, quarter?: string) \=\> {  
    setLoading(true);  
    setError(null);  
      
    try {  
      const data \= await apiService.getDashboard(  
        year || currentYear,   
        quarter || currentQuarter || undefined  
      );  
      setDashboardData(data);  
    } catch (err: any) {  
      setError(err.message || 'Failed to load dashboard');  
    } finally {  
      setLoading(false);  
    }  
  };

  useEffect(() \=\> {  
    loadDashboard();  
  }, \[currentYear, currentQuarter\]);

  return { dashboardData, loading, error, loadDashboard };  
};

Copy  
// src/hooks/useDrillDown.ts  
import { useDashboardStore } from '../store/dashboardStore';  
import { apiService } from '../services/api.service';  
import { DrillDownRequest } from '../types/dashboard.types';

export const useDrillDown \= () \=\> {  
  const {  
    drillDownData,  
    drillDownStack,  
    setDrillDownData,  
    setLoading,  
    setError,  
    pushDrillDown,  
    popDrillDown,  
    clearDrillDown,  
  } \= useDashboardStore();

  const performDrillDown \= async (request: DrillDownRequest) \=\> {  
    setLoading(true);  
    setError(null);  
      
    try {  
      const data \= await apiService.drillDown(request);  
      setDrillDownData(data);  
      pushDrillDown(request.target);  
    } catch (err: any) {  
      setError(err.message || 'Failed to perform drill-down');  
    } finally {  
      setLoading(false);  
    }  
  };

  const goBack \= () \=\> {  
    popDrillDown();  
    if (drillDownStack.length \=== 1) {  
      clearDrillDown();  
    }  
  };

  return {   
    drillDownData,   
    drillDownStack,   
    performDrillDown,   
    goBack,   
    clearDrillDown   
  };  
};

### **7.6 Zone 1: Transformation Health (Spider Chart)**

Copy  
// src/components/Dashboard/Zone1Health.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import HighchartsMore from 'highcharts/highcharts-more';  
import { Zone1Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

HighchartsMore(Highcharts);

interface Zone1HealthProps {  
  data: Zone1Data;  
  year: number;  
}

export const Zone1Health: React.FC\<Zone1HealthProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleDimensionClick \= (dimensionName: string, score: number) \=\> {  
    performDrillDown({  
      zone: 'transformation\_health',  
      target: dimensionName,  
      context: {  
        dimension: dimensionName,  
        year: year,  
      },  
    });  
  };

  const chartOptions: Highcharts.Options \= {  
    chart: {  
      polar: true,  
      type: 'line',  
      backgroundColor: 'transparent',  
    },  
      
    title: {  
      text: \`Transformation Health: ${data.overall\_health.toFixed(1)}%\`,  
      style: { color: '\#EBEBEB', fontSize: '18px', fontWeight: 'bold' },  
    },  
      
    pane: {  
      size: '80%',  
    },  
      
    xAxis: {  
      categories: data.dimensions.map(d \=\> d.name),  
      tickmarkPlacement: 'on',  
      lineWidth: 0,  
      labels: {  
        style: { color: '\#a0a0b0', fontSize: '11px' },  
      },  
    },  
      
    yAxis: {  
      gridLineInterpolation: 'polygon',  
      lineWidth: 0,  
      min: 0,  
      max: 100,  
      labels: {  
        style: { color: '\#a0a0b0' },  
      },  
    },  
      
    tooltip: {  
      shared: true,  
      pointFormat: '\<span style="color:{series.color}"\>{series.name}: \<b\>{point.y:.1f}%\</b\>\<br/\>',  
      backgroundColor: '\#2c2c38',  
      borderColor: '\#4a4a58',  
      style: { color: '\#EBEBEB' },  
    },  
      
    legend: {  
      align: 'center',  
      verticalAlign: 'bottom',  
      itemStyle: { color: '\#a0a0b0' },  
    },  
      
    series: \[  
      {  
        name: 'Current',  
        type: 'area',  
        data: data.dimensions.map(d \=\> d.score),  
        pointPlacement: 'on',  
        color: '\#00AEEF',  
        fillOpacity: 0.3,  
        cursor: 'pointer',  
        point: {  
          events: {  
            click: function() {  
              const dimensionName \= data.dimensions\[this.index\].name;  
              const score \= this.y as number;  
              handleDimensionClick(dimensionName, score);  
            },  
          },  
        },  
      },  
      {  
        name: 'Target',  
        type: 'line',  
        data: data.dimensions.map(d \=\> d.target),  
        pointPlacement: 'on',  
        color: '\#28a745',  
        dashStyle: 'Dash',  
        marker: { enabled: false },  
      },  
    \],  
      
    plotOptions: {  
      series: {  
        animation: { duration: 1000 },  
      },  
    },  
  };

  return (  
    \<div className\="zone-1 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 1: Transformation Health\</h2\>  
        \<p className\="text-sm text-muted"\>Click any dimension to drill down\</p\>  
      \</div\>  
        
      \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
        
      {/\* Dimension Indicators \*/}  
      \<div className\="grid grid-cols-4 gap-3 mt-6"\>  
        {data.dimensions.map((dim, idx) \=\> (  
          \<div  
            key\={idx}  
            className\="p-3 bg-secondary rounded cursor-pointer hover:bg-opacity-80 transition"  
            onClick\={() \=\> handleDimensionClick(dim.name, dim.score)}  
          \>  
            \<div className\="flex items-center justify-between mb-1"\>  
              \<span className\="text-xs text-muted"\>{dim.name}\</span\>  
              \<span className\={\`text-xs ${  
                dim.trend \=== 'improving' ? 'text-success' :   
                dim.trend \=== 'declining' ? 'text-danger' : 'text-warning'  
              }\`}\>  
                {dim.trend \=== 'improving' ? '↑' : dim.trend \=== 'declining' ? '↓' : '→'}  
              \</span\>  
            \</div\>  
            \<div className\="text-lg font-bold text-primary"\>{dim.score.toFixed(1)}%\</div\>  
            \<div className\="text-xs text-muted"\>Target: {dim.target}%\</div\>  
          \</div\>  
        ))}  
      \</div\>  
    \</div\>  
  );  
};

### **7.7 Zone 2: Strategic Insights (Bubble Chart)**

Copy  
// src/components/Dashboard/Zone2Insights.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import HighchartsMore from 'highcharts/highcharts-more';  
import { Zone2Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

HighchartsMore(Highcharts);

interface Zone2InsightsProps {  
  data: Zone2Data;  
  year: number;  
}

export const Zone2Insights: React.FC\<Zone2InsightsProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleBubbleClick \= (bubble: any) \=\> {  
    performDrillDown({  
      zone: 'strategic\_insights',  
      target: bubble.name,  
      context: {  
        entity\_table: 'ent\_projects',  
        entity\_id: bubble.project\_id,  
        year: year,  
      },  
    });  
  };

  const chartOptions: Highcharts.Options \= {  
    chart: {  
      type: 'bubble',  
      plotBorderWidth: 1,  
      zoomType: 'xy',  
      backgroundColor: 'transparent',  
    },  
      
    title: {  
      text: 'Strategic Insights: Objectives vs Projects',  
      style: { color: '\#EBEBEB', fontSize: '18px', fontWeight: 'bold' },  
    },  
      
    xAxis: {  
      title: { text: 'Project Progress (%)', style: { color: '\#a0a0b0' } },  
      min: 0,  
      max: 100,  
      gridLineWidth: 1,  
      gridLineColor: '\#4a4a58',  
      labels: { style: { color: '\#a0a0b0' } },  
    },  
      
    yAxis: {  
      title: { text: 'Impact Score', style: { color: '\#a0a0b0' } },  
      min: 0,  
      max: 100,  
      gridLineColor: '\#4a4a58',  
      labels: { style: { color: '\#a0a0b0' } },  
    },  
      
    tooltip: {  
      useHTML: true,  
      headerFormat: '\<table\>',  
      pointFormat:   
        '\<tr\>\<th colspan="2"\>\<h3\>{point.name}\</h3\>\</th\>\</tr\>' \+  
        '\<tr\>\<th\>Progress:\</th\>\<td\>{point.x}%\</td\>\</tr\>' \+  
        '\<tr\>\<th\>Impact:\</th\>\<td\>{point.y}\</td\>\</tr\>' \+  
        '\<tr\>\<th\>Budget:\</th\>\<td\>${point.z}M\</td\>\</tr\>' \+  
        '\<tr\>\<td colspan="2"\>\<i\>Click for details\</i\>\</td\>\</tr\>',  
      footerFormat: '\</table\>',  
      backgroundColor: '\#2c2c38',  
      borderColor: '\#4a4a58',  
      style: { color: '\#EBEBEB' },  
      followPointer: true,  
    },  
      
    legend: { enabled: false },  
      
    plotOptions: {  
      bubble: {  
        minSize: 20,  
        maxSize: 80,  
        cursor: 'pointer',  
        dataLabels: {  
          enabled: false,  
        },  
        point: {  
          events: {  
            click: function() {  
              handleBubbleClick(this.options);  
            },  
          },  
        },  
      },  
    },  
      
    series: \[  
      {  
        type: 'bubble',  
        name: 'Projects',  
        data: data.bubbles.map(b \=\> ({  
          x: b.x,  
          y: b.y,  
          z: b.z,  
          name: b.name,  
          project\_id: b.project\_id,  
          objective\_id: b.objective\_id,  
        })),  
        color: '\#00AEEF',  
      },  
    \],  
  };

  return (  
    \<div className\="zone-2 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 2: Strategic Insights\</h2\>  
        \<p className\="text-sm text-muted"\>Bubble size \= Budget allocation\</p\>  
      \</div\>  
        
      \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
    \</div\>  
  );  
};

### **7.8 Zone 3: Internal Outputs (Bullet Charts)**

Copy  
// src/components/Dashboard/Zone3Outputs.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import HighchartsBullet from 'highcharts/modules/bullet';  
import { Zone3Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

HighchartsBullet(Highcharts);

interface Zone3OutputsProps {  
  data: Zone3Data;  
  year: number;  
}

export const Zone3Outputs: React.FC\<Zone3OutputsProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleMetricClick \= (entityType: string) \=\> {  
    const tableMap: Record\<string, string\> \= {  
      'Capabilities': 'ent\_capabilities',  
      'Processes': 'ent\_processes',  
      'IT Systems': 'ent\_it\_systems',  
    };

    performDrillDown({  
      zone: 'internal\_outputs',  
      target: entityType,  
      context: {  
        entity\_table: tableMap\[entityType\],  
        year: year,  
      },  
    });  
  };

  return (  
    \<div className\="zone-3 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 3: Internal Outputs\</h2\>  
        \<p className\="text-sm text-muted"\>Click any metric to drill down\</p\>  
      \</div\>  
        
      \<div className\="space-y-6"\>  
        {data.metrics.map((metric, idx) \=\> {  
          const chartOptions: Highcharts.Options \= {  
            chart: {  
              type: 'bullet',  
              inverted: true,  
              marginLeft: 150,  
              height: 100,  
              backgroundColor: 'transparent',  
            },  
              
            title: {  
              text: metric.entity\_type,  
              style: { color: '\#EBEBEB', fontSize: '14px' },  
            },  
              
            xAxis: {  
              categories: \[''\],  
              labels: { enabled: false },  
            },  
              
            yAxis: {  
              min: 0,  
              max: metric.target\_value \* 1.2,  
              plotBands: \[  
                { from: 0, to: metric.target\_value \* 0.6, color: 'rgba(220, 53, 69, 0.3)' },  
                { from: metric.target\_value \* 0.6, to: metric.target\_value \* 0.9, color: 'rgba(255, 193, 7, 0.3)' },  
                { from: metric.target\_value \* 0.9, to: metric.target\_value \* 1.2, color: 'rgba(40, 167, 69, 0.3)' },  
              \],  
              title: null,  
              labels: { style: { color: '\#a0a0b0' } },  
            },  
              
            legend: { enabled: false },  
              
            tooltip: {  
              backgroundColor: '\#2c2c38',  
              borderColor: '\#4a4a58',  
              style: { color: '\#EBEBEB' },  
              pointFormat: '\<b\>{point.y:.1f}\</b\> (Target: {series.options.targetOptions.y:.1f})',  
            },  
              
            plotOptions: {  
              series: {  
                cursor: 'pointer',  
                point: {  
                  events: {  
                    click: () \=\> handleMetricClick(metric.entity\_type),  
                  },  
                },  
              },  
            },  
              
            series: \[  
              {  
                type: 'bullet',  
                data: \[  
                  {  
                    y: metric.current\_value,  
                    target: metric.target\_value,  
                  },  
                \],  
                color: '\#00AEEF',  
                targetOptions: {  
                  width: '140%',  
                  height: 3,  
                  borderWidth: 0,  
                  color: '\#28a745',  
                  y: metric.target\_value,  
                },  
              },  
            \],  
          };

          return (  
            \<div key\={idx} className\="cursor-pointer hover:opacity-80 transition"\>  
              \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
              \<div className\="flex justify-between text-xs text-muted mt-1"\>  
                \<span\>Current: {metric.current\_value.toFixed(1)}\</span\>  
                \<span\>Performance: {metric.performance\_percentage.toFixed(1)}%\</span\>  
                \<span\>Target: {metric.target\_value.toFixed(1)}\</span\>  
              \</div\>  
            \</div\>  
          );  
        })}  
      \</div\>  
    \</div\>  
  );  
};

### **7.9 Zone 4: Sector Outcomes (Combo Chart)**

Copy  
// src/components/Dashboard/Zone4Outcomes.tsx  
import React from 'react';  
import Highcharts from 'highcharts';  
import HighchartsReact from 'highcharts-react-official';  
import { Zone4Data } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

interface Zone4OutcomesProps {  
  data: Zone4Data;  
  year: number;  
}

export const Zone4Outcomes: React.FC\<Zone4OutcomesProps\> \= ({ data, year }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleSectorClick \= (sector: string) \=\> {  
    const tableMap: Record\<string, string\> \= {  
      'Citizens': 'sec\_citizens',  
      'Businesses': 'sec\_businesses',  
      'Transactions': 'sec\_data\_transactions',  
    };

    performDrillDown({  
      zone: 'sector\_outcomes',  
      target: sector,  
      context: {  
        entity\_table: tableMap\[sector\],  
        year: year,  
      },  
    });  
  };

  const chartOptions: Highcharts.Options \= {  
    chart: {  
      type: 'column',  
      backgroundColor: 'transparent',  
    },  
      
    title: {  
      text: 'Sector-Level Outcomes',  
      style: { color: '\#EBEBEB', fontSize: '18px', fontWeight: 'bold' },  
    },  
      
    xAxis: {  
      categories: data.outcomes.map(o \=\> o.sector),  
      labels: { style: { color: '\#a0a0b0' } },  
    },  
      
    yAxis: {  
      min: 0,  
      max: 100,  
      title: { text: 'Score', style: { color: '\#a0a0b0' } },  
      labels: { style: { color: '\#a0a0b0' } },  
      gridLineColor: '\#4a4a58',  
    },  
      
    tooltip: {  
      backgroundColor: '\#2c2c38',  
      borderColor: '\#4a4a58',  
      style: { color: '\#EBEBEB' },  
      shared: true,  
    },  
      
    legend: {  
      itemStyle: { color: '\#a0a0b0' },  
    },  
      
    plotOptions: {  
      column: {  
        cursor: 'pointer',  
        point: {  
          events: {  
            click: function() {  
              handleSectorClick(this.category as string);  
            },  
          },  
        },  
      },  
      line: {  
        marker: { enabled: false },  
      },  
    },  
      
    series: \[  
      {  
        type: 'column',  
        name: 'Current Value',  
        data: data.outcomes.map(o \=\> o.value),  
        color: '\#00AEEF',  
      },  
      {  
        type: 'line',  
        name: 'Target',  
        data: data.outcomes.map(o \=\> o.target),  
        color: '\#28a745',  
        dashStyle: 'Dash',  
      },  
    \],  
  };

  return (  
    \<div className\="zone-4 bg-panel rounded-lg p-6 shadow-lg"\>  
      \<div className\="mb-4"\>  
        \<h2 className\="text-xl font-bold text-primary"\>Zone 4: Sector Outcomes\</h2\>  
        \<p className\="text-sm text-muted"\>Click any sector to drill down\</p\>  
      \</div\>  
        
      \<HighchartsReact highcharts\={Highcharts} options\={chartOptions} /\>  
        
      {/\* Trend Sparklines \*/}  
      \<div className\="grid grid-cols-3 gap-4 mt-6"\>  
        {data.outcomes.map((outcome, idx) \=\> (  
          \<div  
            key\={idx}  
            className\="p-3 bg-secondary rounded cursor-pointer hover:bg-opacity-80 transition"  
            onClick\={() \=\> handleSectorClick(outcome.sector)}  
          \>  
            \<div className\="text-sm text-muted mb-1"\>{outcome.sector}\</div\>  
            \<div className\="text-xl font-bold text-primary"\>{outcome.value.toFixed(1)}%\</div\>  
            \<div className\="text-xs text-muted"\>Target: {outcome.target}%\</div\>  
            {/\* Simple sparkline visualization \*/}  
            \<div className\="mt-2 flex items-end space-x-1" style\={{ height: '30px' }}\>  
              {outcome.trend.map((val, i) \=\> (  
                \<div  
                  key\={i}  
                  className\="flex-1 bg-accent rounded-t"  
                  style\={{ height: \`${(val / 100) \* 100}%\` }}  
                /\>  
              ))}  
            \</div\>  
          \</div\>  
        ))}  
      \</div\>  
    \</div\>  
  );  
};

### **7.10 Main Dashboard Container**

Copy  
// src/components/Dashboard/Dashboard.tsx  
import React, { useEffect } from 'react';  
import { useDashboard } from '../../hooks/useDashboard';  
import { useDashboardStore } from '../../store/dashboardStore';  
import { Zone1Health } from './Zone1Health';  
import { Zone2Insights } from './Zone2Insights';  
import { Zone3Outputs } from './Zone3Outputs';  
import { Zone4Outcomes } from './Zone4Outcomes';  
import { LoadingState } from './LoadingState';

export const Dashboard: React.FC \= () \=\> {  
  const { dashboardData, loading, error, loadDashboard } \= useDashboard();  
  const { currentYear, currentQuarter, setCurrentYear, setCurrentQuarter } \= useDashboardStore();

  if (loading) {  
    return \<LoadingState /\>;  
  }

  if (error) {  
    return (  
      \<div className\="flex items-center justify-center min-h-screen bg-primary"\>  
        \<div className\="text-center"\>  
          \<div className\="text-danger text-xl mb-4"\>⚠️ Error Loading Dashboard\</div\>  
          \<div className\="text-muted"\>{error}\</div\>  
          \<button  
            onClick\={() \=\> loadDashboard()}  
            className="mt-4 px-6 py-2 bg-accent text-white rounded hover:bg-opacity-80 transition"  
          \>  
            Retry  
          \</button\>  
        \</div\>  
      \</div\>  
    );  
  }

  if (\!dashboardData) {  
    return null;  
  }

  return (  
    \<div className\="min-h-screen bg-primary p-6"\>  
      {/\* Header \*/}  
      \<div className\="mb-6 flex items-center justify-between"\>  
        \<div\>  
          \<h1 className\="text-3xl font-bold text-primary"\>Transformation Analytics Dashboard\</h1\>  
          \<p className\="text-muted"\>  
            Holistic view of transformation program health and performance  
          \</p\>  
        \</div\>  
          
        {/\* Year/Quarter Selector \*/}  
        \<div className\="flex space-x-4"\>  
          \<select  
            value\={currentYear}  
            onChange\={(e) \=\> setCurrentYear(Number(e.target.value))}  
            className="px-4 py-2 bg-panel border border-border rounded text-primary"  
          \>  
            {\[2024, 2023, 2022, 2021\].map(year \=\> (  
              \<option key\={year} value\={year}\>{year}\</option\>  
            ))}  
          \</select\>  
            
          \<select  
            value\={currentQuarter || ''}  
            onChange\={(e) \=\> setCurrentQuarter(e.target.value || null)}  
            className="px-4 py-2 bg-panel border border-border rounded text-primary"  
          \>  
            \<option value\=""\>All Quarters\</option\>  
            \<option value\="Q1"\>Q1\</option\>  
            \<option value\="Q2"\>Q2\</option\>  
            \<option value\="Q3"\>Q3\</option\>  
            \<option value\="Q4"\>Q4\</option\>  
          \</select\>  
        \</div\>  
      \</div\>  
        
      {/\* 4-Zone Grid Layout \*/}  
      \<div className\="grid grid-cols-2 gap-6"\>  
        \<Zone1Health data\={dashboardData.zone1} year\={currentYear} /\>  
        \<Zone2Insights data\={dashboardData.zone2} year\={currentYear} /\>  
        \<Zone3Outputs data\={dashboardData.zone3} year\={currentYear} /\>  
        \<Zone4Outcomes data\={dashboardData.zone4} year\={currentYear} /\>  
      \</div\>  
        
      {/\* Cache Indicator \*/}  
      {dashboardData.cache\_hit && (  
        \<div className\="mt-4 text-xs text-muted text-center"\>  
          ⚡ Data loaded from cache (generated at {new Date(dashboardData.generated\_at).toLocaleString()})  
        \</div\>  
      )}  
    \</div\>  
  );  
};

---

## **8\. DRILL-DOWN SYSTEM IMPLEMENTATION**

### **8.1 Drill-Down Panel Component**

Copy  
// src/components/DrillDown/DrillDownPanel.tsx  
import React from 'react';  
import { useDrillDown } from '../../hooks/useDrillDown';  
import { DrillDownContent } from './DrillDownContent';  
import { Breadcrumbs } from '../Common/Breadcrumbs';  
import { ConfidenceBadge } from '../Common/ConfidenceBadge';

export const DrillDownPanel: React.FC \= () \=\> {  
  const { drillDownData, drillDownStack, goBack, clearDrillDown } \= useDrillDown();

  if (\!drillDownData) {  
    return null;  
  }

  return (  
    \<div className\="fixed inset-y-0 right-0 w-2/3 bg-panel shadow-2xl z-50 overflow-hidden flex flex-col animate-slide-in"\>  
      {/\* Header \*/}  
      \<div className\="flex items-center justify-between p-6 border-b border-border"\>  
        \<div className\="flex-1"\>  
          \<Breadcrumbs items\={\['Dashboard', ...drillDownStack\]} onNavigate\={goBack} /\>  
          \<h2 className\="text-2xl font-bold text-primary mt-2"\>  
            {drillDownStack\[drillDownStack.length \- 1\]}  
          \</h2\>  
        \</div\>  
          
        \<button  
          onClick\={clearDrillDown}  
          className\="text-muted hover:text-primary transition text-3xl"  
          aria-label\="Close"  
        \>  
          ×  
        \</button\>  
      \</div\>  
        
      {/\* Confidence Badge \*/}  
      \<div className\="px-6 py-3 bg-secondary"\>  
        \<ConfidenceBadge confidence\={drillDownData.confidence} /\>  
      \</div\>  
        
      {/\* Content \*/}  
      \<div className\="flex-1 overflow-y-auto p-6"\>  
        \<DrillDownContent data\={drillDownData} /\>  
      \</div\>  
        
      {/\* Footer Actions \*/}  
      \<div className\="p-6 border-t border-border bg-secondary flex space-x-4"\>  
        \<button  
          onClick\={goBack}  
          className\="px-6 py-2 bg-panel border border-border rounded hover:bg-primary transition"  
        \>  
          ← Back  
        \</button\>  
        \<button  
          onClick\={() \=\> {/\* Open chat interface \*/}}  
          className="px-6 py-2 bg-accent text-white rounded hover:bg-opacity-80 transition"  
        \>  
          💬 Ask Follow-up Question  
        \</button\>  
        \<button  
          onClick\={() \=\> {/\* Export PDF \*/}}  
          className="px-6 py-2 bg-success text-white rounded hover:bg-opacity-80 transition"  
        \>  
          📤 Export Report  
        \</button\>  
      \</div\>  
    \</div\>  
  );  
};

### **8.2 Drill-Down Content Renderer**

Copy  
// src/components/DrillDown/DrillDownContent.tsx  
import React from 'react';  
import { DrillDownData } from '../../types/dashboard.types';  
import { VisualizationGallery } from './VisualizationGallery';  
import { RelatedEntities } from './RelatedEntities';

interface DrillDownContentProps {  
  data: DrillDownData;  
}

export const DrillDownContent: React.FC\<DrillDownContentProps\> \= ({ data }) \=\> {  
  return (  
    \<div className\="space-y-8"\>  
      {/\* Narrative Insights \*/}  
      \<div className\="prose prose-invert max-w-none"\>  
        \<div  
          className\="text-primary leading-relaxed"  
          dangerouslySetInnerHTML\={{ \_\_html: formatMarkdown(data.narrative) }}  
        /\>  
      \</div\>  
        
      {/\* Visualizations \*/}  
      {data.visualizations.length \> 0 && (  
        \<div\>  
          \<h3 className\="text-xl font-bold text-primary mb-4"\>Visualizations\</h3\>  
          \<VisualizationGallery visualizations\={data.visualizations} /\>  
        \</div\>  
      )}  
        
      {/\* Related Entities \*/}  
      {data.related\_entities.length \> 0 && (  
        \<div\>  
          \<h3 className\="text-xl font-bold text-primary mb-4"\>Related Entities\</h3\>  
          \<RelatedEntities entities\={data.related\_entities} /\>  
        \</div\>  
      )}  
        
      {/\* Recommended Actions \*/}  
      {data.recommended\_actions.length \> 0 && (  
        \<div\>  
          \<h3 className\="text-xl font-bold text-primary mb-4"\>Recommended Actions\</h3\>  
          \<ul className\="space-y-2"\>  
            {data.recommended\_actions.map((action, idx) \=\> (  
              \<li key\={idx} className\="flex items-start space-x-3"\>  
                \<span className\="text-accent font-bold"\>{idx \+ 1}.\</span\>  
                \<span className\="text-primary"\>{action}\</span\>  
              \</li\>  
            ))}  
          \</ul\>  
        \</div\>  
      )}  
    \</div\>  
  );  
};

// Helper function to convert markdown-style text to HTML  
function formatMarkdown(text: string): string {  
  return text  
    .replace(/\\\*\\\*(.\*?)\\\*\\\*/g, '\<strong\>$1\</strong\>')  
    .replace(/\\\*(.\*?)\\\*/g, '\<em\>$1\</em\>')  
    .replace(/^\#\#\# (.\*$)/gim, '\<h3\>$1\</h3\>')  
    .replace(/^\#\# (.\*$)/gim, '\<h2\>$1\</h2\>')  
    .replace(/^\# (.\*$)/gim, '\<h1\>$1\</h1\>')  
    .replace(/^• (.\*$)/gim, '\<li\>$1\</li\>')  
    .replace(/\\n\\n/g, '\</p\>\<p\>')  
    .replace(/\\n/g, '\<br/\>');  
}

### **8.3 Visualization Gallery**

Copy  
// src/components/DrillDown/VisualizationGallery.tsx  
import React, { useState } from 'react';  
import { Visualization } from '../../types/dashboard.types';

interface VisualizationGalleryProps {  
  visualizations: Visualization\[\];  
}

export const VisualizationGallery: React.FC\<VisualizationGalleryProps\> \= ({ visualizations }) \=\> {  
  const \[selectedIndex, setSelectedIndex\] \= useState(0);

  const currentViz \= visualizations\[selectedIndex\];

  return (  
    \<div className\="space-y-4"\>  
      {/\* Main Display \*/}  
      \<div className\="bg-secondary rounded-lg p-4"\>  
        \<h4 className\="text-lg font-bold text-primary mb-2"\>{currentViz.title}\</h4\>  
        \<p className\="text-sm text-muted mb-4"\>{currentViz.description}\</p\>  
          
        \<div className\="flex justify-center"\>  
          \<img  
            src\={\`data:image/png;base64,${currentViz.image\_base64}\`}  
            alt\={currentViz.title}  
            className\="max-w-full h-auto rounded"  
          /\>  
        \</div\>  
      \</div\>  
        
      {/\* Thumbnail Navigation \*/}  
      {visualizations.length \> 1 && (  
        \<div className\="flex space-x-3 overflow-x-auto"\>  
          {visualizations.map((viz, idx) \=\> (  
            \<div  
              key\={idx}  
              onClick\={() \=\> setSelectedIndex(idx)}  
              className={\`cursor-pointer flex-shrink-0 w-32 h-24 rounded overflow-hidden border-2 transition ${  
                idx \=== selectedIndex ? 'border-accent' : 'border-border opacity-50'  
              }\`}  
            \>  
              \<img  
                src\={\`data:image/png;base64,${viz.image\_base64}\`}  
                alt\={viz.title}  
                className\="w-full h-full object-cover"  
              /\>  
            \</div\>  
          ))}  
        \</div\>  
      )}  
    \</div\>  
  );  
};

### **8.4 Related Entities List**

Copy  
// src/components/DrillDown/RelatedEntities.tsx  
import React from 'react';  
import { RelatedEntity } from '../../types/dashboard.types';  
import { useDrillDown } from '../../hooks/useDrillDown';

interface RelatedEntitiesProps {  
  entities: RelatedEntity\[\];  
}

export const RelatedEntities: React.FC\<RelatedEntitiesProps\> \= ({ entities }) \=\> {  
  const { performDrillDown } \= useDrillDown();

  const handleEntityClick \= (entity: RelatedEntity) \=\> {  
    performDrillDown({  
      zone: 'internal\_outputs', // Default zone  
      target: entity.entity\_name,  
      context: {  
        entity\_table: entity.entity\_type.toLowerCase().replace(' ', '\_'),  
        entity\_id: entity.entity\_id,  
        year: new Date().getFullYear(),  
      },  
    });  
  };

  return (  
    \<div className\="grid grid-cols-2 gap-4"\>  
      {entities.map((entity, idx) \=\> (  
        \<div  
          key\={idx}  
          onClick\={() \=\> handleEntityClick(entity)}  
          className="p-4 bg-secondary rounded-lg cursor-pointer hover:bg-opacity-80 transition"  
        \>  
          \<div className\="flex items-center justify-between mb-2"\>  
            \<span className\="text-sm text-muted"\>{entity.entity\_type}\</span\>  
            \<span className\="text-xs text-accent"\>{entity.relationship}\</span\>  
          \</div\>  
          \<div className\="text-lg font-bold text-primary"\>{entity.entity\_name}\</div\>  
          \<div className\="text-xs text-muted mt-1"\>ID: {entity.entity\_id}\</div\>  
        \</div\>  
      ))}  
    \</div\>  
  );  
};

### **8.5 Common Components**

Copy  
// src/components/Common/ConfidenceBadge.tsx  
import React from 'react';  
import { ConfidenceInfo } from '../../types/dashboard.types';

interface ConfidenceBadgeProps {  
  confidence: ConfidenceInfo;  
}

export const ConfidenceBadge: React.FC\<ConfidenceBadgeProps\> \= ({ confidence }) \=\> {  
  const getColor \= () \=\> {  
    if (confidence.level \=== 'high') return 'bg-success';  
    if (confidence.level \=== 'medium') return 'bg-warning';  
    return 'bg-danger';  
  };

  return (  
    \<div className\="flex items-center space-x-4"\>  
      \<div className\="flex items-center space-x-2"\>  
        \<span className\="text-muted text-sm"\>Confidence:\</span\>  
        \<span className\={\`px-3 py-1 rounded-full text-white text-sm font-bold ${getColor()}\`}\>  
          {confidence.level.toUpperCase()}  
        \</span\>  
        \<span className\="text-muted text-sm"\>({(confidence.score \* 100).toFixed(0)}%)\</span\>  
      \</div\>  
        
      {confidence.warnings.length \> 0 && (  
        \<div className\="flex items-start space-x-2"\>  
          \<span className\="text-warning text-sm"\>⚠️\</span\>  
          \<div className\="text-xs text-muted"\>  
            {confidence.warnings.map((warning, idx) \=\> (  
              \<div key\={idx}\>{warning}\</div\>  
            ))}  
          \</div\>  
        \</div\>  
      )}  
    \</div\>  
  );  
};

Copy  
// src/components/Common/Breadcrumbs.tsx  
import React from 'react';

interface BreadcrumbsProps {  
  items: string\[\];  
  onNavigate: () \=\> void;  
}

export const Breadcrumbs: React.FC\<BreadcrumbsProps\> \= ({ items, onNavigate }) \=\> {  
  return (  
    \<nav className\="flex items-center space-x-2 text-sm text-muted"\>  
      {items.map((item, idx) \=\> (  
        \<React.Fragment key\={idx}\>  
          {idx \> 0 && \<span\>›\</span\>}  
          \<button  
            onClick\={idx \< items.length \- 1 ? onNavigate : undefined}  
            className\={\`hover:text-primary transition ${  
              idx \=== items.length \- 1 ? 'font-bold text-primary' : ''  
            }\`}  
          \>  
            {item}  
          \</button\>  
        \</React.Fragment\>  
      ))}  
    \</nav\>  
  );  
};

---

## **9\. DEPLOYMENT ARCHITECTURE**

### **9.1 Docker Compose Configuration**

Copy  
\# docker-compose.yml  
version: '3.8'

services:  
  \# Backend API (FastAPI)  
  backend:  
    build:  
      context: ./backend  
      dockerfile: Dockerfile  
    container\_name: analytics-backend  
    ports:  
      \- "8000:8000"  
    environment:  
      \- SUPABASE\_URL=${SUPABASE\_URL}  
      \- SUPABASE\_KEY=${SUPABASE\_KEY}  
      \- OPENAI\_API\_KEY=${OPENAI\_API\_KEY}  
      \- QDRANT\_URL=http://qdrant:6333  
      \- REDIS\_URL=redis://redis:6379  
    depends\_on:  
      \- redis  
      \- qdrant  
    volumes:  
      \- ./backend:/app  
      \- ./data:/app/data  
    command: uvicorn app.main:app \--host 0.0.0.0 \--port 8000 \--reload  
    
  \# Frontend (React)  
  frontend:  
    build:  
      context: ./frontend  
      dockerfile: Dockerfile  
    container\_name: analytics-frontend  
    ports:  
      \- "3000:3000"  
    environment:  
      \- REACT\_APP\_API\_URL=http://localhost:8000/api/v1  
    volumes:  
      \- ./frontend:/app  
      \- /app/node\_modules  
    command: npm start  
    
  \# Redis Cache  
  redis:  
    image: redis:7-alpine  
    container\_name: analytics-redis  
    ports:  
      \- "6379:6379"  
    volumes:  
      \- redis-data:/data  
    
  \# Qdrant Vector Database  
  qdrant:  
    image: qdrant/qdrant:latest  
    container\_name: analytics-qdrant  
    ports:  
      \- "6333:6333"  
      \- "6334:6334"  
    volumes:  
      \- qdrant-storage:/qdrant/storage  
    
  \# Nginx Reverse Proxy  
  nginx:  
    image: nginx:alpine  
    container\_name: analytics-nginx  
    ports:  
      \- "80:80"  
      \- "443:443"  
    volumes:  
      \- ./nginx/nginx.conf:/etc/nginx/nginx.conf  
      \- ./nginx/ssl:/etc/nginx/ssl  
    depends\_on:  
      \- backend  
      \- frontend

volumes:  
  redis-data:  
  qdrant-storage:

### **9.2 Backend Dockerfile**

Copy  
\# backend/Dockerfile  
FROM python:3.11\-slim

WORKDIR /app

\# Install system dependencies  
RUN apt-get update && apt-get install \-y \\  
    gcc \\  
    g++ \\  
    libpq-dev \\  
    && rm \-rf /var/lib/apt/lists/\*

\# Copy requirements  
COPY requirements.txt .  
RUN pip install \--no-cache-dir \-r requirements.txt

\# Copy application code  
COPY . .

\# Expose port  
EXPOSE 8000

\# Run application  
CMD \["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"\]

### **9.3 Frontend Dockerfile**

Copy  
\# frontend/Dockerfile  
FROM node:18\-alpine

WORKDIR /app

\# Copy package files  
COPY package\*.json ./  
RUN npm install

\# Copy application code  
COPY . .

\# Build for production  
RUN npm run build

\# Expose port  
EXPOSE 3000

\# Run application  
CMD \["npm", "start"\]

### **9.4 Nginx Configuration**

Copy  
\# nginx/nginx.conf  
**events** {  
    worker\_connections 1024;  
}

**http** {  
    **upstream** backend {  
        server backend:8000;  
    }  
      
    **upstream** frontend {  
        server frontend:3000;  
    }  
      
    **server** {  
        listen 80;  
        server\_name localhost;  
          
        \# Frontend  
        **location** / {  
            proxy\_pass http://frontend;  
            proxy\_http\_version 1.1;  
            proxy\_set\_header Upgrade $http\_upgrade;  
            proxy\_set\_header Connection 'upgrade';  
            proxy\_set\_header Host $host;  
            proxy\_cache\_bypass $http\_upgrade;  
        }  
          
        \# Backend API  
        **location** /api/ {  
            proxy\_pass http://backend;  
            proxy\_http\_version 1.1;  
            proxy\_set\_header Host $host;  
            proxy\_set\_header X-Real-IP $remote\_addr;  
            proxy\_set\_header X-Forwarded-For $proxy\_add\_x\_forwarded\_for;  
            proxy\_set\_header X-Forwarded-Proto $scheme;  
              
            \# CORS headers  
            add\_header 'Access-Control-Allow-Origin' '\*' always;  
            add\_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;  
            add\_header 'Access-Control-Allow-Headers' 'Content-Type' always;  
        }  
    }  
}

---

## **10\. TESTING STRATEGY**

### **10.1 Backend Tests**

Copy  
\# tests/test\_dashboard.py  
import pytest  
from app.services.dashboard\_generator import DashboardGenerator  
from app.services.dimension\_calculator import DimensionCalculator

@pytest.mark.asyncio  
async def test\_dashboard\_generation(dashboard\_generator):  
    """Test complete dashboard generation"""  
    result \= await dashboard\_generator.generate\_dashboard(year=2024, quarter="Q1")  
      
    assert result.year \== 2024  
    assert result.zone1 is not None  
    assert len(result.zone1.dimensions) \== 8  
    assert result.zone1.overall\_health \>= 0  
    assert result.zone1.overall\_health \<= 100

@pytest.mark.asyncio  
async def test\_dimension\_calculation(dimension\_calculator):  
    """Test individual dimension calculation"""  
    result \= await dimension\_calculator.calculate\_single\_dimension(  
        dimension\_name="Strategic Alignment",  
        year=2024,  
        quarter="Q1"  
    )  
      
    assert result\["name"\] \== "Strategic Alignment"  
    assert 0 \<= result\["score"\] \<= 100  
    assert result\["trend"\] in \["improving", "declining", "stable"\]

@pytest.mark.asyncio  
async def test\_drill\_down(dashboard\_generator):  
    """Test drill-down functionality"""  
    from app.models.schemas import DrillDownRequest, DrillDownContext  
      
    request \= DrillDownRequest(  
        zone="transformation\_health",  
        target="IT Systems",  
        context=DrillDownContext(  
            dimension="IT Systems",  
            entity\_table="ent\_it\_systems",  
            year=2024  
        )  
    )  
      
    result \= await dashboard\_generator.drill\_down(request)  
      
    assert result.narrative is not None  
    assert len(result.visualizations) \> 0  
    assert result.confidence.level in \["high", "medium", "low"\]

### **10.2 Frontend Tests**

Copy  
// src/components/Dashboard/\_\_tests\_\_/Dashboard.test.tsx  
import { render, screen, waitFor } from '@testing-library/react';  
import { Dashboard } from '../Dashboard';  
import { apiService } from '../../../services/api.service';

jest.mock('../../../services/api.service');

describe('Dashboard Component', () \=\> {  
  it('renders all 4 zones', async () \=\> {  
    const mockData \= {  
      year: 2024,  
      zone1: { dimensions: \[\], overall\_health: 75 },  
      zone2: { bubbles: \[\] },  
      zone3: { metrics: \[\] },  
      zone4: { outcomes: \[\] },  
      generated\_at: new Date().toISOString(),  
      cache\_hit: false,  
    };  
      
    (apiService.getDashboard as jest.Mock).mockResolvedValue(mockData);  
      
    render(\<Dashboard /\>);  
      
    await waitFor(() \=\> {  
      expect(screen.getByText('Zone 1: Transformation Health')).toBeInTheDocument();  
      expect(screen.getByText('Zone 2: Strategic Insights')).toBeInTheDocument();  
      expect(screen.getByText('Zone 3: Internal Outputs')).toBeInTheDocument();  
      expect(screen.getByText('Zone 4: Sector Outcomes')).toBeInTheDocument();  
    });  
  });  
});

---

## **11\. FILE STRUCTURE & CODE ORGANIZATION**

transformation-analytics-platform/  
├── backend/  
│   ├── app/  
│   │   ├── \_\_init\_\_.py  
│   │   ├── main.py  
│   │   ├── config.py  
│   │   ├── dependencies.py  
│   │   ├── api/  
│   │   │   └── v1/  
│   │   │       ├── dashboard.py  
│   │   │       ├── agent.py  
│   │   │       ├── ingest.py  
│   │   │       └── health.py  
│   │   ├── services/  
│   │   │   ├── dashboard\_generator.py  
│   │   │   ├── dimension\_calculator.py  
│   │   │   ├── autonomous\_agent.py  
│   │   │   ├── intent\_memory.py  
│   │   │   ├── retrieval\_memory.py  
│   │   │   ├── analytical\_memory.py  
│   │   │   ├── visualization\_memory.py  
│   │   │   ├── agent\_feed\_pipeline.py  
│   │   │   └── confidence\_tracker.py  
│   │   ├── models/  
│   │   │   ├── database.py  
│   │   │   ├── schemas.py  
│   │   │   └── world\_view\_map.py  
│   │   ├── db/  
│   │   │   ├── supabase\_client.py  
│   │   │   ├── vector\_client.py  
│   │   │   └── redis\_client.py  
│   │   └── utils/  
│   │       ├── statistical\_analyzer.py  
│   │       ├── query\_builder.py  
│   │       └── chart\_generator.py  
│   ├── tests/  
│   ├── data/  
│   │   ├── worldviewmap.json  
│   │   └── gov-model-v2.json  
│   ├── requirements.txt  
│   └── Dockerfile  
│  
├── frontend/  
│   ├── public/  
│   ├── src/  
│   │   ├── App.tsx  
│   │   ├── index.tsx  
│   │   ├── types/  
│   │   ├── components/  
│   │   │   ├── Dashboard/  
│   │   │   ├── DrillDown/  
│   │   │   ├── Chat/  
│   │   │   └── Common/  
│   │   ├── services/  
│   │   ├── hooks/  
│   │   ├── store/  
│   │   ├── utils/  
│   │   └── styles/  
│   ├── package.json  
│   ├── tsconfig.json  
│   └── Dockerfile  
│  
├── nginx/  
│   ├── nginx.conf  
│   └── ssl/  
│  
├── docker-compose.yml  
├── .env.example  
└── README.md

---

## **12\. STEP-BY-STEP IMPLEMENTATION GUIDE**

### **Phase 1: Database Setup (Week 1\)**

Copy  
\# Step 1: Set up Supabase project  
\# 1\. Go to https://supabase.com  
\# 2\. Create new project  
\# 3\. Get URL and anon key  
\# 4\. Run database schema SQL (Section 3.1)

\# Step 2: Set up Vector DB  
docker run \-p 6333:6333 qdrant/qdrant

\# Step 3: Create collections  
python scripts/setup\_vector\_db.py

### **Phase 2: Backend Implementation (Week 2-3)**

Copy  
\# Step 1: Create project structure  
mkdir \-p backend/app/{api/v1,services,models,db,utils}  
cd backend

\# Step 2: Install dependencies  
pip install fastapi uvicorn supabase qdrant-client redis scipy matplotlib openai pydantic sqlalchemy

\# Step 3: Implement core services (in order)  
\# 1\. app/db/supabase\_client.py  
\# 2\. app/models/schemas.py  
\# 3\. app/services/dimension\_calculator.py  
\# 4\. app/services/dashboard\_generator.py  
\# 5\. app/services/autonomous\_agent.py (layers 1-4)  
\# 6\. app/api/v1/dashboard.py  
\# 7\. app/main.py

\# Step 4: Test locally  
uvicorn app.main:app \--reload

\# Step 5: Test API endpoints  
curl http://localhost:8000/api/v1/dashboard/generate?year=2024

### **Phase 3: Frontend Implementation (Week 4\)**

Copy  
\# Step 1: Create React app  
npx create-react-app frontend \--template typescript  
cd frontend

\# Step 2: Install dependencies  
npm install highcharts highcharts-react-official axios zustand react-query tailwindcss

\# Step 3: Implement components (in order)  
\# 1\. src/types/dashboard.types.ts  
\# 2\. src/services/api.service.ts  
\# 3\. src/store/dashboardStore.ts  
\# 4\. src/hooks/useDashboard.ts  
\# 5\. src/components/Dashboard/Zone1Health.tsx (and other zones)  
\# 6\. src/components/Dashboard/Dashboard.tsx  
\# 7\. src/components/DrillDown/DrillDownPanel.tsx

\# Step 4: Test locally  
npm start

### **Phase 4: Integration (Week 5\)**

Copy  
\# Step 1: Create docker-compose.yml  
\# Step 2: Build containers  
docker-compose build

\# Step 3: Start all services  
docker-compose up

\# Step 4: Test end-to-end flow  
\# 1\. Open http://localhost:3000  
\# 2\. Verify dashboard loads  
\# 3\. Test drill-down by clicking dimensions  
\# 4\. Test chat interface

### **Phase 5: Data Population (Week 6\)**

Copy  
\# Step 1: Create sample data generator  
python scripts/generate\_sample\_data.py \--year 2024

\# Step 2: Ingest data via API  
curl \-X POST http://localhost:8000/api/v1/ingest/structured \\  
  \-H "Content-Type: application/json" \\  
  \-d @sample\_data/projects.json

\# Step 3: Ingest documents  
curl \-X POST http://localhost:8000/api/v1/ingest/unstructured \\  
  \-H "Content-Type: application/json" \\  
  \-d @sample\_data/strategy\_docs.json

\# Step 4: Refresh materialized views  
psql $SUPABASE\_URL \-c "SELECT refresh\_dashboard\_materialized\_views();"

### **Phase 6: Testing & QA (Week 7\)**

Copy  
\# Backend tests  
cd backend  
pytest tests/ \-v \--cov=app

\# Frontend tests  
cd frontend  
npm test \-- \--coverage

\# Integration tests  
python tests/integration/test\_e2e.py

### **Phase 7: Deployment (Week 8\)**

Copy  
\# Step 1: Set up production environment  
\# 1\. Configure .env.production  
\# 2\. Set up SSL certificates  
\# 3\. Configure domain DNS

\# Step 2: Deploy to production  
docker-compose \-f docker-compose.prod.yml up \-d

\# Step 3: Health check  
curl https://your-domain.com/api/v1/health/check

\# Step 4: Monitor logs  
docker-compose logs \-f backend

---

## **13\. ENVIRONMENT CONFIGURATION**

Copy  
\# .env.example  
\# Copy to .env and fill in values

\# Supabase  
SUPABASE\_URL=https://your-project.supabase.co  
SUPABASE\_KEY=your-anon-key

\# OpenAI  
OPENAI\_API\_KEY=sk-...

\# Qdrant  
QDRANT\_URL=http://localhost:6333

\# Redis  
REDIS\_URL=redis://localhost:6379

\# Frontend  
REACT\_APP\_API\_URL=http://localhost:8000/api/v1

---

## **14\. REQUIREMENTS FILES**

Copy  
\# backend/requirements.txt  
fastapi==0.104.1  
uvicorn\[standard\]==0.24.0  
pydantic==2.5.0  
pydantic-settings==2.1.0  
supabase==2.0.3  
qdrant-client==1.7.0  
redis==5.0.1  
scipy==1.11.4  
matplotlib==3.8.2  
openai==1.3.7  
sqlalchemy==2.0.23  
psycopg2-binary==2.9.9  
python-multipart==0.0.6  
pytest==7.4.3  
pytest-asyncio==0.21.1  
pytest-cov==4.1.0  
black==23.12.0

Copy  
// frontend/package.json  
{  
  "name": "transformation-analytics-frontend",  
  "version": "1.0.0",  
  "dependencies": {  
    "react": "^18.2.0",  
    "react-dom": "^18.2.0",  
    "typescript": "^5.3.3",  
    "highcharts": "^11.2.0",  
    "highcharts-react-official": "^3.2.1",  
    "axios": "^1.6.2",  
    "zustand": "^4.4.7",  
    "@tanstack/react-query": "^5.12.2",  
    "tailwindcss": "^3.4.0"  
  },  
  "devDependencies": {  
    "@testing-library/react": "^14.1.2",  
    "@testing-library/jest-dom": "^6.1.5",  
    "@types/react": "^18.2.45",  
    "@types/react-dom": "^18.2.18",  
    "eslint": "^8.56.0",  
    "prettier": "^3.1.1"  
  }  
}

---

## **15\. FINAL CHECKLIST FOR CODING AGENT**

### **✅ Database:**

*  Supabase project created  
*  Schema SQL executed (18+ entity tables, 8 sector tables, 20+ join tables)  
*  Materialized views created  
*  Indices created  
*  Sample data populated

### **✅ Backend:**

*  FastAPI project structure created  
*  All API endpoints implemented (`/dashboard/generate`, `/dashboard/drill-down`, `/agent/ask`, `/ingest/*`)  
*  DashboardGenerator service with all 4 zones  
*  DimensionCalculator with 8 dimensions  
*  AutonomousAnalyticalAgent with 4 layers  
*  Database clients (Supabase, Qdrant, Redis)  
*  Tests written and passing  
*  Docker image builds successfully

### **✅ Frontend:**

*  React project with TypeScript  
*  All zone components (Zone1-4)  
*  DrillDownPanel component  
*  API service and hooks  
*  Zustand store  
*  Highcharts integration  
*  Responsive layout  
*  Tests written and passing  
*  Docker image builds successfully

### **✅ Integration:**

*  docker-compose.yml configured  
*  All services start successfully  
*  Frontend can reach backend API  
*  Backend can reach Supabase  
*  Backend can reach Vector DB  
*  Redis caching works  
*  End-to-end drill-down flow works

### **✅ Documentation:**

*  API documentation (Swagger/OpenAPI at `/docs`)  
*  README with setup instructions  
*  Environment variable documentation  
*  Architecture diagrams  
*  Deployment guide

---

## **🎯 HANDOFF TO CODING AGENT**

**Instructions for AI Coding Agent:**

* **Start with Phase 1 (Database Setup)**  
  * Use the SQL schema in Section 3.1  
  * Create all tables in exact order shown  
  * Create materialized views  
  * Verify with sample queries  
* **Proceed to Phase 2 (Backend)**  
  * Follow file structure in Section 7.1  
  * Copy code from Sections 4-6 exactly  
  * Install dependencies from requirements.txt  
  * Test each endpoint as you build  
* **Build Frontend (Phase 3\)**  
  * Use TypeScript strictly  
  * Copy components from Section 7 exactly  
  * Test each zone independently before integrating  
* **Docker Integration (Phase 4\)**  
  * Use docker-compose.yml from Section 9.1  
  * Build and test each service individually  
  * Verify networking between containers  
* **Testing (Phase 6\)**  
  * Run all tests before marking phase complete  
  * Fix any failing tests immediately  
  * Achieve \>80% code coverage

**Zero Questions Policy:**

* All code is provided in full  
* All configurations are complete  
* All dependencies are listed  
* All schemas are defined  
* All API contracts are specified

**If you encounter ANY ambiguity:**

* Re-read the relevant section  
* All answers are in this document  
* Do NOT improvise or assume

**Success Criteria:**

* All 15 checklist items are complete  
* `docker-compose up` starts all services  
* Dashboard loads at `http://localhost:3000`  
* Drill-down works when clicking any chart element  
* Tests pass with `pytest` and `npm test`

**GO\! 🚀**

