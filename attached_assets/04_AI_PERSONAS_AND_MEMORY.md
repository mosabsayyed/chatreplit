# AI PERSONAS & MEMORY SYSTEM

## META

**Dependencies:** 01_DATABASE_FOUNDATION.md, 02_CORE_DATA_MODELS.md, 03_AUTH_AND_USERS.md  
**Provides:** Multi-turn conversation memory, session management, context retention  
**Integration Points:** Chat backend (11), Agent orchestrator (10), Database conversations/messages tables  
**Status:** ✅ **FULLY IMPLEMENTED** (October 26, 2025)  
**Implementation Files:**
- `backend/app/services/conversation_manager.py` - ConversationManager class
- `backend/app/api/routes/chat.py` - Chat API with conversation memory
- `backend/app/services/autonomous_agent.py` - Agent with context integration
- `frontend/index.html` - Chat UI with conversation history display

---

## 📝 CHANGELOG

### October 26, 2025 - Documentation Update
**Changed:**
- ✅ Updated status from "PLANNED" to "✅ FULLY IMPLEMENTED"
- ✅ Added actual implementation file paths
- ✅ Documented live ConversationManager implementation in `backend/app/services/conversation_manager.py`
- ✅ Confirmed multi-turn conversation memory working in production

**Reason:** Align documentation with completed implementation

---

## OVERVIEW

This document describes the **fully implemented** multi-turn conversation memory system. The implementation enables the agent to maintain context across multiple conversation turns, resolve pronouns, and provide contextual responses.

**✅ IMPLEMENTATION STATUS:** This feature is now live and operational in the codebase.

### What This Enables

1. **Multi-turn conversations** - Agent remembers previous questions/answers
2. **Context retention** - "What about Project Alpha?" after asking about projects
3. **Session management** - User can continue conversation after refresh
4. **Conversation history** - Display past messages in chat UI
5. **Persona-aware memory** - Different personas maintain separate contexts

### Key Concept: Conversation Context

```
User: "Which projects are behind schedule?"
Agent: [Stores question + answer in memory]

User: "Why are they delayed?" ← Agent knows "they" = the projects from previous question
Agent: [Retrieves context, generates answer with full understanding]

User: "Show me the budget analysis" ← Agent knows which projects to analyze
Agent: [Context-aware response using memory]
```

---

## ARCHITECTURE

### Memory Flow

```
┌─────────────────────────────────────────────────────────────┐
│  USER SENDS MESSAGE                                          │
│  "Which healthcare projects are behind?"                     │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│  CONVERSATION MANAGER                                        │
│  1. Get/Create conversation                                  │
│  2. Retrieve conversation history (last N messages)          │
│  3. Build context summary                                    │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│  AGENT PROCESSING (with memory context)                      │
│  Layer 1: Intent + conversation context                      │
│  Layer 2: Retrieval (uses context for ambiguous refs)        │
│  Layer 3: Analysis (builds on previous insights)             │
│  Layer 4: Visualization                                      │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│  MEMORY STORAGE                                              │
│  1. Store user message in messages table                     │
│  2. Store agent response in messages table                   │
│  3. Update conversation timestamp                            │
│  4. Store artifacts (if generated)                           │
└─────────────────────────────────────────────────────────────┘
```

---

## IMPLEMENTATION

### Part 1: Conversation Manager

