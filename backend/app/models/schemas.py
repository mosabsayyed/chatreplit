from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

# ========== DASHBOARD SCHEMAS ==========

class DimensionScore(BaseModel):
    name: str
    score: float = Field(..., ge=0, le=100)
    target: float
    description: str
    entity_tables: List[str]
    trend: str  # "improving", "declining", "stable"

class Zone1Data(BaseModel):
    """Transformation Health - Spider Chart"""
    dimensions: List[DimensionScore]
    overall_health: float

class BubblePoint(BaseModel):
    id: int
    name: str
    x: float  # Progress %
    y: float  # Impact score
    z: float  # Budget size
    objective_id: int
    project_id: int

class Zone2Data(BaseModel):
    """Strategic Insights - Bubble Chart"""
    bubbles: List[BubblePoint]

class MetricBar(BaseModel):
    entity_type: str  # "capabilities", "processes", "it_systems"
    current_value: float
    target_value: float
    performance_percentage: float

class Zone3Data(BaseModel):
    """Internal Outputs - Bullet Charts"""
    metrics: List[MetricBar]

class OutcomeMetric(BaseModel):
    sector: str  # "citizens", "businesses", "gov_entities"
    kpi_name: str
    value: float
    target: float
    trend: List[float]  # Time series

class Zone4Data(BaseModel):
    """Sector Outcomes - Combo Chart"""
    outcomes: List[OutcomeMetric]

class DashboardResponse(BaseModel):
    year: int
    quarter: Optional[str]
    zone1: Zone1Data
    zone2: Zone2Data
    zone3: Zone3Data
    zone4: Zone4Data
    generated_at: datetime
    cache_hit: bool

# ========== DRILL-DOWN SCHEMAS ==========

class DrillDownContext(BaseModel):
    dimension: Optional[str]
    entity_table: Optional[str]
    entity_id: Optional[int]
    year: int
    quarter: Optional[str]
    level: Optional[str]

class DrillDownRequest(BaseModel):
    zone: str  # "transformation_health", "strategic_insights", etc.
    target: str
    context: DrillDownContext

class Visualization(BaseModel):
    type: str
    title: str
    image_base64: str
    description: str

class ConfidenceInfo(BaseModel):
    level: str  # "high", "medium", "low"
    score: float = Field(..., ge=0, le=1)
    warnings: List[str]

class RelatedEntity(BaseModel):
    entity_type: str
    entity_id: int
    entity_name: str
    relationship: str

class DrillDownResponse(BaseModel):
    narrative: str
    visualizations: List[Visualization]
    confidence: ConfidenceInfo
    related_entities: List[RelatedEntity]
    recommended_actions: List[str]
    metadata: Dict[str, Any]

# ========== AGENT SCHEMAS ==========

class AgentRequest(BaseModel):
    question: str
    context: Optional[Dict[str, Any]] = None

class AgentResponse(BaseModel):
    narrative: str
    visualizations: List[Visualization] = []
    confidence: ConfidenceInfo
    metadata: Dict[str, Any] = {}

# ========== INGESTION SCHEMAS ==========

class StructuredDataRequest(BaseModel):
    table: str
    records: List[Dict[str, Any]]
    operation: str  # "insert", "update", "upsert"

class DocumentMetadata(BaseModel):
    project_id: Optional[int] = None
    year: int
    quarter: Optional[str] = None
    author: str
    date: str
    related_entities: List[str]

class UnstructuredDocument(BaseModel):
    doc_type: str
    content: str
    metadata: DocumentMetadata

class UnstructuredDataRequest(BaseModel):
    documents: List[UnstructuredDocument]

class IngestionResponse(BaseModel):
    status: str
    message: str
    validated_count: int
    inserted_count: int
    errors: Optional[List[str]] = None

# ========== HEALTH CHECK SCHEMAS ==========

class HealthCheckResponse(BaseModel):
    status: str  # "healthy", "degraded", "critical"
    health_score: int
    warnings: Dict[str, int]
    data_completeness: Dict[str, Any]
    last_check: datetime
