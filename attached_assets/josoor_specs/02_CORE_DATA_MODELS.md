# CORE DATA MODELS

## META

**Dependencies:** 01_DATABASE_FOUNDATION.md  
**Provides:** Complete Pydantic schemas for all API requests/responses  
**Integration Points:** Used by all API endpoints, agent layers, frontend components

---

## OVERVIEW

This document contains all Pydantic data models used throughout the JOSOOR platform. These models provide:

1. **Request/Response validation** for all API endpoints
2. **Type safety** for Python backend code
3. **OpenAPI documentation** auto-generation
4. **Data serialization** between components
5. **Frontend TypeScript type generation** (via openapi-typescript-codegen)

### Design Principles

- **Explicit over implicit:** All fields explicitly typed
- **Validation at boundaries:** Pydantic validates all external inputs
- **Consistent naming:** snake_case for Python, camelCase for JSON/TypeScript
- **Reusable components:** Base models for common patterns
- **Backward compatibility:** Optional fields for future extensions

---

## ARCHITECTURE

### Model Hierarchy

```
BaseModel (Pydantic root)
├── Entity Models (database tables)
│   ├── UserModel
│   ├── ConversationModel
│   ├── MessageModel
│   ├── PersonaModel
│   └── ArtifactModel
│
├── Request Models (API inputs)
│   ├── Auth Requests (LoginRequest, RegisterRequest)
│   ├── Chat Requests (ChatMessageRequest, PersonaSwitchRequest)
│   ├── Canvas Requests (CreateArtifactRequest, ExportRequest)
│   ├── Dashboard Requests (GenerateDashboardRequest, DrillDownRequest)
│   └── Admin Requests (UpdateLLMConfigRequest, CreatePersonaRequest)
│
├── Response Models (API outputs)
│   ├── Auth Responses (TokenResponse, UserResponse)
│   ├── Chat Responses (ChatMessageResponse, ConversationResponse)
│   ├── Canvas Responses (ArtifactResponse, ExportResponse)
│   ├── Dashboard Responses (DashboardDataResponse, DrillDownResponse)
│   └── Agent Responses (AgentAnalysisResponse, ConfidenceResponse)
│
└── Internal Models (agent memory, analysis)
    ├── IntentModel (Layer 1 output)
    ├── RetrievalResultModel (Layer 2 output)
    ├── AnalysisInsightModel (Layer 3 output)
    └── VisualizationModel (Layer 4 output)
```

---

## IMPLEMENTATION

### Part 1: Base Models & Enums

```python
# app/models/schemas.py
from pydantic import BaseModel, Field, EmailStr, validator
from typing import Optional, List, Dict, Any, Union, Literal
from datetime import datetime
from enum import Enum

# =====================================================
# ENUMS
# =====================================================

class UserRole(str, Enum):
    USER = "user"
    ANALYST = "analyst"
    ADMIN = "admin"

class MessageRole(str, Enum):
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"
    TOOL = "tool"

class ArtifactType(str, Enum):
    CHART = "chart"
    REPORT = "report"
    DTDL_MODEL = "dtdl_model"
    SQL_QUERY = "sql_query"

class ChartType(str, Enum):
    SPIDER = "spider"
    BUBBLE = "bubble"
    BULLET = "bullet"
    COMBO = "combo"
    LINE = "line"
    BAR = "bar"
    PIE = "pie"

class ProjectStatus(str, Enum):
    PLANNING = "planning"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    ON_HOLD = "on_hold"
    CANCELLED = "cancelled"

class ConfidenceLevel(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

class PersonaName(str, Enum):
    TRANSFORMATION_ANALYST = "transformation_analyst"
    DIGITAL_TWIN_DESIGNER = "digital_twin_designer"

class LLMProvider(str, Enum):
    OPENAI = "openai"
    GEMINI = "gemini"
    GROK = "grok"
    DEEPSEEK = "deepseek"
    CUSTOM = "custom"

# =====================================================
# BASE MODELS
# =====================================================

class BaseResponse(BaseModel):
    """Base response model with common fields"""
    success: bool = True
    message: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

class PaginationParams(BaseModel):
    """Pagination parameters for list endpoints"""
    page: int = Field(1, ge=1, description="Page number (1-indexed)")
    page_size: int = Field(20, ge=1, le=100, description="Items per page")
    
class PaginatedResponse(BaseModel):
    """Paginated response wrapper"""
    total: int
    page: int
    page_size: int
    items: List[Any]

class ErrorDetail(BaseModel):
    """Error details for validation errors"""
    field: str
    message: str
    type: str

class ErrorResponse(BaseModel):
    """Standard error response"""
    success: bool = False
    error: str
    details: Optional[List[ErrorDetail]] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
```