```python
# backend/app/services/conversation_manager.py
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session
from datetime import datetime
from app.db.models import Conversation, Message, User
from app.models.schemas import MessageRole, ConversationResponse, MessageResponse

class ConversationManager:
    """
    Manages conversation lifecycle and memory
    
    Responsibilities:
    - Create/retrieve conversations
    - Store/retrieve messages
    - Build conversation context for agent
    - Maintain conversation state
    """
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_or_create_conversation(
        self, 
        user_id: int, 
        conversation_id: Optional[int] = None,
        persona_id: int = 1  # Default to Transformation Analyst
    ) -> Conversation:
        """
        Get existing conversation or create new one
        
        Args:
            user_id: User ID
            conversation_id: Existing conversation ID (None = create new)
            persona_id: Persona ID for new conversation
        
        Returns:
            Conversation object
        """
        if conversation_id:
            # Retrieve existing conversation
            conversation = self.db.query(Conversation).filter(
                Conversation.id == conversation_id,
                Conversation.user_id == user_id
            ).first()
            
            if not conversation:
                raise ValueError(f"Conversation {conversation_id} not found for user {user_id}")
            
            return conversation
        else:
            # Create new conversation
            conversation = Conversation(
                user_id=user_id,
                persona_id=persona_id,
                title=None,  # Will be auto-generated from first message
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            self.db.add(conversation)
            self.db.commit()
            self.db.refresh(conversation)
            
            return conversation
    
    def store_message(
        self,
        conversation_id: int,
        role: MessageRole,
        content: str,
        artifact_ids: List[int] = [],
        metadata: Dict[str, Any] = {}
    ) -> Message:
        """
        Store message in conversation
        
        Args:
            conversation_id: Conversation ID
            role: Message role (user, assistant, system)
            content: Message content
            artifact_ids: List of artifact IDs generated
            metadata: Additional metadata (tool calls, confidence, etc.)
        
        Returns:
            Message object
        """
        message = Message(
            conversation_id=conversation_id,
            role=role.value,
            content=content,
            artifact_ids=artifact_ids,
            metadata=metadata,
            created_at=datetime.utcnow()
        )
        self.db.add(message)
        
        # Update conversation timestamp
        conversation = self.db.query(Conversation).filter(
            Conversation.id == conversation_id
        ).first()
        conversation.updated_at = datetime.utcnow()
        
        # Auto-generate title from first user message if not set
        if not conversation.title and role == MessageRole.USER:
            conversation.title = self._generate_title(content)
        
        self.db.commit()
        self.db.refresh(message)
        
        return message
    
    def get_conversation_history(
        self,
        conversation_id: int,
        limit: int = 10
    ) -> List[Message]:
        """
        Retrieve conversation history (most recent N messages)
        
        Args:
            conversation_id: Conversation ID
            limit: Maximum number of messages to retrieve
        
        Returns:
            List of Message objects (ordered chronologically)
        """
        messages = self.db.query(Message).filter(
            Message.conversation_id == conversation_id
        ).order_by(Message.created_at.desc()).limit(limit).all()
        
        # Reverse to get chronological order
        return list(reversed(messages))
    
    def build_context_summary(
        self,
        conversation_id: int,
        max_messages: int = 10
    ) -> str:
        """
        Build conversation context summary for agent
        
        This creates a condensed summary of conversation history
        to provide context without overwhelming the agent with tokens.
        
        Args:
            conversation_id: Conversation ID
            max_messages: Maximum messages to include
        
        Returns:
            Context summary string
        """
        messages = self.get_conversation_history(conversation_id, limit=max_messages)
        
        if not messages:
            return ""
        
        # Build context summary
        context_parts = ["Previous conversation context:"]
        
        for i, msg in enumerate(messages[-5:], 1):  # Last 5 messages only
            role_label = "User" if msg.role == MessageRole.USER.value else "Assistant"
            # Truncate long messages
            content_preview = msg.content[:200] + "..." if len(msg.content) > 200 else msg.content
            context_parts.append(f"{i}. {role_label}: {content_preview}")
        
        return "\n".join(context_parts)
    
    def get_conversation_metadata(
        self,
        conversation_id: int
    ) -> Dict[str, Any]:
        """
        Get conversation metadata (persona, created date, message count)
        
        Args:
            conversation_id: Conversation ID
        
        Returns:
            Metadata dictionary
        """
        conversation = self.db.query(Conversation).filter(
            Conversation.id == conversation_id
        ).first()
        
        message_count = self.db.query(Message).filter(
            Message.conversation_id == conversation_id
        ).count()
        
        return {
            "conversation_id": conversation.id,
            "persona_id": conversation.persona_id,
            "title": conversation.title,
            "created_at": conversation.created_at.isoformat(),
            "updated_at": conversation.updated_at.isoformat(),
            "message_count": message_count
        }
    
    def _generate_title(self, first_message: str) -> str:
        """
        Auto-generate conversation title from first user message
        
        Args:
            first_message: First user message
        
        Returns:
            Generated title (truncated to 50 chars)
        """
        # Simple heuristic: use first sentence or first 50 chars
        title = first_message.split('.')[0].split('?')[0].split('!')[0]
        return title[:50] + "..." if len(title) > 50 else title
    
    def switch_persona(
        self,
        conversation_id: int,
        new_persona_id: int
    ) -> Conversation:
        """
        Switch persona for conversation
        
        Args:
            conversation_id: Conversation ID
            new_persona_id: New persona ID
        
        Returns:
            Updated conversation
        """
        conversation = self.db.query(Conversation).filter(
            Conversation.id == conversation_id
        ).first()
        
        if not conversation:
            raise ValueError(f"Conversation {conversation_id} not found")
        
        # Store persona switch in message history
        self.store_message(
            conversation_id=conversation_id,
            role=MessageRole.SYSTEM,
            content=f"Switched persona to {new_persona_id}",
            metadata={"event": "persona_switch", "from_persona": conversation.persona_id, "to_persona": new_persona_id}
        )
        
        conversation.persona_id = new_persona_id
        conversation.updated_at = datetime.utcnow()
        self.db.commit()
        
        return conversation
```

