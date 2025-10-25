# CHAT INTERFACE BACKEND (REFERENCE + ENHANCEMENTS)

## META

**Dependencies:** 02_CORE_DATA_MODELS.md, 03_AUTH_AND_USERS.md, 04_AI_PERSONAS_AND_MEMORY.md, 05_LLM_PROVIDER_ABSTRACTION.md  
**Provides:** Chat API endpoints with conversation memory  
**Integration Points:** Agent orchestrator (10), Frontend chat UI (12), Database conversations/messages  
**Status:** ⚠️ **PARTIALLY IMPLEMENTED** - Existing `/agent/ask`, needs conversation memory integration

---

## OVERVIEW

### Current Status

✅ **Already Implemented:**
- `POST /api/v1/agent/ask` endpoint
- Basic question → agent → response flow
- PostgreSQL + Knowledge Graph integration
- AgentResponse model with narrative + visualizations

❌ **Missing (Needs Implementation):**
- Conversation memory integration
- Multi-turn conversation support
- Message history storage
- Session management
- Conversation list endpoints

### What This Document Provides

1. **Reference** to existing `/agent/ask` implementation
2. **Enhancement specification** for conversation memory (from doc 04)
3. **New endpoints** for conversation management
4. **Complete API specification** for chat system

---

## EXISTING IMPLEMENTATION REFERENCE

### File Location

```
backend/
└── app/
    ├── main.py  ← EXISTING: Contains /agent/ask endpoint
    └── services/
        └── autonomous_agent.py  ← EXISTING: 4-layer agent
```

### Current Endpoint (Existing)

```python
# backend/app/main.py (EXISTING)

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from app.services.autonomous_agent import AutonomousAnalyticalAgent

app = FastAPI()

class AgentRequest(BaseModel):
    """EXISTING: Agent request model"""
    question: str
    context: dict = {}

class AgentResponse(BaseModel):
    """EXISTING: Agent response model"""
    narrative: str
    visualizations: list
    confidence: str
    metadata: dict

@app.post("/api/v1/agent/ask", response_model=AgentResponse)
async def ask_agent(request: AgentRequest):
    """
    EXISTING ENDPOINT: Ask agent a question
    
    Current behavior:
    - Takes question + optional context
    - Runs through 4-layer agent
    - Returns narrative + visualizations
    - NO conversation memory
    - NO session tracking
    """
    agent = AutonomousAnalyticalAgent()
    
    response = await agent.process_question(
        question=request.question,
        context=request.context
    )
    
    return AgentResponse(
        narrative=response["narrative"],
        visualizations=response["visualizations"],
        confidence=response["confidence"],
        metadata=response["metadata"]
    )
```

**Limitation:** Each request is treated as isolated - no conversation history!

---

## ENHANCED IMPLEMENTATION (WITH CONVERSATION MEMORY)

### New Router Structure

```
backend/
└── app/
    └── api/
        └── endpoints/
            └── chat.py  ← NEW FILE (or enhance existing)
```

### Enhanced Chat Endpoints

