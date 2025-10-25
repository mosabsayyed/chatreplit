# CHAT INTERFACE FRONTEND (REFERENCE + ENHANCEMENTS)

## META

**Dependencies:** 02_CORE_DATA_MODELS.md, 11_CHAT_INTERFACE_BACKEND.md  
**Provides:** React chat UI with conversation memory  
**Integration Points:** Chat backend API (11), Auth service (03)  
**Status:** ⚠️ **PARTIALLY IMPLEMENTED** - Existing UI, needs chat bubbles + conversation history

---

## OVERVIEW

### Current Status (Existing)

✅ **Already Implemented** (`frontend/index.html`):
- Beautiful purple gradient UI design
- Text input field
- 4 suggestion buttons
- AI narrative response display
- Visualization display (base64 images)

❌ **Missing (Needs Implementation)**:
- Chat bubbles for messages
- Conversation history sidebar
- Multi-turn conversation UI
- Message persistence across refresh
- Persona switcher
- Conversation list

---

## ENHANCED IMPLEMENTATION

### File Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── Chat/
│   │   │   ├── ChatInterface.tsx         ← NEW: Main chat component
│   │   │   ├── ChatMessage.tsx           ← NEW: Message bubble
│   │   │   ├── ChatInput.tsx             ← NEW: Input field
│   │   │   ├── ConversationSidebar.tsx   ← NEW: Conversation list
│   │   │   └── PersonaSwitcher.tsx       ← NEW: Persona toggle
│   ├── services/
│   │   └── chatService.ts                ← NEW: API client
│   └── types/
│       └── chat.ts                        ← NEW: TypeScript types
└── index.html                             ← EXISTING: Current UI
```

### ChatInterface Component (Main)

```typescript
// src/components/Chat/ChatInterface.tsx

import React, { useState, useEffect, useRef } from 'react';
import { ChatMessage } from './ChatMessage';
import { ChatInput } from './ChatInput';
import { ConversationSidebar } from './ConversationSidebar';
import chatService from '../../services/chatService';
import { Message, Conversation } from '../../types/chat';

export const ChatInterface: React.FC = () => {
  const [currentConversation, setCurrentConversation] = useState<number | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [loading, setLoading] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  // Load conversations on mount
  useEffect(() => {
    loadConversations();
  }, []);

  // Load messages when conversation changes
  useEffect(() => {
    if (currentConversation) {
      loadMessages(currentConversation);
    }
  }, [currentConversation]);

  // Auto-scroll to bottom
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const loadConversations = async () => {
    try {
      const convs = await chatService.getConversations();
      setConversations(convs);
    } catch (error) {
      console.error('Failed to load conversations:', error);
    }
  };

  const loadMessages = async (conversationId: number) => {
    try {
      const msgs = await chatService.getConversationMessages(conversationId);
      setMessages(msgs);
    } catch (error) {
      console.error('Failed to load messages:', error);
    }
  };

  const handleSendMessage = async (message: string) => {
    if (!message.trim()) return;

    setLoading(true);

    // Optimistic UI update
    const userMessage: Message = {
      id: Date.now(),
      conversation_id: currentConversation || 0,
      role: 'user',
      content: message,
      artifact_ids: [],
      metadata: {},
      created_at: new Date().toISOString()
    };
    setMessages(prev => [...prev, userMessage]);

    try {
      const response = await chatService.sendMessage(
        message,
        currentConversation || undefined
      );

      // Update conversation ID if new
      if (!currentConversation) {
        setCurrentConversation(response.conversation_id);
        await loadConversations(); // Refresh conversation list
      }

      // Add assistant response
      const assistantMessage: Message = {
        id: response.message_id,
        conversation_id: response.conversation_id,
        role: 'assistant',
        content: response.response,
        artifact_ids: response.artifacts.map(a => a.id),
        metadata: response.metadata,
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, assistantMessage]);

    } catch (error) {
      console.error('Failed to send message:', error);
      // Remove optimistic message on error
      setMessages(prev => prev.filter(m => m.id !== userMessage.id));
    } finally {
      setLoading(false);
    }
  };

  const handleNewConversation = () => {
    setCurrentConversation(null);
    setMessages([]);
  };

  const handleSelectConversation = (conversationId: number) => {
    setCurrentConversation(conversationId);
  };

  return (
    <div className="flex h-screen bg-gradient-to-br from-purple-900 to-indigo-900">
      {/* Sidebar */}
      {sidebarOpen && (
        <ConversationSidebar
          conversations={conversations}
          currentConversation={currentConversation}
          onSelectConversation={handleSelectConversation}
          onNewConversation={handleNewConversation}
        />
      )}

      {/* Main Chat Area */}
      <div className="flex-1 flex flex-col">
        {/* Header */}
        <div className="bg-white/10 backdrop-blur-lg p-4 flex items-center justify-between">
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="text-white p-2 rounded hover:bg-white/20"
          >
            ☰
          </button>
          <h1 className="text-white text-xl font-bold">JOSOOR AI Assistant</h1>
          <div className="w-8" /> {/* Spacer */}
        </div>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 ? (
            <div className="text-center text-white/60 mt-20">
              <h2 className="text-2xl font-bold mb-4">Start a conversation</h2>
              <p>Ask me about your transformation projects...</p>
            </div>
          ) : (
            messages.map(msg => (
              <ChatMessage key={msg.id} message={msg} />
            ))
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Input */}
        <ChatInput
          onSend={handleSendMessage}
          loading={loading}
          placeholder="Ask about your transformation..."
        />
      </div>
    </div>
  );
};
```

### ChatMessage Component (Bubble)

```typescript
// src/components/Chat/ChatMessage.tsx

