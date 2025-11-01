from typing import Dict, Any, List, Optional
from datetime import datetime
from app.db.supabase_client import SupabaseClient


class SupabaseConversationManager:
    def __init__(self, supabase_client: SupabaseClient):
        self.client = supabase_client
    
    async def create_conversation(
        self,
        user_id: int,
        persona_name: str = "transformation_analyst",
        title: str = None
    ) -> Dict[str, Any]:
        personas = await self.client.table_select('personas', '*', {'name': persona_name})
        if not personas:
            raise ValueError(f"Persona '{persona_name}' not found. Please seed personas first.")
        
        persona = personas[0]
        
        conversation_data = {
            'user_id': user_id,
            'persona_id': persona['id'],
            'title': title or "New Conversation",
            'created_at': datetime.utcnow().isoformat(),
            'updated_at': datetime.utcnow().isoformat()
        }
        
        result = await self.client.table_insert('conversations', conversation_data)
        return result[0] if result else None
    
    async def get_conversation(
        self,
        conversation_id: int,
        user_id: int
    ) -> Optional[Dict[str, Any]]:
        conversations = await self.client.table_select(
            'conversations',
            '*',
            {'id': conversation_id, 'user_id': user_id}
        )
        return conversations[0] if conversations else None
    
    async def list_conversations(
        self,
        user_id: int,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        conversations = await self.client.table_select(
            'conversations',
            '*',
            {'user_id': user_id}
        )
        conversations.sort(key=lambda x: x.get('updated_at', ''), reverse=True)
        return conversations[:limit]
    
    async def delete_conversation(
        self,
        conversation_id: int,
        user_id: int
    ) -> bool:
        conversation = await self.get_conversation(conversation_id, user_id)
        if conversation:
            await self.client.table_delete('conversations', {'id': conversation_id})
            return True
        return False
    
    async def add_message(
        self,
        conversation_id: int,
        role: str,
        content: str,
        metadata: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        message_data = {
            'conversation_id': conversation_id,
            'role': role,
            'content': content,
            'extra_metadata': metadata or {},
            'created_at': datetime.utcnow().isoformat()
        }
        
        result = await self.client.table_insert('messages', message_data)
        message = result[0] if result else None
        
        conversations = await self.client.table_select('conversations', '*', {'id': conversation_id})
        if conversations:
            conversation = conversations[0]
            update_data = {'updated_at': datetime.utcnow().isoformat()}
            
            if conversation.get('title') == "New Conversation" and role == "user":
                update_data['title'] = content[:50] + ("..." if len(content) > 50 else "")
            
            await self.client.table_update('conversations', update_data, {'id': conversation_id})
        
        return message
    
    async def get_messages(
        self,
        conversation_id: int,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        messages = await self.client.table_select(
            'messages',
            '*',
            {'conversation_id': conversation_id}
        )
        messages.sort(key=lambda x: x.get('created_at', ''))
        return messages[-limit:] if len(messages) > limit else messages
    
    async def build_conversation_context(
        self,
        conversation_id: int,
        max_messages: int = 10
    ) -> str:
        messages = await self.get_messages(conversation_id, limit=max_messages)
        
        if not messages:
            return "No previous conversation history."
        
        messages.sort(key=lambda x: x.get('created_at', ''), reverse=True)
        messages = list(reversed(messages[-max_messages:]))
        
        context_lines = []
        for msg in messages:
            role_label = msg['role'].capitalize()
            content = msg['content'][:200] + ("..." if len(msg['content']) > 200 else "")
            context_lines.append(f"{role_label}: {content}")
        
        return "\n".join(context_lines)