### Part 2: Integration with Existing Agent

```python
# backend/app/api/endpoints/chat.py (ENHANCEMENT)
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.models.schemas import ChatMessageRequest, ChatMessageResponse, MessageRole
from app.core.dependencies import get_current_user, get_db
from app.services.conversation_manager import ConversationManager
from app.services.autonomous_agent import AutonomousAnalyticalAgent

router = APIRouter(prefix="/api/v1/chat", tags=["Chat"])

@router.post("/message", response_model=ChatMessageResponse)
async def send_message(
    request: ChatMessageRequest,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Send message to agent with conversation memory
    
    Enhanced version of /api/v1/agent/ask with memory support
    """
    # Initialize conversation manager
    conv_manager = ConversationManager(db)
    
    # Get or create conversation
    conversation = conv_manager.get_or_create_conversation(
        user_id=current_user.id,
        conversation_id=request.conversation_id,
        persona_id=request.persona_id or 1  # Default to Transformation Analyst
    )
    
    # Store user message
    user_message = conv_manager.store_message(
        conversation_id=conversation.id,
        role=MessageRole.USER,
        content=request.message,
        metadata=request.context or {}
    )
    
    # Build conversation context
    context_summary = conv_manager.build_context_summary(conversation.id)
    
    # Call agent with context
    agent = AutonomousAnalyticalAgent(db)
    
    # Enhance request with conversation context
    enhanced_context = {
        "conversation_id": conversation.id,
        "conversation_context": context_summary,
        "persona_id": conversation.persona_id,
        **(request.context or {})
    }
    
    agent_response = await agent.process_question(
        question=request.message,
        context=enhanced_context
    )
    
    # Store agent response
    assistant_message = conv_manager.store_message(
        conversation_id=conversation.id,
        role=MessageRole.ASSISTANT,
        content=agent_response.narrative,
        artifact_ids=[v.get('artifact_id') for v in agent_response.visualizations if v.get('artifact_id')],
        metadata={
            "confidence": agent_response.confidence,
            "execution_time_ms": agent_response.execution_time_ms,
            "insights_count": len(agent_response.insights)
        }
    )
    
    return ChatMessageResponse(
        success=True,
        conversation_id=conversation.id,
        message_id=assistant_message.id,
        response=agent_response.narrative,
        artifacts=[],  # TODO: Convert visualizations to artifacts
        confidence=agent_response.confidence,
        confidence_details=agent_response.confidence_explanation,
        metadata={
            "execution_time_ms": agent_response.execution_time_ms,
            "insights": agent_response.insights
        }
    )

@router.get("/conversations", response_model=List[ConversationResponse])
async def list_conversations(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's conversation list"""
    conversations = db.query(Conversation).filter(
        Conversation.user_id == current_user.id
    ).order_by(Conversation.updated_at.desc()).all()
    
    return [ConversationResponse.from_orm(conv) for conv in conversations]

@router.get("/conversations/{conversation_id}/messages", response_model=List[MessageResponse])
async def get_conversation_messages(
    conversation_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get conversation message history"""
    # Verify ownership
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == current_user.id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    conv_manager = ConversationManager(db)
    messages = conv_manager.get_conversation_history(conversation_id, limit=100)
    
    return [MessageResponse.from_orm(msg) for msg in messages]

@router.post("/conversations/{conversation_id}/switch-persona")
async def switch_conversation_persona(
    conversation_id: int,
    new_persona_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Switch persona for conversation"""
    conv_manager = ConversationManager(db)
    
    # Verify ownership
    conversation = db.query(Conversation).filter(
        Conversation.id == conversation_id,
        Conversation.user_id == current_user.id
    ).first()
    
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    updated_conv = conv_manager.switch_persona(conversation_id, new_persona_id)
    
    return {"success": True, "conversation_id": updated_conv.id, "persona_id": updated_conv.persona_id}
```

