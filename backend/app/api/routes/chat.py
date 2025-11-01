# backend/app/api/routes/chat.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from app.db.supabase_client import supabase_client
from app.services.supabase_conversation_manager import SupabaseConversationManager
from app.utils.debug_logger import init_debug_logger

router = APIRouter()


async def get_conversation_manager() -> SupabaseConversationManager:
    """Dependency to get Supabase conversation manager"""
    await supabase_client.connect()
    return SupabaseConversationManager(supabase_client)


def _generate_artifact_from_steps(query: str, steps: List[dict]) -> Optional[dict]:
    """
    Generate Canvas artifact from orchestrator steps
    
    Analyzes SQL results and creates appropriate artifact type:
    - CHART: For numeric data that can be visualized
    - TABLE: For tabular data listings
    """
    import re
    
    # Find SQL execution steps with data
    sql_results = []
    for step in steps:
        if step.get("result", {}).get("data"):
            sql_results.append(step["result"])
    
    if not sql_results:
        return None
    
    # Use the last SQL result for artifact generation
    last_result = sql_results[-1]
    data = last_result.get("data", [])
    
    if not data or len(data) == 0:
        return None
    
    # Detect if this should be a chart
    first_row = data[0]
    columns = list(first_row.keys())
    
    # Check for numeric columns
    numeric_cols = []
    text_col = None
    for col in columns:
        if col.lower() in ['id', 'year']:
            continue
        
        try:
            # Check if values are numeric
            values = [row[col] for row in data if row.get(col) is not None]
            if values and all(isinstance(v, (int, float)) for v in values):
                numeric_cols.append(col)
            elif not text_col:
                text_col = col
        except:
            continue
    
    # If we have numeric data, create a chart
    if numeric_cols and text_col and len(data) <= 20:
        # Determine chart type based on query
        chart_type = 'column'
        if 'maturity' in query.lower() or 'capability' in query.lower():
            chart_type = 'radar'
        elif 'trend' in query.lower() or 'over time' in query.lower():
            chart_type = 'line'
        
        # Build chart data
        categories = [str(row[text_col]) for row in data]
        series = []
        
        for col in numeric_cols[:3]:  # Max 3 series for readability
            series.append({
                "name": col.replace('_', ' ').title(),
                "data": [float(row[col]) if row.get(col) is not None else 0 for row in data],
                "pointPlacement": "on" if chart_type == 'radar' else None
            })
        
        return {
            "artifact_type": "CHART",
            "title": f"{query[:50]}..." if len(query) > 50 else query,
            "content": {
                "type": chart_type,
                "chart_title": query[:80],
                "categories": categories,
                "series": series,
                "x_axis_label": text_col.replace('_', ' ').title(),
                "y_axis_label": "Value",
                "max_value": 5 if chart_type == 'radar' else None
            },
            "description": f"Chart showing {len(data)} results"
        }
    
    # Otherwise, create a table artifact
    return {
        "artifact_type": "TABLE",
        "title": f"{query[:50]}..." if len(query) > 50 else query,
        "content": {
            "columns": columns,
            "data": data[:100]  # Limit to 100 rows for performance
        },
        "description": f"Table showing {len(data)} results"
    }


class ChatRequest(BaseModel):
    query: str
    conversation_id: Optional[int] = None
    persona: Optional[str] = "transformation_analyst"


class Artifact(BaseModel):
    artifact_type: str  # CHART, TABLE, REPORT, DOCUMENT
    title: str
    content: dict
    description: Optional[str] = None


class ChatResponse(BaseModel):
    conversation_id: int
    message: str
    visualization: Optional[dict] = None
    insights: List[str] = []  # Changed from List[dict] to List[str]
    artifact: Optional[Artifact] = None  # Canvas artifact


class ConversationSummary(BaseModel):
    id: int
    title: str
    message_count: int
    created_at: str
    updated_at: str


class ConversationListResponse(BaseModel):
    conversations: List[ConversationSummary]


class MessageResponse(BaseModel):
    id: int
    role: str
    content: str
    created_at: str
    metadata: Optional[dict] = None


class ConversationDetailResponse(BaseModel):
    conversation: dict
    messages: List[MessageResponse]