### Part 2: User & Auth Models

```python
# =====================================================
# USER & AUTHENTICATION MODELS
# =====================================================

class UserBase(BaseModel):
    """Base user fields"""
    email: EmailStr
    full_name: Optional[str] = None
    role: UserRole = UserRole.USER

class UserCreate(UserBase):
    """User registration request"""
    password: str = Field(..., min_length=8, description="Password (min 8 characters)")
    
    @validator('password')
    def validate_password(cls, v):
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        return v

class UserLogin(BaseModel):
    """User login request"""
    email: EmailStr
    password: str

class UserResponse(UserBase):
    """User response (excludes password)"""
    id: int
    is_active: bool
    created_at: datetime
    
    class Config:
        orm_mode = True

class TokenResponse(BaseModel):
    """JWT token response"""
    access_token: str
    token_type: str = "bearer"
    expires_in: int = 86400  # 24 hours in seconds
    user: UserResponse

class TokenRefresh(BaseModel):
    """Token refresh request"""
    refresh_token: str
```

### Part 3: Persona Models

```python
# =====================================================
# PERSONA MODELS
# =====================================================

class PersonaBase(BaseModel):
    """Base persona fields"""
    name: PersonaName
    display_name: str
    description: Optional[str] = None
    is_active: bool = True

class PersonaCreate(PersonaBase):
    """Create persona request"""
    system_prompt: str = Field(..., min_length=50, description="System prompt template")

class PersonaUpdate(BaseModel):
    """Update persona request"""
    display_name: Optional[str] = None
    description: Optional[str] = None
    system_prompt: Optional[str] = None
    is_active: Optional[bool] = None

class ToolConfig(BaseModel):
    """Tool configuration for persona"""
    tool_name: str
    is_enabled: bool = True
    config: Dict[str, Any] = {}

class PersonaResponse(PersonaBase):
    """Persona response with tools"""
    id: int
    system_prompt: str
    tools: List[ToolConfig] = []
    created_at: datetime
    
    class Config:
        orm_mode = True

class PersonaSwitchRequest(BaseModel):
    """Switch persona in conversation"""
    conversation_id: int
    persona_id: int
```

### Part 4: Conversation & Message Models

```python
# =====================================================
# CONVERSATION & MESSAGE MODELS
# =====================================================

class ConversationCreate(BaseModel):
    """Create conversation request"""
    persona_id: int
    title: Optional[str] = None

class ConversationUpdate(BaseModel):
    """Update conversation request"""
    title: Optional[str] = None
    persona_id: Optional[int] = None

class ConversationResponse(BaseModel):
    """Conversation response"""
    id: int
    user_id: int
    persona_id: int
    title: Optional[str]
    created_at: datetime
    updated_at: datetime
    message_count: int = 0
    
    class Config:
        orm_mode = True

class MessageCreate(BaseModel):
    """Create message request (internal)"""
    conversation_id: int
    role: MessageRole
    content: str
    artifact_ids: List[int] = []
    metadata: Dict[str, Any] = {}

class MessageResponse(BaseModel):
    """Message response"""
    id: int
    conversation_id: int
    role: MessageRole
    content: str
    artifact_ids: List[int]
    metadata: Dict[str, Any]
    created_at: datetime
    
    class Config:
        orm_mode = True

class ChatMessageRequest(BaseModel):
    """User chat message request"""
    conversation_id: Optional[int] = None  # None = new conversation
    message: str = Field(..., min_length=1, max_length=10000)
    persona_id: Optional[int] = None  # Required if new conversation
    context: Optional[Dict[str, Any]] = None  # Additional context (e.g., selected dashboard zone)

class ChatMessageResponse(BaseResponse):
    """Chat message response from agent"""
    conversation_id: int
    message_id: int
    response: str
    artifacts: List['ArtifactResponse'] = []
    confidence: ConfidenceLevel
    confidence_details: Optional[str] = None
    metadata: Dict[str, Any] = {}
```

