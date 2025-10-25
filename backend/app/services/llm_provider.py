from typing import List, Dict, Any, Optional
from openai import OpenAI
import os
from app.config import settings

class LLMProvider:
    """Switchable LLM provider supporting Replit AI Integrations, OpenAI, and Anthropic"""
    
    def __init__(self):
        self.provider = settings.LLM_PROVIDER
        self.client = None
    
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
                try:
                    from anthropic import Anthropic
                    self.client = Anthropic(api_key=api_key)
                except ImportError:
                    raise ImportError("anthropic package is not installed. Install with: pip install anthropic")
            
            else:
                raise ValueError(f"Unsupported LLM provider: {self.provider}. Supported: replit, openai, anthropic")
        
        return self.client
    
    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: str = "gpt-4o-mini",
        temperature: float = 0.7,
        max_tokens: int = 2000
    ) -> str:
        """Get chat completion from LLM"""
        try:
            client = self._get_client()
            
            if self.provider == "anthropic":
                system_msg = next((m["content"] for m in messages if m["role"] == "system"), "")
                user_messages = [{"role": m["role"], "content": m["content"]} 
                               for m in messages if m["role"] != "system"]
                
                response = client.messages.create(
                    model=model if "claude" in model else "claude-3-5-sonnet-20241022",
                    max_tokens=max_tokens,
                    temperature=temperature,
                    system=system_msg,
                    messages=user_messages
                )
                return response.content[0].text
            
            else:
                response = client.chat.completions.create(
                    model=model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens
                )
                return response.choices[0].message.content
        
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