```python
# backend/app/api/endpoints/chat.py (ENHANCED VERSION)

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.models.schemas import (
    ChatMessageRequest, 
    ChatMessageResponse,
    ConversationResponse,
    MessageResponse,
    MessageRole
)
from app.core.dependencies import get_current_user, get_db
from app.services.conversation_manager import ConversationManager
from app.services.autonomous_agent import AutonomousAnalyticalAgent

router = APIRouter(prefix="/api/v1/chat", tags=["Chat"])

# =====================================================
# ENHANCED: Send Message with Conversation Memory
# =====================================================

@router.post("/message", response_model=ChatMessageResponse)
async def send_message(
    request: ChatMessageRequest,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    ENHANCED: Send message to agent with conversation memory
    
    New features vs existing /agent/ask:
    - ✅ Conversation memory (multi-turn support)
    - ✅ Message history storage
    - ✅ Context-aware responses
    - ✅ Session tracking
    - ✅ User authentication
    
    Args:
        request.message: User question
        request.conversation_id: Existing conversation (null = new)
        request.persona_id: AI persona (null = default)
        request.context: Additional context
    
    Returns:
        ChatMessageResponse with conversation_id, response, confidence
    """
    # Initialize conversation manager
    conv_manager = ConversationManager(db)
    
    # Get or create conversation
    conversation = conv_manager.get_or_create_conversation(
        user_id=current_user.id,
        conversation_id=request.conversation_id,
        persona_id=request.persona_id or 1  # Default to Transformation Analyst
    )
    
    # Store user message in database
    user_message = conv_manager.store_message(
        conversation_id=conversation.id,
        role=MessageRole.USER,
        content=request.message,
        metadata=request.context or {}
    )
    
    # Build conversation context summary (for agent)
    context_summary = conv_manager.build_context_summary(
        conversation_id=conversation.id,
        max_messages=10
    )
    
    # Call autonomous agent with conversation context
    agent = AutonomousAnalyticalAgent(db)
    
    # Enhance context with conversation history
    enhanced_context = {
        "conversation_id": conversation.id,
        "conversation_context": context_summary,  # ← KEY: Previous messages
        "persona_id": conversation.persona_id,
        "user_id": current_user.id,
        **(request.context or {})
    }
    
    # Process question (existing agent method)
    agent_response = await agent.process_question(
        question=request.message,
        context=enhanced_context
    )
    
    # Store agent response in database
    assistant_message = conv_manager.store_message(
        conversation_id=conversation.id,
        role=MessageRole.ASSISTANT,
        content=agent_response["narrative"],
        artifact_ids=[],  # TODO: Extract from visualizations
        metadata={
            "confidence": agent_response["confidence"],
            "execution_time_ms": agent_response.get("execution_time_ms", 0),
            "insights_count": len(agent_response.get("insights", []))
        }
    )
    
    return ChatMessageResponse(
        success=True,
        conversation_id=conversation.id,
        message_id=assistant_message.id,
        response=agent_response["narrative"],
        artifacts=[],  # Will be populated when canvas system is implemented
        confidence=agent_response["confidence"],
        confidence_details=agent_response.get("confidence_explanation"),
        metadata=agent_response.get("metadata", {})
    )

# =====================================================
# NEW: Conversation Management Endpoints
# =====================================================

@router.get("/conversations", response_model=List[ConversationResponse])
async def list_conversations(
    limit: int = 20,
    offset: int = 0,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    NEW: Get user's conversation list
    
    Returns:
        List of conversations ordered by most recent
    """
    conversations = db.query(Conversation).filter(
        Conversation.user_id == current_user.id
    ).order_by(
        Conversation.updated_at.desc()
    ).offset(offset).limit(limit).all()
    
    result = []
    for conv in conversations:
        message_count = db.query(Message).filter(
            Message.conversation_id == conv.id
        ).count()
        
        conv_response = ConversationResponse.from_orm(conv)
        conv_response.message_count = message_count
        result.append(conv_response)
    
    return result

@router.get("/conversations/{conversation_id}", response_model=ConversationResponse)
async def get_conversation(
    conversation_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    NEW: Get single conversation details
    """
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == current_user.id
    ).first()
    
    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )
    
    return ConversationResponse.from_orm(conversation)

@router.get("/conversations/{conversation_id}/messages", response_model=List[MessageResponse])
async def get_conversation_messages(
    conversation_id: int,
    limit: int = 100,
    offset: int = 0,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    NEW: Get conversation message history
    
    Returns:
        List of messages in chronological order
    """
    # Verify conversation ownership
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == current_user.id
    ).first()
    
    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )
    
    # Get messages
    messages = db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).order_by(
        Message.created_at.asc()
    ).offset(offset).limit(limit).all()
    
    return [MessageResponse.from_orm(msg) for msg in messages]

@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    NEW: Delete conversation and all messages
    """
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == current_user.id
    ).first()
    
    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )
    
    # Delete conversation (cascades to messages)
    db.delete(conversation)
    db.commit()
    
    return {"success": True, "message": "Conversation deleted"}

@router.post("/conversations/{conversation_id}/switch-persona")
async def switch_persona(
    conversation_id: int,
    new_persona_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    NEW: Switch AI persona in conversation
    
    Example: Switch from Transformation Analyst to Digital Twin Designer
    """
    conv_manager = ConversationManager(db)
    
    # Verify ownership
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == current_user.id
    ).first()
    
    if not conversation:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found"
        )
    
    # Switch persona
    updated_conv = conv_manager.switch_persona(
        conversation_id=conversation_id,
        new_persona_id=new_persona_id
    )
    
    return {
        "success": True,
        "conversation_id": updated_conv.id,
        "persona_id": updated_conv.persona_id,
        "message": "Persona switched successfully"
    }

# =====================================================
# BACKWARD COMPATIBILITY: Keep existing /agent/ask
# =====================================================

@router.post("/agent/ask", response_model=AgentResponse)
async def ask_agent_legacy(request: AgentRequest):
    """
    EXISTING ENDPOINT: Maintained for backward compatibility
    
    Note: This endpoint does NOT have conversation memory.
    Use POST /chat/message for conversations.
    """
    agent = AutonomousAnalyticalAgent()
    
    response = await agent.process_question(
        question=request.question,
        context=request.context
    )
    
    return AgentResponse(
        narrative=response["narrative"],
        visualizations=response["visualizations"],
        confidence=response["confidence"],
        metadata=response["metadata"]
    )
```