### Part 5: Artifact Models

```python
# =====================================================
# CANVAS ARTIFACT MODELS
# =====================================================

class ChartConfig(BaseModel):
    """Chart configuration"""
    chart_type: ChartType
    title: str
    data: Dict[str, Any]  # Highcharts-compatible config
    options: Dict[str, Any] = {}

class ReportConfig(BaseModel):
    """Report configuration"""
    title: str
    sections: List[Dict[str, Any]]  # Section configs
    template: str = "default"
    export_format: Literal["pdf", "docx", "html"] = "pdf"

class DTDLModelConfig(BaseModel):
    """DTDL model configuration"""
    model_name: str
    entities: List[Dict[str, Any]]
    relationships: List[Dict[str, Any]]
    dtdl_version: str = "v2"

class SQLQueryConfig(BaseModel):
    """SQL query configuration"""
    query: str
    description: Optional[str] = None
    parameters: Dict[str, Any] = {}

class CreateArtifactRequest(BaseModel):
    """Create artifact request"""
    conversation_id: int
    artifact_type: ArtifactType
    title: str
    content: Union[ChartConfig, ReportConfig, DTDLModelConfig, SQLQueryConfig]

class UpdateArtifactRequest(BaseModel):
    """Update artifact request"""
    title: Optional[str] = None
    content: Optional[Union[ChartConfig, ReportConfig, DTDLModelConfig, SQLQueryConfig]] = None

class ArtifactResponse(BaseModel):
    """Artifact response"""
    id: int
    conversation_id: int
    user_id: int
    artifact_type: ArtifactType
    title: str
    content: Dict[str, Any]
    rendered_output: Optional[str] = None  # Base64 encoded or URL
    version: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True

class ExportArtifactRequest(BaseModel):
    """Export artifact request"""
    artifact_id: int
    format: Literal["png", "pdf", "json", "excel"] = "png"
    options: Dict[str, Any] = {}

class ExportArtifactResponse(BaseResponse):
    """Export artifact response"""
    download_url: str
    format: str
    size_bytes: int
    expires_at: datetime
```

### Part 6: Dashboard Models

```python
# =====================================================
# DASHBOARD MODELS
# =====================================================

class DimensionScore(BaseModel):
    """Single dimension score"""
    dimension_name: str
    score: float = Field(..., ge=0, le=100)
    target: float = Field(..., ge=0, le=100)
    status: Literal["on_track", "at_risk", "off_track"]
    trend: Optional[Literal["improving", "stable", "declining"]] = None

class Zone1Data(BaseModel):
    """Zone 1: Transformation Health - Spider Chart"""
    dimensions: List[DimensionScore]
    overall_health: float = Field(..., ge=0, le=100)
    
class Zone2Data(BaseModel):
    """Zone 2: Strategic Insights - Bubble Chart"""
    bubbles: List[Dict[str, Any]]  # {name, x, y, z, category}
    axes: Dict[str, str]  # {x: "label", y: "label", z: "label"}

class Zone3Data(BaseModel):
    """Zone 3: Internal Outputs - Bullet Charts"""
    metrics: List[Dict[str, Any]]  # {name, value, target, ranges}

class Zone4Data(BaseModel):
    """Zone 4: Sector Outcomes - Combo Chart"""
    series: List[Dict[str, Any]]  # {name, type, data}
    categories: List[str]

class GenerateDashboardRequest(BaseModel):
    """Generate dashboard request"""
    year: int = Field(..., ge=2020, le=2100)
    quarter: Optional[Literal["Q1", "Q2", "Q3", "Q4"]] = None
    refresh_cache: bool = False

class DashboardDataResponse(BaseResponse):
    """Complete dashboard data response"""
    year: int
    quarter: str
    zone1: Zone1Data
    zone2: Zone2Data
    zone3: Zone3Data
    zone4: Zone4Data
    generated_at: datetime
    cache_status: Literal["hit", "miss", "refreshed"]

class DrillDownRequest(BaseModel):
    """Drill-down request"""
    zone: Literal["zone1", "zone2", "zone3", "zone4"]
    item_id: str  # Dimension name, objective ID, etc.
    year: int
    quarter: Optional[str] = None
    depth: int = Field(1, ge=1, le=3, description="Drill-down depth level")

class DrillDownResponse(BaseResponse):
    """Drill-down response"""
    zone: str
    item_id: str
    item_name: str
    data: Dict[str, Any]
    related_entities: List[Dict[str, Any]]
    visualizations: List[ArtifactResponse]
    narrative: str
    confidence: ConfidenceLevel
```