import React from 'react';
import { Message } from '../../types/chat';

interface ChatMessageProps {
  message: Message;
}

export const ChatMessage: React.FC<ChatMessageProps> = ({ message }) => {
  const isUser = message.role === 'user';

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div
        className={`max-w-3xl rounded-lg p-4 ${
          isUser
            ? 'bg-purple-600 text-white'
            : 'bg-white/10 backdrop-blur-lg text-white'
        }`}
      >
        {!isUser && (
          <div className="text-xs text-purple-300 mb-2">AI Assistant</div>
        )}
        
        <div className="prose prose-invert">
          {message.content}
        </div>

        {message.metadata?.confidence && (
          <div className="mt-2 text-xs opacity-60">
            Confidence: {message.metadata.confidence}
          </div>
        )}

        {message.artifact_ids?.length > 0 && (
          <div className="mt-2 text-xs text-purple-300">
            📊 {message.artifact_ids.length} visualization(s) generated
          </div>
        )}
      </div>
    </div>
  );
};
```

### ChatInput Component

```typescript
// src/components/Chat/ChatInput.tsx

import React, { useState, KeyboardEvent } from 'react';

interface ChatInputProps {
  onSend: (message: string) => void;
  loading: boolean;
  placeholder?: string;
}

export const ChatInput: React.FC<ChatInputProps> = ({
  onSend,
  loading,
  placeholder = 'Type your message...'
}) => {
  const [message, setMessage] = useState('');

  const handleSend = () => {
    if (message.trim() && !loading) {
      onSend(message);
      setMessage('');
    }
  };

  const handleKeyPress = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const suggestions = [
    "Which projects are behind schedule?",
    "Show me healthcare sector performance",
    "What are the main risks?",
    "Analyze IT modernization progress"
  ];

  return (
    <div className="bg-white/10 backdrop-blur-lg p-4 border-t border-white/20">
      {/* Suggestion Buttons */}
      {message === '' && (
        <div className="flex gap-2 mb-3 overflow-x-auto">
          {suggestions.map((suggestion, idx) => (
            <button
              key={idx}
              onClick={() => setMessage(suggestion)}
              className="px-3 py-1 text-sm bg-white/20 hover:bg-white/30 text-white rounded-full whitespace-nowrap"
            >
              {suggestion}
            </button>
          ))}
        </div>
      )}

      {/* Input Field */}
      <div className="flex gap-2">
        <textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder={placeholder}
          disabled={loading}
          rows={1}
          className="flex-1 bg-white/20 text-white placeholder-white/50 rounded-lg px-4 py-3 resize-none focus:outline-none focus:ring-2 focus:ring-purple-500"
        />
        <button
          onClick={handleSend}
          disabled={loading || !message.trim()}
          className="px-6 py-3 bg-purple-600 hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-lg font-medium"
        >
          {loading ? '...' : 'Send'}
        </button>
      </div>
    </div>
  );
};
```

### ConversationSidebar Component

```typescript
// src/components/Chat/ConversationSidebar.tsx