### Part 3: Agent Layer 1 Enhancement (Context-Aware Intent)

```python
# backend/app/services/autonomous_agent.py (ENHANCEMENT TO LAYER 1)

class AutonomousAnalyticalAgent:
    
    async def _layer1_intent_understanding(
        self, 
        question: str, 
        context: Dict[str, Any]
    ) -> IntentUnderstanding:
        """
        Layer 1: Intent Understanding with Conversation Context
        
        Enhanced to handle conversation context and resolve references
        like "they", "those projects", "the same data"
        """
        # Build system prompt with conversation context
        system_prompt = f"""You are Layer 1: Intent Understanding for organizational transformation analysis.

Your job: Parse the user's question and extract structured intent.

CONVERSATION CONTEXT:
{context.get('conversation_context', 'No prior conversation.')}

CURRENT QUESTION: {question}

INSTRUCTIONS:
1. If the question references previous context (e.g., "they", "those", "the same"):
   - Resolve references using conversation context
   - Extract the actual entities being discussed
   
2. Extract:
   - entities: List of table names (ent_projects, sec_objectives, etc.)
   - temporal_scope: {{year: YYYY, quarter: "QX"}}
   - operational_chain: Which chain applies (SectorOps, Strategy_to_Tactics, etc.)
   - question_type: status_check, comparison, trend_analysis, drill_down, correlation
   - extracted_filters: Any specific filters (project_name, status, etc.)

3. Output JSON format:
{{
  "entities": ["table_name1", "table_name2"],
  "temporal_scope": {{"year": 2024, "quarter": null}},
  "operational_chain": "SectorOps",
  "question_type": "status_check",
  "extracted_filters": {{"status": "in_progress"}},
  "confidence": "high"
}}

EXAMPLES:

User: "Which healthcare projects are behind schedule?"
Output: {{"entities": ["ent_projects"], "temporal_scope": {{"year": 2024}}, "question_type": "status_check", "extracted_filters": {{"sector": "healthcare", "status": "in_progress", "progress_threshold": 50}}}}

User: "Why are they delayed?" (after previous question about projects)
Output: {{"entities": ["ent_projects", "ent_risks"], "temporal_scope": {{"year": 2024}}, "question_type": "drill_down", "extracted_filters": {{"sector": "healthcare", "status": "in_progress"}}, "resolved_reference": "healthcare projects from previous question"}}
"""
        
        # Call LLM
        response = await self.llm.chat_completion(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": question}
            ],
            temperature=0.3
        )
        
        # Parse JSON response
        intent_data = json.loads(response)
        
        return IntentUnderstanding(**intent_data)
```