### Part 7: Agent Internal Models

```python
# =====================================================
# AGENT INTERNAL MODELS (Layer Outputs)
# =====================================================

class IntentUnderstanding(BaseModel):
    """Layer 1 output: Parsed user intent"""
    entities: List[str]  # Table names (ent_projects, sec_objectives)
    temporal_scope: Dict[str, Any]  # {year: 2024, quarter: "Q2"}
    operational_chain: Optional[str] = None  # SectorOps, Strategy_to_Tactics
    question_type: Literal["status_check", "comparison", "trend_analysis", "drill_down", "correlation", "prediction"]
    extracted_filters: Dict[str, Any] = {}
    confidence: ConfidenceLevel

class SQLQuery(BaseModel):
    """Generated SQL query"""
    query: str
    parameters: Dict[str, Any] = {}
    tables_used: List[str]
    estimated_rows: Optional[int] = None

class VectorSearchResult(BaseModel):
    """Vector search result"""
    doc_id: str
    score: float
    content: str
    metadata: Dict[str, Any]

class RetrievalResult(BaseModel):
    """Layer 2 output: Retrieved data"""
    sql_results: List[Dict[str, Any]]
    vector_results: List[VectorSearchResult]
    execution_time_ms: float
    data_quality_issues: List[str] = []

class AnalysisInsight(BaseModel):
    """Layer 3 output: Analytical insights"""
    insight_type: Literal["correlation", "trend", "anomaly", "comparison", "risk_assessment"]
    description: str
    supporting_data: Dict[str, Any]
    confidence: ConfidenceLevel
    statistical_significance: Optional[float] = None

class VisualizationSpec(BaseModel):
    """Layer 4 output: Visualization specification"""
    viz_type: ChartType
    title: str
    chart_config: Dict[str, Any]
    narrative: str
    key_takeaways: List[str]

class AgentAnalysisResponse(BaseModel):
    """Complete agent analysis response"""
    intent: IntentUnderstanding
    retrieval: RetrievalResult
    insights: List[AnalysisInsight]
    visualizations: List[VisualizationSpec]
    narrative: str
    confidence: ConfidenceLevel
    confidence_explanation: str
    execution_time_ms: float
```

### Part 8: Admin Configuration Models