---

## API SPECIFICATION SUMMARY

### Endpoints

| Method | Endpoint | Purpose | Auth Required |
|--------|----------|---------|---------------|
| **POST** | `/api/v1/chat/message` | Send message with conversation memory | ✅ Yes |
| **GET** | `/api/v1/chat/conversations` | List user's conversations | ✅ Yes |
| **GET** | `/api/v1/chat/conversations/{id}` | Get conversation details | ✅ Yes |
| **GET** | `/api/v1/chat/conversations/{id}/messages` | Get message history | ✅ Yes |
| **DELETE** | `/api/v1/chat/conversations/{id}` | Delete conversation | ✅ Yes |
| **POST** | `/api/v1/chat/conversations/{id}/switch-persona` | Switch AI persona | ✅ Yes |
| **POST** | `/api/v1/agent/ask` | Legacy endpoint (no memory) | ❌ No |

---

## REQUEST/RESPONSE EXAMPLES

### Example 1: Start New Conversation

```http
POST /api/v1/chat/message
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "message": "Which healthcare projects are behind schedule?",
  "conversation_id": null,
  "persona_id": 1
}
```

**Response:**
```json
{
  "success": true,
  "conversation_id": 42,
  "message_id": 101,
  "response": "Based on current data, 5 healthcare projects are behind schedule: Project Alpha (30% complete, target 60%), Project Beta (45% complete, target 70%)...",
  "artifacts": [],
  "confidence": "high",
  "confidence_details": "High confidence based on 284 projects analyzed with complete progress data.",
  "metadata": {
    "execution_time_ms": 1250,
    "insights": [...]
  }
}
```

### Example 2: Continue Conversation

```http
POST /api/v1/chat/message
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "message": "Why are they delayed?",
  "conversation_id": 42
}
```

**Response:**
```json
{
  "success": true,
  "conversation_id": 42,
  "message_id": 102,
  "response": "Analysis of the 5 delayed healthcare projects shows 3 main causes: Vendor delays (40% of projects), Budget constraints (35%), Resource shortages (25%)...",
  "confidence": "high",
  ...
}
```

### Example 3: Get Conversation History

```http
GET /api/v1/chat/conversations/42/messages
Authorization: Bearer <jwt_token>
```

**Response:**
```json
[
  {
    "id": 101,
    "conversation_id": 42,
    "role": "user",
    "content": "Which healthcare projects are behind schedule?",
    "artifact_ids": [],
    "metadata": {},
    "created_at": "2024-10-25T10:30:00Z"
  },
  {
    "id": 102,
    "conversation_id": 42,
    "role": "assistant",
    "content": "Based on current data, 5 healthcare projects...",
    "artifact_ids": [],
    "metadata": {"confidence": "high"},
    "created_at": "2024-10-25T10:30:05Z"
  },
  ...
]
```

---

## INTEGRATION WITH EXISTING AGENT

