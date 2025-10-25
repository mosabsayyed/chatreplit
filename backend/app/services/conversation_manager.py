# backend/app/services/conversation_manager.py
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc
from datetime import datetime

from app.db.models import Conversation, Message, Persona


class ConversationManager:
    """
    Conversation Memory Manager - Enables multi-turn conversations
    
    This is the bridge between stateless agent and persistent conversation history.
    
    Key Methods:
    - create_conversation() - Start new chat session
    - add_message() - Store user/assistant messages
    - build_conversation_context() - THE MAGIC - Build context string for agent
    - get_relevant_past_results() - Find historical queries for trend analysis
    """
    
    def __init__(self, db_session: Session):
        self.db = db_session
    
    # ==================== CONVERSATION CRUD ====================
    
    def create_conversation(
        self,
        user_id: int,
        persona_name: str = "transformation_analyst",
        title: str = None
    ) -> Conversation:
        """
        Create a new conversation session
        
        Args:
            user_id: ID of the user
            persona_name: Name of persona (default: transformation_analyst)
            title: Optional title (auto-generated from first message if None)
        
        Returns:
            Conversation object
        """
        # Get persona ID
        persona = self.db.query(Persona).filter(Persona.name == persona_name).first()
        if not persona:
            raise ValueError(f"Persona '{persona_name}' not found. Please seed personas first.")
        
        # Create conversation
        conversation = Conversation(
            user_id=user_id,
            persona_id=persona.id,
            title=title or "New Conversation",
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        self.db.add(conversation)
        self.db.commit()
        self.db.refresh(conversation)
        
        return conversation
    
    def get_conversation(
        self,
        conversation_id: int,
        user_id: int
    ) -> Optional[Conversation]:
        """
        Get conversation by ID (with user ownership check)
        """
        return self.db.query(Conversation).filter(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id
        ).first()
    
    def list_conversations(
        self,
        user_id: int,
        limit: int = 50,
        offset: int = 0
    ) -> List[Conversation]:
        """
        List all conversations for a user (most recent first)
        """
        return self.db.query(Conversation).filter(
            Conversation.user_id == user_id
        ).order_by(
            desc(Conversation.updated_at)
        ).limit(limit).offset(offset).all()
    
    def delete_conversation(
        self,
        conversation_id: int,
        user_id: int
    ) -> bool:
        """
        Delete conversation (cascades to messages)
        """
        conversation = self.get_conversation(conversation_id, user_id)
        if conversation:
            self.db.delete(conversation)
            self.db.commit()
            return True
        return False
    
    # ==================== MESSAGE CRUD ====================
    
    def add_message(
        self,
        conversation_id: int,
        role: str,
        content: str,
        metadata: Dict[str, Any] = None
    ) -> Message:
        """
        Add a message to conversation
        
        THIS IS THE KEY METHOD - Called after every user query and agent response
        
        Args:
            conversation_id: ID of conversation
            role: 'user', 'assistant', or 'system'
            content: Message text
            metadata: Optional dict with viz configs, entities, etc.
        
        Returns:
            Message object
        """
        message = Message(
            conversation_id=conversation_id,
            role=role,
            content=content,
            extra_metadata=metadata or {},
            created_at=datetime.utcnow()
        )
        
        self.db.add(message)
        
        # Update conversation timestamp
        conversation = self.db.query(Conversation).filter(
            Conversation.id == conversation_id
        ).first()
        if conversation:
            conversation.updated_at = datetime.utcnow()
            
            # Auto-generate title from first user message
            if conversation.title == "New Conversation" and role == "user":
                conversation.title = content[:50] + ("..." if len(content) > 50 else "")
        
        self.db.commit()
        self.db.refresh(message)
        
        return message
    
    def get_messages(
        self,
        conversation_id: int,
        limit: int = 100,
        offset: int = 0,
        order_desc: bool = False
    ) -> List[Message]:
        """
        Get messages for a conversation
        
        Args:
            order_desc: If True, get most recent messages first (for context building)
        """
        query = self.db.query(Message).filter(
            Message.conversation_id == conversation_id
        )
        
        if order_desc:
            query = query.order_by(desc(Message.created_at))
        else:
            query = query.order_by(Message.created_at)
        
        return query.limit(limit).offset(offset).all()
    
    # ==================== CONTEXT BUILDING (THE MAGIC) ====================
    
    def build_conversation_context(
        self,
        conversation_id: int,
        max_messages: int = 10
    ) -> str:
        """
        Build context summary from MOST RECENT messages
        
        THIS IS WHAT THE AGENT NEEDS - Returns formatted string with conversation history
        
        Args:
            conversation_id: ID of conversation
            max_messages: How many recent messages to include (default: 10)
        
        Returns:
            Formatted string like:
            "User: Show me education sector health
             Assistant: Education sector health is 75/100...
             User: Compare it with healthcare"
        """
        # CRITICAL FIX: Get most recent messages (desc order) then reverse to chronological
        messages = self.get_messages(conversation_id, limit=max_messages, order_desc=True)
        
        if not messages:
            return "No previous conversation history."
        
        # Reverse to chronological order (oldest first)
        messages = list(reversed(messages))
        
        context_lines = []
        for msg in messages:
            role_label = msg.role.capitalize()
            # Truncate long messages for context
            content = msg.content[:200] + ("..." if len(msg.content) > 200 else "")
            context_lines.append(f"{role_label}: {content}")
        
        return "\n".join(context_lines)
    
    def get_relevant_past_results(
        self,
        conversation_id: int,
        current_entities: List[str],
        limit: int = 3
    ) -> List[Dict[str, Any]]:
        """
        Get past query results relevant to current entities
        
        THIS ENABLES TREND ANALYSIS - Finds previous queries about same sectors/entities
        
        Args:
            conversation_id: ID of conversation
            current_entities: List of entities in current query (e.g., ["education", "2024"])
            limit: How many past results to return
        
        Returns:
            List of dicts with past query results that mentioned same entities
        """
        messages = self.get_messages(conversation_id, limit=50)
        
        relevant_results = []
        for msg in messages:
            if msg.role != "assistant":
                continue
            
            # Check if metadata contains relevant entities
            if not msg.extra_metadata:
                continue
            
            metadata = msg.extra_metadata
            
            # Check for entity overlap
            msg_entities = []
            if "dimensions" in metadata:
                msg_entities.extend([d.get("name") for d in metadata.get("dimensions", [])])
            if "entities" in metadata:
                msg_entities.extend(metadata.get("entities", []))
            
            # Calculate overlap
            overlap = set(current_entities).intersection(set(msg_entities))
            if overlap:
                relevant_results.append({
                    "message_id": msg.id,
                    "content": msg.content,
                    "metadata": metadata,
                    "overlap": list(overlap),
                    "created_at": msg.created_at.isoformat()
                })
        
        # Sort by overlap size and recency
        relevant_results.sort(
            key=lambda x: (len(x["overlap"]), x["created_at"]),
            reverse=True
        )
        
        return relevant_results[:limit]
    
    # ==================== UTILITY METHODS ====================
    
    def get_conversation_summary(
        self,
        conversation_id: int
    ) -> Dict[str, Any]:
        """
        Get conversation metadata summary
        """
        conversation = self.db.query(Conversation).filter(
            Conversation.id == conversation_id
        ).first()
        
        if not conversation:
            return None
        
        message_count = self.db.query(Message).filter(
            Message.conversation_id == conversation_id
        ).count()
        
        return {
            "id": conversation.id,
            "title": conversation.title,
            "persona_id": conversation.persona_id,
            "message_count": message_count,
            "created_at": conversation.created_at.isoformat(),
            "updated_at": conversation.updated_at.isoformat()
        }