```python
# =====================================================
# ADMIN CONFIGURATION MODELS
# =====================================================

class LLMConfig(BaseModel):
    """LLM configuration"""
    provider: LLMProvider
    model: str
    temperature: float = Field(0.7, ge=0.0, le=1.0)
    max_tokens: int = Field(4096, ge=256, le=32000)
    top_p: float = Field(0.9, ge=0.0, le=1.0)
    
class UpdateLLMConfigRequest(BaseModel):
    """Update LLM config request"""
    provider: Optional[LLMProvider] = None
    model: Optional[str] = None
    temperature: Optional[float] = Field(None, ge=0.0, le=1.0)
    max_tokens: Optional[int] = Field(None, ge=256, le=32000)
    top_p: Optional[float] = Field(None, ge=0.0, le=1.0)

class LLMConfigResponse(BaseResponse):
    """LLM config response"""
    config: LLMConfig

class ToolConfigUpdate(BaseModel):
    """Update tool config request"""
    persona_id: int
    tool_name: str
    is_enabled: bool
    config: Optional[Dict[str, Any]] = None

class KnowledgeFileUpload(BaseModel):
    """Knowledge file upload request"""
    persona_id: Optional[int] = None  # None = global knowledge
    filename: str
    file_type: Literal["json", "pdf", "sql", "md", "txt"]
    vector_index: bool = True  # Whether to embed in vector DB

class KnowledgeFileResponse(BaseModel):
    """Knowledge file response"""
    id: int
    persona_id: Optional[int]
    filename: str
    file_type: str
    storage_path: str
    vector_indexed: bool
    created_at: datetime
    
    class Config:
        orm_mode = True

class SystemHealthResponse(BaseResponse):
    """System health check response"""
    database_status: Literal["healthy", "degraded", "down"]
    vector_db_status: Literal["healthy", "degraded", "down"]
    redis_status: Literal["healthy", "degraded", "down"]
    llm_provider_status: Literal["healthy", "degraded", "down"]
    active_conversations: int
    cache_hit_rate: float
    avg_response_time_ms: float
```

### Part 9: Data Ingestion Models

```python
# =====================================================
# DATA INGESTION MODELS
# =====================================================

class StructuredDataIngestion(BaseModel):
    """Structured data ingestion request"""
    table_name: str
    records: List[Dict[str, Any]]
    year: int
    quarter: Optional[str] = None
    validate_worldview: bool = True
    upsert: bool = True  # Update if exists, insert if not

class UnstructuredDocumentIngestion(BaseModel):
    """Unstructured document ingestion request"""
    doc_type: Literal["strategy", "assessment", "study", "meeting_minutes", "email", "text_update"]
    content: str
    metadata: Dict[str, Any]
    project_id: Optional[int] = None
    year: int
    quarter: Optional[str] = None
    embed_in_vector_db: bool = True

class IngestionResponse(BaseResponse):
    """Data ingestion response"""
    records_processed: int
    records_inserted: int
    records_updated: int
    records_failed: int
    validation_errors: List[str] = []
    processing_time_ms: float

class DataQualityIssue(BaseModel):
    """Data quality issue"""
    severity: Literal["critical", "warning", "info"]
    issue_type: str
    description: str
    affected_records: List[Dict[str, Any]]
    remediation: Optional[str] = None

class DataQualityReport(BaseModel):
    """Data quality report"""
    table_name: str
    year: int
    total_records: int
    issues: List[DataQualityIssue]
    overall_score: float = Field(..., ge=0, le=100)
    generated_at: datetime
```

---

## CONFIGURATION

### Pydantic Settings

```python
# app/core/config.py
from pydantic import BaseSettings, Field

class Settings(BaseSettings):
    """Application settings"""
    
    # App
    APP_NAME: str = "JOSOOR Transformation Platform"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # Database
    DATABASE_URL: str = Field(..., env="DATABASE_URL")
    
    # Auth
    JWT_SECRET: str = Field(..., env="JWT_SECRET")
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRATION_MINUTES: int = 1440
    
    # LLM (defaults, can be overridden via admin_config table)
    DEFAULT_LLM_PROVIDER: str = "openai"
    DEFAULT_LLM_MODEL: str = "gpt-4-turbo"
    DEFAULT_TEMPERATURE: float = 0.7
    
    # Cache
    REDIS_URL: str = Field(..., env="REDIS_URL")
    CACHE_TTL_DASHBOARD: int = 900  # 15 minutes
    CACHE_TTL_QUERY: int = 3600  # 1 hour
    
    # Vector DB
    QDRANT_URL: str = Field(..., env="QDRANT_URL")
    QDRANT_COLLECTION: str = "transformation_documents"
    
    # Storage
    ARTIFACTS_STORAGE_PATH: str = "/var/app/artifacts"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
```