import React from 'react';
import { Conversation } from '../../types/chat';

interface ConversationSidebarProps {
  conversations: Conversation[];
  currentConversation: number | null;
  onSelectConversation: (id: number) => void;
  onNewConversation: () => void;
}

export const ConversationSidebar: React.FC<ConversationSidebarProps> = ({
  conversations,
  currentConversation,
  onSelectConversation,
  onNewConversation
}) => {
  return (
    <div className="w-80 bg-black/30 backdrop-blur-lg border-r border-white/10 flex flex-col">
      {/* Header */}
      <div className="p-4 border-b border-white/10">
        <button
          onClick={onNewConversation}
          className="w-full px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-medium"
        >
          + New Conversation
        </button>
      </div>

      {/* Conversation List */}
      <div className="flex-1 overflow-y-auto p-2">
        {conversations.map(conv => (
          <button
            key={conv.id}
            onClick={() => onSelectConversation(conv.id)}
            className={`w-full text-left p-3 rounded-lg mb-2 transition ${
              currentConversation === conv.id
                ? 'bg-purple-600 text-white'
                : 'bg-white/5 hover:bg-white/10 text-white/80'
            }`}
          >
            <div className="font-medium truncate">{conv.title || 'Untitled'}</div>
            <div className="text-xs opacity-60 mt-1">
              {conv.message_count} messages • {new Date(conv.updated_at).toLocaleDateString()}
            </div>
          </button>
        ))}
      </div>
    </div>
  );
};
```

---

## MIGRATION FROM EXISTING UI

### Current UI (`index.html`) → New React App

**Step 1:** Keep existing `index.html` for backward compatibility  
**Step 2:** Create new React app at `/chat` route  
**Step 3:** Gradually migrate users to new UI  
**Step 4:** Deprecate old UI after testing

---

## TESTING

```typescript
// src/components/Chat/__tests__/ChatInterface.test.tsx

import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { ChatInterface } from '../ChatInterface';
import chatService from '../../../services/chatService';

jest.mock('../../../services/chatService');

test('sends message and displays response', async () => {
  const mockResponse = {
    conversation_id: 1,
    message_id: 2,
    response: 'Test response',
    artifacts: [],
    confidence: 'high',
    metadata: {}
  };

  (chatService.sendMessage as jest.Mock).mockResolvedValue(mockResponse);

  render(<ChatInterface />);

  const input = screen.getByPlaceholderText(/ask about/i);
  const sendButton = screen.getByText('Send');

  fireEvent.change(input, { target: { value: 'Test question' } });
  fireEvent.click(sendButton);

  await waitFor(() => {
    expect(screen.getByText('Test question')).toBeInTheDocument();
    expect(screen.getByText('Test response')).toBeInTheDocument();
  });
});
```

---

## CHECKLIST

- [ ] Create React components (ChatInterface, ChatMessage, ChatInput, ConversationSidebar)
- [ ] Implement chatService.ts API client
- [ ] Add TypeScript types
- [ ] Test multi-turn conversation UI
- [ ] Test conversation switching
- [ ] Test message history persistence
- [ ] Migrate from existing index.html

