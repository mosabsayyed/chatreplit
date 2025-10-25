# backend/app/api/routes/chat.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.orm import Session
from app.db.sqlalchemy_session import get_db
from app.services.conversation_manager import ConversationManager

router = APIRouter()


class ChatRequest(BaseModel):
    query: str
    conversation_id: Optional[int] = None
    persona: Optional[str] = "transformation_analyst"


class ChatResponse(BaseModel):
    conversation_id: int
    message: str
    visualization: Optional[dict] = None
    insights: List[dict] = []


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
    
    conversation_manager = ConversationManager(db)
    
    # For MVP: Use demo user (id=1)
    # TODO: Replace with JWT authentication
    user_id = 1
    
    try:
        # Get or create conversation
        if request.conversation_id:
            # Verify conversation exists and belongs to user
            conversation = conversation_manager.get_conversation(
                conversation_id=request.conversation_id,
                user_id=user_id
            )
            if not conversation:
                raise HTTPException(status_code=404, detail="Conversation not found")
            conversation_id = request.conversation_id
        else:
            # Create new conversation
            conversation = conversation_manager.create_conversation(
                user_id=user_id,
                persona_name=request.persona,
                title=request.query[:50] + ("..." if len(request.query) > 50 else "")
            )
            conversation_id = conversation.id
        
        # Store user message
        conversation_manager.add_message(
            conversation_id=conversation_id,
            role="user",
            content=request.query,
            metadata={"persona": request.persona}
        )
        
        # Build conversation context for agent
        conversation_context = conversation_manager.build_conversation_context(
            conversation_id=conversation_id,
            max_messages=10
        )
        
        # TODO: Process through 4-layer autonomous agent
        # For now, return mock response to test conversation flow
        response_text = f"[AGENT RESPONSE] Analyzing: {request.query}\n\nContext:\n{conversation_context}"
        
        # Store agent response
        conversation_manager.add_message(
            conversation_id=conversation_id,
            role="assistant",
            content=response_text,
            metadata={
                "visualization": None,
                "insights": [],
                "entities": []
            }
        )
        
        return ChatResponse(
            conversation_id=conversation_id,
            message=response_text,
            visualization=None,
            insights=[]
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
