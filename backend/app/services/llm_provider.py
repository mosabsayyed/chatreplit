from typing import List, Dict, Any, Optional, Union
from openai import OpenAI
import os
import json
from app.config import settings

try:
    from anthropic import Anthropic
except ImportError:
    Anthropic = None

class LLMProvider:
    """Switchable LLM provider supporting Replit AI Integrations, OpenAI, and Anthropic"""
    
    def __init__(self):
        self.provider = settings.LLM_PROVIDER
        self.client: Optional[Union[OpenAI, Any]] = None
    
    def _get_client(self):
        """Lazy initialization of LLM client based on provider"""
        if self.client is None:
            if self.provider == "replit":
                api_key = os.getenv("AI_INTEGRATIONS_OPENAI_API_KEY", "_DUMMY_API_KEY_")
                base_url = os.getenv("AI_INTEGRATIONS_OPENAI_BASE_URL", "http://localhost:1106/modelfarm/openai")
                self.client = OpenAI(api_key=api_key, base_url=base_url)
            
            elif self.provider == "openai":
                api_key = os.getenv("OPENAI_API_KEY")
                if not api_key:
                    raise ValueError("OPENAI_API_KEY environment variable is required for OpenAI provider")
                base_url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
                self.client = OpenAI(api_key=api_key, base_url=base_url)
            
            elif self.provider == "anthropic":
                api_key = os.getenv("ANTHROPIC_API_KEY")
                if not api_key:
                    raise ValueError("ANTHROPIC_API_KEY environment variable is required for Anthropic provider")
                if Anthropic is None:
                    raise ImportError("anthropic package is not installed. Install with: pip install anthropic")
                self.client = Anthropic(api_key=api_key)
            
            else:
                raise ValueError(f"Unsupported LLM provider: {self.provider}. Supported: replit, openai, anthropic")
        
        return self.client
    
    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: str = "gpt-4o-mini",
        temperature: float = 0.7,
        max_tokens: int = 2000,
        debug: bool = False
    ) -> str:
        """Get chat completion from LLM"""
        
        # DEBUG: Log actual prompts if debug mode enabled
        if debug or os.getenv("DEBUG_PROMPTS", "false").lower() == "true":
            debug_log = {
                "provider": self.provider,
                "model": model,
                "temperature": temperature,
                "max_tokens": max_tokens,
                "messages": messages
            }
            print("\n" + "="*80)
            print("🔍 DEBUG: ACTUAL PROMPT SENT TO LLM")
            print("="*80)
            print(json.dumps(debug_log, indent=2))
            print("="*80 + "\n")
        
        try:
            client = self._get_client()
            
            if self.provider == "anthropic":
                system_msg = next((m["content"] for m in messages if m["role"] == "system"), "")
                user_messages = [{"role": m["role"], "content": m["content"]} 
                               for m in messages if m["role"] != "system"]
                
                response = client.messages.create(  # type: ignore
                    model=model if "claude" in model else "claude-3-5-sonnet-20241022",
                    max_tokens=max_tokens,
                    temperature=temperature,
                    system=system_msg,
                    messages=user_messages  # type: ignore
                )
                return str(response.content[0].text)
            
            else:
                response = client.chat.completions.create(
                    model=model,
                    messages=messages,  # type: ignore
                    temperature=temperature,
                    max_tokens=max_tokens
                )
                result = response.choices[0].message.content or ""
                
                # DEBUG: Log response
                if debug or os.getenv("DEBUG_PROMPTS", "false").lower() == "true":
                    print("\n" + "="*80)
                    print("📥 DEBUG: ACTUAL RESPONSE FROM LLM")
                    print("="*80)
                    print(result)
                    print("="*80 + "\n")
                
                return result
        
        except Exception as e:
            raise Exception(f"LLM API Error: {str(e)}")
    
    async def generate_embeddings(
        self,
        texts: List[str],
        model: str = "text-embedding-3-small"
    ) -> List[List[float]]:
        """Generate embeddings for text (not supported for Anthropic)"""
        if self.provider == "anthropic":
            raise NotImplementedError("Anthropic does not provide embedding models. Use OpenAI or Replit provider for embeddings.")
        
        try:
            client = self._get_client()
            response = client.embeddings.create(
                model=model,
                input=texts
            )
            return [item.embedding for item in response.data]
        except Exception as e:
            raise Exception(f"Embedding API Error: {str(e)}")

llm_provider = LLMProvider()