@router.post("/message", response_model=ChatResponse)
async def send_message(
    request: ChatRequest,
    conversation_manager: SupabaseConversationManager = Depends(get_conversation_manager)
):
    """
    Send message and get AI response with conversation memory
    
    This endpoint:
    1. Creates new conversation OR continues existing one
    2. Stores user message
    3. Processes query through 4-layer agent WITH CONTEXT
    4. Stores agent response
    5. Returns response with conversation_id
    """
    
    from starlette.concurrency import run_in_threadpool
    
    # For MVP: Use demo user (id=1)
    # TODO: Replace with JWT authentication
    user_id = 1
    
    try:
        # CRITICAL FIX: Run synchronous SQLAlchemy in threadpool to avoid blocking event loop
        
        # Get or create conversation
        if request.conversation_id:
            # Verify conversation exists and belongs to user
            conversation = await run_in_threadpool(
                conversation_manager.get_conversation,
                request.conversation_id,
                user_id
            )
            if not conversation:
                raise HTTPException(status_code=404, detail="Conversation not found")
            conversation_id = request.conversation_id
        else:
            # Create new conversation
            conversation = await run_in_threadpool(
                conversation_manager.create_conversation,
                user_id,
                request.persona,
                request.query[:50] + ("..." if len(request.query) > 50 else "")
            )
            conversation_id = conversation.id
        
        # Initialize debug logger AFTER we have the real conversation_id
        debug_logger = init_debug_logger(str(conversation_id))
        
        # Store user message
        await run_in_threadpool(
            conversation_manager.add_message,
            conversation_id,
            "user",
            request.query,
            {"persona": request.persona}
        )
        
        # Build conversation context for agent (THE MAGIC!)
        conversation_context = await run_in_threadpool(
            conversation_manager.build_conversation_context,
            conversation_id,
            10
        )
        
        # OPTIMIZATION: Initialize agent with conversation_manager for composite key resolution
        from app.services.autonomous_agent import AutonomousAnalyticalAgent
        agent = AutonomousAnalyticalAgent(conversation_manager)
        
        # Process through 4-layer autonomous agent WITH CONTEXT
        agent_response = await agent.process_query(
            question=request.query,
            context={
                "conversation_history": conversation_context,
                "conversation_id": conversation_id
            }
        )
        
        # CRITICAL FIX: Guard against None/empty visualizations
        visualizations_data = []
        if agent_response.visualizations:
            visualizations_data = [v.model_dump() for v in agent_response.visualizations]
        
        # Store agent response with rich metadata
        await run_in_threadpool(
            conversation_manager.add_message,
            conversation_id,
            "assistant",
            agent_response.narrative,
            {
                "visualizations": visualizations_data,
                "insights": agent_response.metadata.get("key_insights", []),
                "chain_selected": agent_response.metadata.get("chain_selected"),
                "suggestions": agent_response.metadata.get("suggestions", []),
                "confidence": {
                    "level": agent_response.confidence.level,
                    "score": agent_response.confidence.score
                }
            }
        )
        
        return ChatResponse(
            conversation_id=conversation_id,
            message=agent_response.narrative,
            visualization={"visualizations": visualizations_data} if visualizations_data else None,
            insights=agent_response.metadata.get("key_insights", [])
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/message/v2", response_model=ChatResponse)
async def send_message_v2(
    request: ChatRequest,
    conversation_manager: SupabaseConversationManager = Depends(get_conversation_manager)
):
    """
    V2 Chat Endpoint - Single-layer LLM with pgvector semantic search
    
    This endpoint:
    1. Uses pgvector-augmented single LLM orchestrator (1 call vs 4)
    2. Maintains conversation history for multi-turn interactions
    3. Function calling for semantic_search() and execute_sql() tools
    4. 75% cost reduction compared to 4-layer agent
    """
    from starlette.concurrency import run_in_threadpool
    from app.services.orchestrator_v2 import OrchestratorV2
    
    user_id = 1  # Demo user (TODO: JWT auth)
    
    try:
        # Get or create conversation
        if request.conversation_id:
            conversation = await conversation_manager.get_conversation(
                request.conversation_id,
                user_id
            )
            if not conversation:
                raise HTTPException(status_code=404, detail="Conversation not found")
            conversation_id = request.conversation_id
        else:
            conversation = await conversation_manager.create_conversation(
                user_id,
                request.persona,
                request.query[:50] + ("..." if len(request.query) > 50 else "")
            )
            conversation_id = conversation['id']
        
        # Initialize debug logger
        debug_logger = init_debug_logger(str(conversation_id))
        
        # Store user message
        await conversation_manager.add_message(
            conversation_id,
            "user",
            request.query
        )
        
        # Build conversation history in OpenAI format
        messages = await conversation_manager.get_messages(
            conversation_id,
            limit=20  # Last 20 messages for context
        )
        
        # Convert to OpenAI format (excluding current user query)
        conversation_history = []
        for msg in messages[:-1]:  # Exclude the message we just added
            conversation_history.append({
                "role": msg['role'],
                "content": msg['content']
            })
        
        # Initialize orchestrator and process query
        orchestrator = OrchestratorV2()
        
        # Process query with conversation context
        result = await run_in_threadpool(
            orchestrator.process_query,
            request.query,
            conversation_history,
            max_iterations=5
        )
        
        # Log debug information
        debug_logger.log_layer(
            "orchestrator_v2",
            {
                "success": result.get("success", False),
                "iterations": result.get("total_iterations", 0),
                "steps_taken": result.get("steps_taken", []),
                "debug_log": result.get("debug_log", [])
            }
        )
        
        # Extract answer
        answer = result.get("answer", "I apologize, but I encountered an error processing your query.")
        
        # Generate artifact from results
        artifact_dict = None
        steps_taken = result.get("steps_taken", [])
        if steps_taken:
            artifact_dict = _generate_artifact_from_steps(request.query, steps_taken)
        
        artifact = Artifact(**artifact_dict) if artifact_dict else None
        
        # Store assistant response
        await conversation_manager.add_message(
            conversation_id,
            "assistant",
            answer,
            {
                "orchestrator_version": "v2",
                "steps_taken": result.get("steps_taken", []),
                "total_iterations": result.get("total_iterations", 0),
                "success": result.get("success", False),
                "artifact": artifact.model_dump() if artifact else None
            }
        )
        
        return ChatResponse(
            conversation_id=conversation_id,
            message=answer,
            visualization=None,
            insights=[],
            artifact=artifact
        )
    
    except Exception as e:
        debug_logger.log_error("orchestrator_v2_error", str(e))
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/conversations", response_model=ConversationListResponse)
async def list_conversations(
    conversation_manager: SupabaseConversationManager = Depends(get_conversation_manager)
):
    """List all conversations for current user"""
    user_id = 1  # Demo user
    
    try:
        conversations = conversation_manager.list_conversations(
            user_id=user_id,
            limit=50
        )
        
        summaries = []
        for conv in conversations:
            summary = conversation_manager.get_conversation_summary(conv.id)
            if summary:
                summaries.append(ConversationSummary(**summary))
        
        return ConversationListResponse(conversations=summaries)
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/conversations/{conversation_id}", response_model=ConversationDetailResponse)
async def get_conversation_detail(
    conversation_id: int,
    conversation_manager: SupabaseConversationManager = Depends(get_conversation_manager)
):
    """Get conversation with all messages"""
    user_id = 1  # Demo user
    
    try:
        conversation = conversation_manager.get_conversation(
            conversation_id=conversation_id,
            user_id=user_id
        )
        
        if not conversation:
            raise HTTPException(status_code=404, detail="Conversation not found")
        
        messages = conversation_manager.get_messages(conversation_id)
        
        return ConversationDetailResponse(
            conversation={
                "id": conversation.id,
                "title": conversation.title,
                "created_at": conversation.created_at.isoformat()
            },
            messages=[MessageResponse(**msg.to_dict()) for msg in messages]
        )
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: int,
    conversation_manager: SupabaseConversationManager = Depends(get_conversation_manager)
):
    """Delete a conversation"""
    user_id = 1  # Demo user
    
    try:
        deleted = conversation_manager.delete_conversation(
            conversation_id=conversation_id,
            user_id=user_id
        )
        
        if not deleted:
            raise HTTPException(status_code=404, detail="Conversation not found")
        
        return {"message": "Conversation deleted successfully"}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/debug_logs/{conversation_id}")
async def get_debug_logs(conversation_id: str):
    """Get debug logs for a conversation - RAW layer outputs"""
    from app.utils.debug_logger import get_debug_logs
    
    try:
        logs = get_debug_logs(conversation_id)
        return {"conversation_id": conversation_id, "logs": logs}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to load debug logs: {str(e)}")
