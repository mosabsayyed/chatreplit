# backend/app/api/routes/chat.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.orm import Session
from app.db.sqlalchemy_session import get_db
from app.services.conversation_manager import ConversationManager
from app.utils.debug_logger import init_debug_logger

router = APIRouter()


class ChatRequest(BaseModel):
    query: str
    conversation_id: Optional[int] = None
    persona: Optional[str] = "transformation_analyst"


class ChatResponse(BaseModel):
    conversation_id: int
    message: str
    visualization: Optional[dict] = None
    insights: List[str] = []  # Changed from List[dict] to List[str]


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
    db: Session = Depends(get_db)
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
    
    conversation_manager = ConversationManager(db)
    
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


@router.get("/conversations", response_model=ConversationListResponse)
async def list_conversations(
    db: Session = Depends(get_db)
):
    """List all conversations for current user"""
    
    conversation_manager = ConversationManager(db)
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
    db: Session = Depends(get_db)
):
    """Get conversation with all messages"""
    
    conversation_manager = ConversationManager(db)
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
    db: Session = Depends(get_db)
):
    """Delete a conversation"""
    
    conversation_manager = ConversationManager(db)
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
