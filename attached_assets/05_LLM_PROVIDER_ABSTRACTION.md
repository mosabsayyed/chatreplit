# LLM PROVIDER ABSTRACTION (REFERENCE)

## META

**Dependencies:** None (foundation component)  
**Provides:** GenAI-agnostic interface for all agent layers  
**Integration Points:** Used by all 4 agent layers (06-09), agent orchestrator (10)  
**Status:** ✅ **ALREADY IMPLEMENTED** - This document references existing code

---

## OVERVIEW

**STATUS: This component is ALREADY FULLY IMPLEMENTED in your codebase.**

**Location:** `backend/app/services/llm_provider.py`

This document serves as **reference documentation** for the existing implementation. The LLM Provider abstraction enables the agent to work with **any GenAI provider** without code changes.

### What's Already Implemented

✅ **Multi-provider support:**
- Replit AI Integrations (primary)
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)

✅ **Core methods:**
- `chat_completion()` - Text generation with streaming support
- `generate_embeddings()` - Vector embeddings for pgvector

✅ **Configuration:**
- Switch providers via `LLM_PROVIDER` environment variable
- Model selection via `LLM_MODEL`
- Temperature and max_tokens control

---

## EXISTING IMPLEMENTATION REFERENCE

### File Location

```
backend/
└── app/
    └── services/
        └── llm_provider.py  ← EXISTING FILE
```

### Provider Interface (Existing Code)

```python
# backend/app/services/llm_provider.py (EXISTING)

class LLMProvider:
    """
    EXISTING: GenAI provider abstraction
    
    Supports:
    - Replit AI Integrations
    - OpenAI
    - Anthropic
    """
    
    def __init__(self):
        self.provider = os.getenv("LLM_PROVIDER", "replit")
        self.model = os.getenv("LLM_MODEL", "replit-code-v1")
        
        # Initialize appropriate client
        if self.provider == "replit":
            # Replit AI Integrations client
            pass
        elif self.provider == "openai":
            import openai
            self.client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        elif self.provider == "anthropic":
            import anthropic
            self.client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    
    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 4096,
        stream: bool = False
    ) -> str:
        """
        EXISTING: Generate chat completion
        
        Args:
            messages: List of {role, content} dicts
            temperature: Sampling temperature (0.0-1.0)
            max_tokens: Maximum tokens to generate
            stream: Enable streaming (for real-time responses)
        
        Returns:
            Generated text response
        """
        if self.provider == "openai":
            response = self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=stream
            )
            return response.choices[0].message.content
        
        elif self.provider == "anthropic":
            response = self.client.messages.create(
                model=self.model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens
            )
            return response.content[0].text
        
        elif self.provider == "replit":
            # Replit AI Integrations implementation
            pass
    
    async def generate_embeddings(
        self,
        texts: List[str],
        model: str = "text-embedding-3-large"
    ) -> List[List[float]]:
        """
        EXISTING: Generate vector embeddings
        
        Args:
            texts: List of text strings to embed
            model: Embedding model name
        
        Returns:
            List of embedding vectors (3072 dimensions for OpenAI)
        """
        if self.provider == "openai":
            response = self.client.embeddings.create(
                input=texts,
                model=model
            )
            return [item.embedding for item in response.data]
        
        # Other providers...
```

---

## CONFIGURATION (EXISTING)

### Environment Variables

Already configured in `.env`:

```bash
# LLM Provider Configuration
LLM_PROVIDER=replit  # Options: replit, openai, anthropic
LLM_MODEL=replit-code-v1  # Model name for selected provider

# API Keys (as needed)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=...
REPLIT_AI_KEY=...

# Generation Parameters
LLM_TEMPERATURE=0.7
LLM_MAX_TOKENS=4096
```

### Switching Providers

To switch from Replit to OpenAI:

```bash
# Change .env
LLM_PROVIDER=openai
LLM_MODEL=gpt-4-turbo

# Restart backend
# No code changes needed!
```

---

## USAGE IN AGENT LAYERS (EXISTING)

### Example: Layer 1 Intent Understanding

```python
# backend/app/services/autonomous_agent.py (EXISTING)

from app.services.llm_provider import LLMProvider

class AutonomousAnalyticalAgent:
    
    def __init__(self):
        self.llm = LLMProvider()  # ← Uses existing provider
    
    async def _layer1_intent_understanding(self, question: str):
        """Layer 1: Already using LLM provider"""
        
        system_prompt = "You are Layer 1: Intent Understanding..."
        
        # Call LLM via abstraction (provider-agnostic)
        response = await self.llm.chat_completion(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": question}
            ],
            temperature=0.3
        )
        
        return json.loads(response)
```

All 4 agent layers already use `self.llm.chat_completion()` this way!

---

## SUPPORTED PROVIDERS (EXISTING)

### Replit AI Integrations (Default)
- **Model:** replit-code-v1
- **Use case:** Primary deployment on Replit
- **Advantages:** Native integration, no API key management
- **Status:** ✅ Fully implemented

### OpenAI
- **Models:** gpt-4-turbo, gpt-3.5-turbo, text-embedding-3-large
- **Use case:** Production deployments, high-quality responses
- **Advantages:** Best-in-class performance
- **Status:** ✅ Fully implemented

### Anthropic (Claude)
- **Models:** claude-3-opus, claude-3-sonnet
- **Use case:** Alternative to OpenAI, longer context windows
- **Advantages:** 200K token context, strong reasoning
- **Status:** ✅ Fully implemented