### Minimal Changes to autonomous_agent.py

```python
# backend/app/services/autonomous_agent.py (MINOR ENHANCEMENT)

class AutonomousAnalyticalAgent:
    
    async def process_question(self, question: str, context: Dict[str, Any]):
        """
        ENHANCED: Process question with optional conversation context
        
        Changes:
        - Check for 'conversation_context' in context dict
        - Pass to Layer 1 for context-aware intent understanding
        """
        
        # Layer 1: Intent Understanding (with conversation context)
        intent = await self._layer1_intent_understanding(
            question=question,
            context=context  # ← Now includes conversation_context if present
        )
        
        # Layers 2-4: Unchanged, continue as before
        retrieval = await self._layer2_hybrid_retrieval(intent, context)
        insights = await self._layer3_analytical_reasoning(retrieval, context)
        visualization = await self._layer4_visualization_generation(insights, context)
        
        return {
            "narrative": visualization["narrative"],
            "visualizations": visualization["visualizations"],
            "confidence": insights["confidence"],
            "metadata": {...}
        }
```

**Key Point:** The existing agent code requires MINIMAL changes - just pass conversation context through!

---

## TESTING

```python
# tests/test_chat_api.py

import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_send_message_new_conversation(auth_token):
    """Test starting new conversation"""
    response = client.post(
        "/api/v1/chat/message",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "message": "Which projects are behind?",
            "conversation_id": None,
            "persona_id": 1
        }
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "conversation_id" in data
    assert "response" in data
    assert data["success"] is True

def test_send_message_existing_conversation(auth_token, test_conversation):
    """Test multi-turn conversation"""
    # First message
    response1 = client.post(
        "/api/v1/chat/message",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "message": "Which healthcare projects are behind?",
            "conversation_id": test_conversation.id
        }
    )
    
    conv_id = response1.json()["conversation_id"]
    
    # Second message (context-aware)
    response2 = client.post(
        "/api/v1/chat/message",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "message": "Why are they delayed?",  # ← References previous question
            "conversation_id": conv_id
        }
    )
    
    assert response2.status_code == 200
    assert "delayed" in response2.json()["response"].lower()

def test_get_conversation_history(auth_token, test_conversation):
    """Test retrieving message history"""
    response = client.get(
        f"/api/v1/chat/conversations/{test_conversation.id}/messages",
        headers={"Authorization": f"Bearer {auth_token}"}
    )
    
    assert response.status_code == 200
    messages = response.json()
    assert len(messages) > 0
    assert all(msg["conversation_id"] == test_conversation.id for msg in messages)
```

---

## DEPLOYMENT CONFIGURATION

Add to `backend/app/main.py`:

```python
# backend/app/main.py (UPDATE)

from app.api.endpoints import chat

app = FastAPI(title="JOSOOR Transformation Platform")

# Include chat router
app.include_router(chat.router)

# Keep existing /agent/ask for backward compatibility
# (or move to chat router as shown above)
```

---

## CHECKLIST FOR CODING AGENT

### Implementation Tasks

- [ ] Create `app/api/endpoints/chat.py` with enhanced endpoints
- [ ] Implement `ConversationManager` (from doc 04)
- [ ] Add conversation context to `autonomous_agent.py` Layer 1
- [ ] Test multi-turn conversation flow
- [ ] Test conversation history retrieval
- [ ] Test persona switching
- [ ] Verify backward compatibility with existing `/agent/ask`

### Database Setup

- [ ] Verify `conversations` table exists (from doc 01)
- [ ] Verify `messages` table exists
- [ ] Test foreign key constraints
- [ ] Test cascade deletion

### Integration Testing

- [ ] Test new conversation creation
- [ ] Test context-aware responses ("they", "those projects")
- [ ] Test conversation list retrieval
- [ ] Test message history pagination
- [ ] Test conversation deletion

---

## NEXT STEPS

- [ ] Proceed to **12_CHAT_INTERFACE_FRONTEND.md** (React UI for multi-turn chat)
- [ ] Implement conversation sidebar in frontend
- [ ] Add chat bubbles for message history
- [ ] Test end-to-end conversation flow
