from fastapi import APIRouter
from app.models.schemas import HealthCheckResponse
from app.db.supabase_client import supabase_client
from datetime import datetime

router = APIRouter()

@router.get("/check", response_model=HealthCheckResponse)
async def health_check():
    """Check system health using Supabase REST API"""
    try:
        # Test Supabase connection by querying users table
        await supabase_client.connect()
        result = await supabase_client.table_select("users", "count")
        
        if result is not None:
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
                "database": "connected via Supabase REST API"
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