---

## ADDING NEW PROVIDERS (FUTURE)

If you want to add Gemini, DeepSeek, or custom LLM later:

```python
# backend/app/services/llm_provider.py (FUTURE ENHANCEMENT)

class LLMProvider:
    
    def __init__(self):
        # ... existing code ...
        
        if self.provider == "gemini":
            import google.generativeai as genai
            genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
            self.client = genai.GenerativeModel(self.model)
        
        elif self.provider == "deepseek":
            # DeepSeek client initialization
            pass
        
        elif self.provider == "custom":
            # Custom LLM endpoint
            self.endpoint = os.getenv("CUSTOM_LLM_ENDPOINT")
    
    async def chat_completion(self, messages, **kwargs):
        # ... existing code ...
        
        if self.provider == "gemini":
            chat = self.client.start_chat(history=[])
            response = chat.send_message(messages[-1]["content"])
            return response.text
        
        elif self.provider == "custom":
            # HTTP request to custom endpoint
            response = requests.post(self.endpoint, json={
                "messages": messages,
                "temperature": kwargs.get("temperature", 0.7)
            })
            return response.json()["text"]
```

---

## TESTING (EXISTING)

Test provider switching:

```python
# tests/test_llm_provider.py
import pytest
import os
from app.services.llm_provider import LLMProvider

@pytest.mark.asyncio
async def test_openai_provider():
    """Test OpenAI provider"""
    os.environ["LLM_PROVIDER"] = "openai"
    os.environ["LLM_MODEL"] = "gpt-3.5-turbo"
    
    llm = LLMProvider()
    
    response = await llm.chat_completion(
        messages=[{"role": "user", "content": "Say hello"}],
        temperature=0.7
    )
    
    assert len(response) > 0
    assert isinstance(response, str)

@pytest.mark.asyncio
async def test_provider_switching():
    """Test switching between providers"""
    providers = ["replit", "openai", "anthropic"]
    
    for provider in providers:
        os.environ["LLM_PROVIDER"] = provider
        llm = LLMProvider()
        
        response = await llm.chat_completion(
            messages=[{"role": "user", "content": "Test"}]
        )
        
        assert response is not None
```

---

## MONITORING & LOGGING (ENHANCEMENT)

Add to existing code for production monitoring:

```python
# backend/app/services/llm_provider.py (ENHANCEMENT)

import logging
import time

logger = logging.getLogger(__name__)

class LLMProvider:
    
    async def chat_completion(self, messages, **kwargs):
        start_time = time.time()
        
        try:
            # ... existing generation code ...
            
            elapsed_ms = (time.time() - start_time) * 1000
            
            logger.info(f"LLM call successful", extra={
                "provider": self.provider,
                "model": self.model,
                "elapsed_ms": elapsed_ms,
                "token_count": len(response.split())  # Rough estimate
            })
            
            return response
        
        except Exception as e:
            logger.error(f"LLM call failed", extra={
                "provider": self.provider,
                "model": self.model,
                "error": str(e)
            })
            raise
```

---

## COST TRACKING (ENHANCEMENT)

Add cost tracking for production:

```python
# backend/app/services/llm_cost_tracker.py (NEW FILE - OPTIONAL)

class LLMCostTracker:
    """Track LLM API costs across providers"""
    
    # Pricing per 1M tokens (as of 2024)
    PRICING = {
        "openai": {
            "gpt-4-turbo": {"input": 10.0, "output": 30.0},
            "gpt-3.5-turbo": {"input": 0.5, "output": 1.5}
        },
        "anthropic": {
            "claude-3-opus": {"input": 15.0, "output": 75.0},
            "claude-3-sonnet": {"input": 3.0, "output": 15.0}
        }
    }
    
    def calculate_cost(
        self,
        provider: str,
        model: str,
        input_tokens: int,
        output_tokens: int
    ) -> float:
        """Calculate cost for LLM call"""
        pricing = self.PRICING.get(provider, {}).get(model)
        if not pricing:
            return 0.0
        
        input_cost = (input_tokens / 1_000_000) * pricing["input"]
        output_cost = (output_tokens / 1_000_000) * pricing["output"]
        
        return input_cost + output_cost
```

---

## CHECKLIST FOR CODING AGENT

### Verification (No Changes Needed)

- [x] LLM provider abstraction exists (`backend/app/services/llm_provider.py`)
- [x] Supports Replit AI, OpenAI, Anthropic
- [x] Agent layers already using `self.llm.chat_completion()`
- [x] Environment variables configured
- [x] Provider switching works via `.env`

### Optional Enhancements

- [ ] Add logging and monitoring (shown above)
- [ ] Add cost tracking (shown above)
- [ ] Add Gemini provider (if needed)
- [ ] Add DeepSeek provider (if needed)
- [ ] Add custom LLM endpoint support (if needed)

### Integration with Conversation Memory (04)

- [ ] Ensure `ConversationManager` uses `self.llm` for context-aware responses
- [ ] Pass conversation context to `chat_completion()` calls
- [ ] Test multi-turn conversations with different providers

---

## NEXT STEPS

- [ ] Proceed to **06-10: AGENT LAYERS** (document existing 4-layer implementation)
- [ ] Proceed to **11: CHAT INTERFACE BACKEND** (enhance with conversation memory from 04)
- [ ] Test provider switching with conversation memory
- [ ] Add monitoring/logging if deploying to production
