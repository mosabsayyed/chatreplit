"""
Embeddings Management API Routes
"""
from fastapi import APIRouter, HTTPException
from ...services.schema_embedder import get_schema_embedder
from ...services.entity_embedder import get_entity_embedder

router = APIRouter()

@router.post("/populate/schema")
async def populate_schema_embeddings():
    """Populate schema embeddings"""
    try:
        embedder = get_schema_embedder()
        count = embedder.populate_schema_embeddings()
        return {
            "success": True,
            "message": f"Populated {count} schema embeddings",
            "count": count
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/populate/entities")
async def populate_entity_embeddings():
    """Populate entity embeddings"""
    try:
        embedder = get_entity_embedder()
        count = embedder.populate_entity_embeddings()
        return {
            "success": True,
            "message": f"Populated {count} entity embeddings",
            "count": count
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/populate/all")
async def populate_all_embeddings():
    """Populate both schema and entity embeddings"""
    try:
        # Populate schema
        schema_embedder = get_schema_embedder()
        schema_count = schema_embedder.populate_schema_embeddings()
        
        # Populate entities
        entity_embedder = get_entity_embedder()
        entity_count = entity_embedder.populate_entity_embeddings()
        
        return {
            "success": True,
            "message": "Populated all embeddings",
            "schema_count": schema_count,
            "entity_count": entity_count,
            "total_count": schema_count + entity_count
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search/schema")
async def search_schema(query: str, top_k: int = 5):
    """Search schema embeddings"""
    try:
        embedder = get_schema_embedder()
        results = embedder.search_schema(query, top_k)
        return {
            "success": True,
            "query": query,
            "results": results
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search/entities")
async def search_entities(query: str, entity_type: str = None, top_k: int = 10):
    """Search entity embeddings"""
    try:
        embedder = get_entity_embedder()
        results = embedder.search_entities(query, entity_type, top_k)
        return {
            "success": True,
            "query": query,
            "results": results
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
