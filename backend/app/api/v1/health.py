from fastapi import APIRouter
from app.models.schemas import HealthCheckResponse
from app.db.postgres_client import postgres_client
from datetime import datetime

router = APIRouter()

@router.get("/check", response_model=HealthCheckResponse)
async def health_check():
    """Check system health"""
    try:
        result = await postgres_client.execute_query("SELECT 1 as test")
        
        if result and result[0].get('test') == 1:
            status = "healthy"
            health_score = 100
        else:
            status = "degraded"
            health_score = 50
        
        return HealthCheckResponse(
            status=status,
            health_score=health_score,
            warnings={},
            data_completeness={
                "database": "connected"
            },
            last_check=datetime.now()
        )
    except Exception as e:
        return HealthCheckResponse(
            status="critical",
            health_score=0,
            warnings={"database": str(e)},
            data_completeness={},
            last_check=datetime.now()
        )