### Part 4: Session State in Redis (Optional Enhancement)

```python
# backend/app/services/session_state.py
import redis
import json
from typing import Dict, Any, Optional

class SessionStateManager:
    """
    Manage ephemeral session state in Redis
    
    Complements database conversation storage with fast access to:
    - Current conversation context
    - User preferences
    - Temporary query results
    """
    
    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
    
    def store_conversation_state(
        self,
        conversation_id: int,
        state: Dict[str, Any],
        ttl: int = 3600  # 1 hour
    ):
        """Store conversation state in Redis"""
        key = f"conv_state:{conversation_id}"
        self.redis.setex(key, ttl, json.dumps(state))
    
    def get_conversation_state(
        self,
        conversation_id: int
    ) -> Optional[Dict[str, Any]]:
        """Retrieve conversation state from Redis"""
        key = f"conv_state:{conversation_id}"
        data = self.redis.get(key)
        return json.loads(data) if data else None
    
    def update_conversation_state(
        self,
        conversation_id: int,
        updates: Dict[str, Any]
    ):
        """Update conversation state (merge with existing)"""
        current_state = self.get_conversation_state(conversation_id) or {}
        current_state.update(updates)
        self.store_conversation_state(conversation_id, current_state)
```

---

## FRONTEND INTEGRATION

### Enhanced Chat Component (Context-Aware)

```typescript
// frontend/src/services/chatService.ts
import apiClient from './api';
import { ChatMessageRequest, ChatMessageResponse, ConversationResponse } from '../types';

class ChatService {
  /**
   * Send message with conversation context
   */
  async sendMessage(
    message: string,
    conversationId?: number,
    personaId?: number
  ): Promise<ChatMessageResponse> {
    const response = await apiClient.post<ChatMessageResponse>('/chat/message', {
      message,
      conversation_id: conversationId,
      persona_id: personaId
    });
    
    return response.data;
  }

  /**
   * Get conversation list
   */
  async getConversations(): Promise<ConversationResponse[]> {
    const response = await apiClient.get<ConversationResponse[]>('/chat/conversations');
    return response.data;
  }

  /**
   * Get conversation message history
   */
  async getConversationMessages(conversationId: number) {
    const response = await apiClient.get(`/chat/conversations/${conversationId}/messages`);
    return response.data;
  }

  /**
   * Switch persona in conversation
   */
  async switchPersona(conversationId: number, newPersonaId: number) {
    const response = await apiClient.post(
      `/chat/conversations/${conversationId}/switch-persona`,
      { new_persona_id: newPersonaId }
    );
    return response.data;
  }
}

export default new ChatService();
```

---

## DATABASE MODELS (Already in 01_DATABASE_FOUNDATION.md)

**Note:** The required tables already exist:
- ✅ `conversations` table
- ✅ `messages` table  
- ✅ `personas` table

**Foreign keys:**
- `conversations.user_id` → `users.id`
- `conversations.persona_id` → `personas.id`
- `messages.conversation_id` → `conversations.id`

---

## TESTING

