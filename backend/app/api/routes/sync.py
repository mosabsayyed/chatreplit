"""
Data Sync API Endpoints
Endpoints for syncing data between PostgreSQL and Neo4j
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from app.services.data_sync_service import data_sync_service
from app.db.neo4j_client import neo4j_client

router = APIRouter()

class SyncAllRequest(BaseModel):
    """Request model for syncing all data"""
    year: Optional[int] = None

class SyncIncrementalRequest(BaseModel):
    """Request model for incremental sync"""
    entity_type: str
    entity_id: str
    year: int

@router.post("/neo4j/all")
async def sync_all_to_neo4j(request: SyncAllRequest) -> Dict[str, Any]:
    """
    Sync all entities and relationships from PostgreSQL to Neo4j
    
    This endpoint performs a full batch sync of all entity tables and join tables
    for a specific year (defaults to current year).
    
    **Note:** Neo4j must be configured and available. Set NEO4J_URI, NEO4J_USERNAME, 
    and NEO4J_PASSWORD environment variables.
    """
    try:
        result = await data_sync_service.sync_all(year=request.year)
        
        if not result.get("success"):
            raise HTTPException(status_code=500, detail=result.get("error", "Sync failed"))
        
        return {
            "success": True,
            "message": f"Data synced successfully for year {result['year']}",
            "details": result
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")

@router.post("/neo4j/incremental")
async def sync_incremental(request: SyncIncrementalRequest) -> Dict[str, Any]:
    """
    Sync a single entity to Neo4j
    
    Use this endpoint to sync a specific entity and its relationships after updates.
    """
    try:
        result = await data_sync_service.sync_incremental(
            entity_type=request.entity_type,
            entity_id=request.entity_id,
            year=request.year
        )
        
        if not result.get("success"):
            raise HTTPException(status_code=400, detail=result.get("error", "Sync failed"))
        
        return result
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Incremental sync failed: {str(e)}")

@router.post("/neo4j/clear")
async def clear_neo4j() -> Dict[str, Any]:
    """
    Clear all data from Neo4j (USE WITH CAUTION)
    
    **Warning:** This will delete all nodes and relationships from Neo4j.
    Use this before a fresh sync or for testing purposes only.
    """
    try:
        result = await data_sync_service.clear_neo4j()
        
        if not result.get("success"):
            raise HTTPException(status_code=500, detail=result.get("error", "Clear failed"))
        
        return {
            "success": True,
            "message": "Neo4j database cleared successfully",
            "details": result
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Clear failed: {str(e)}")

@router.get("/neo4j/status")
async def neo4j_status() -> Dict[str, Any]:
    """
    Check Neo4j connection status and database statistics
    """
    try:
        health = neo4j_client.health_check()
        return health
    
    except Exception as e:
        return {
            "status": "error",
            "connected": False,
            "error": str(e)
        }