---

## TESTING

### Model Validation Tests

```python
# tests/test_models.py
import pytest
from app.models.schemas import *

def test_user_create_validation():
    """Test user creation validation"""
    # Valid user
    user = UserCreate(
        email="test@example.com",
        password="Password123",
        full_name="Test User"
    )
    assert user.email == "test@example.com"
    
    # Invalid password (no uppercase)
    with pytest.raises(ValueError):
        UserCreate(
            email="test@example.com",
            password="password123"
        )
    
    # Invalid password (no digit)
    with pytest.raises(ValueError):
        UserCreate(
            email="test@example.com",
            password="PasswordABC"
        )

def test_chat_message_request():
    """Test chat message request"""
    req = ChatMessageRequest(
        conversation_id=1,
        message="Which projects are behind schedule?"
    )
    assert req.conversation_id == 1
    assert req.persona_id is None
    
def test_dashboard_request():
    """Test dashboard generation request"""
    req = GenerateDashboardRequest(year=2024, quarter="Q2")
    assert req.year == 2024
    assert req.quarter == "Q2"
    
def test_artifact_creation():
    """Test artifact creation"""
    chart_config = ChartConfig(
        chart_type=ChartType.SPIDER,
        title="Transformation Health",
        data={"categories": [], "series": []}
    )
    req = CreateArtifactRequest(
        conversation_id=1,
        artifact_type=ArtifactType.CHART,
        title="Health Dashboard",
        content=chart_config
    )
    assert req.artifact_type == ArtifactType.CHART
```

---

## EXAMPLES

### Usage in FastAPI Endpoints

```python
# app/api/endpoints/chat.py
from fastapi import APIRouter, Depends
from app.models.schemas import ChatMessageRequest, ChatMessageResponse
from app.services.autonomous_agent import AutonomousAnalyticalAgent

router = APIRouter()

@router.post("/chat/message", response_model=ChatMessageResponse)
async def send_message(
    request: ChatMessageRequest,
    agent: AutonomousAnalyticalAgent = Depends(get_agent)
):
    """Send message to AI agent"""
    response = await agent.process_message(request)
    return response
```

### Frontend TypeScript Type Generation

```bash
# Generate TypeScript types from Pydantic models
npx openapi-typescript-codegen --input http://localhost:8000/openapi.json --output src/types --client axios
```

Generated TypeScript:
```typescript
// src/types/ChatMessageRequest.ts
export interface ChatMessageRequest {
    conversation_id?: number | null;
    message: string;
    persona_id?: number | null;
    context?: Record<string, any> | null;
}

// src/types/ChatMessageResponse.ts
export interface ChatMessageResponse {
    success: boolean;
    message?: string | null;
    timestamp: string;
    conversation_id: number;
    message_id: number;
    response: string;
    artifacts: ArtifactResponse[];
    confidence: ConfidenceLevel;
    confidence_details?: string | null;
    metadata: Record<string, any>;
}
```

---

## CHECKLIST FOR CODING AGENT

### Model Implementation

- [ ] Create `app/models/schemas.py` with all models
- [ ] Create `app/core/config.py` with settings
- [ ] Import models in FastAPI app: `from app.models.schemas import *`
- [ ] Test model validation with pytest
- [ ] Generate OpenAPI spec: `uvicorn app.main:app --host 0.0.0.0 --port 8000`
- [ ] Access OpenAPI JSON: `http://localhost:8000/openapi.json`
- [ ] Generate TypeScript types for frontend
- [ ] Verify type safety in IDE (VSCode, PyCharm)

### Integration with Database

- [ ] Add `orm_mode = True` to response models that map to database tables
- [ ] Use SQLAlchemy models for database operations
- [ ] Use Pydantic models for API layer
- [ ] Convert between SQLAlchemy ↔ Pydantic using `from_orm()`

### Next Steps

- [ ] Proceed to **03_AUTH_AND_USERS.md** for authentication implementation
- [ ] Proceed to **04_AI_PERSONAS_AND_MEMORY.md** for persona system