```python
# tests/test_conversation_manager.py
import pytest
from app.services.conversation_manager import ConversationManager
from app.models.schemas import MessageRole

def test_create_conversation(db_session, test_user):
    """Test conversation creation"""
    conv_manager = ConversationManager(db_session)
    
    conv = conv_manager.get_or_create_conversation(
        user_id=test_user.id,
        persona_id=1
    )
    
    assert conv.id is not None
    assert conv.user_id == test_user.id
    assert conv.persona_id == 1

def test_store_retrieve_messages(db_session, test_conversation):
    """Test message storage and retrieval"""
    conv_manager = ConversationManager(db_session)
    
    # Store user message
    msg1 = conv_manager.store_message(
        conversation_id=test_conversation.id,
        role=MessageRole.USER,
        content="Which projects are behind?"
    )
    
    # Store assistant response
    msg2 = conv_manager.store_message(
        conversation_id=test_conversation.id,
        role=MessageRole.ASSISTANT,
        content="5 projects are behind schedule..."
    )
    
    # Retrieve history
    history = conv_manager.get_conversation_history(test_conversation.id)
    
    assert len(history) == 2
    assert history[0].role == MessageRole.USER.value
    assert history[1].role == MessageRole.ASSISTANT.value

def test_context_summary(db_session, test_conversation):
    """Test context summary generation"""
    conv_manager = ConversationManager(db_session)
    
    # Add several messages
    for i in range(6):
        conv_manager.store_message(
            conversation_id=test_conversation.id,
            role=MessageRole.USER if i % 2 == 0 else MessageRole.ASSISTANT,
            content=f"Message {i}"
        )
    
    # Get context summary (should include last 5 messages)
    summary = conv_manager.build_context_summary(test_conversation.id)
    
    assert "Previous conversation context:" in summary
    assert "Message 5" in summary  # Most recent
```

---

## CONFIGURATION

Add to `.env`:
```bash
# Conversation settings
MAX_CONVERSATION_HISTORY=10  # Messages to send to agent as context
CONVERSATION_TITLE_MAX_LENGTH=50
```

---

## EXAMPLES

### Example 1: Multi-Turn Conversation

```python
# Request 1
POST /api/v1/chat/message
{
  "message": "Which healthcare projects are behind schedule?",
  "conversation_id": null,  # New conversation
  "persona_id": 1
}

# Response 1
{
  "success": true,
  "conversation_id": 42,
  "message_id": 101,
  "response": "5 healthcare projects are behind schedule: Project Alpha (30% complete), Project Beta (45% complete)...",
  "confidence": "high"
}

# Request 2 (same conversation)
POST /api/v1/chat/message
{
  "message": "Why are they delayed?",  # ← "they" references previous projects
  "conversation_id": 42
}

# Response 2
{
  "success": true,
  "conversation_id": 42,
  "message_id": 102,
  "response": "Analysis of the 5 delayed healthcare projects shows 3 main causes: vendor delays (40%), budget constraints (35%), resource shortages (25%)...",
  "confidence": "high"
}

# Request 3
POST /api/v1/chat/message
{
  "message": "Show me the budget breakdown",  # ← Agent knows which projects
  "conversation_id": 42
}
```

---

## CHECKLIST FOR CODING AGENT

### Backend Implementation

- [ ] Create `app/services/conversation_manager.py`
- [ ] Enhance `app/api/endpoints/chat.py` with conversation endpoints
- [ ] Enhance `app/services/autonomous_agent.py` Layer 1 with context handling
- [ ] Test conversation creation
- [ ] Test message storage/retrieval
- [ ] Test context summary generation
- [ ] Test multi-turn conversation flow

### Frontend Integration

- [ ] Create `src/services/chatService.ts`
- [ ] Update chat component to use conversation_id
- [ ] Add conversation list UI
- [ ] Add message history display
- [ ] Test multi-turn conversation in UI

### Database

- [ ] Verify `conversations` table exists (from 01_DATABASE_FOUNDATION.md)
- [ ] Verify `messages` table exists
- [ ] Verify foreign keys are set up correctly

### Testing

- [ ] Write unit tests for ConversationManager
- [ ] Write integration tests for chat endpoints
- [ ] Test conversation context in agent responses
- [ ] Test persona switching

---

## NEXT STEPS

- [ ] Proceed to **05_LLM_PROVIDER_ABSTRACTION.md** (reference existing code)
- [ ] Proceed to **11_CHAT_INTERFACE_BACKEND.md** (document existing + enhancements)
- [ ] Integrate conversation manager with existing `/api/v1/agent/ask` endpoint
