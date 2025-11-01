"""
Embedding Generation Service for JOSOOR
Uses OpenAI text-embedding-ada-002 model to generate 1536-dimensional vectors
"""
import os
from typing import List, Optional
from openai import OpenAI
import asyncio
from functools import lru_cache

class EmbeddingService:
    """Service for generating OpenAI embeddings"""
    
    def __init__(self):
        # Use the same API key pattern as llm_provider.py
        # Supports Replit AI Integrations and standard OpenAI
        api_key = os.getenv("AI_INTEGRATIONS_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY", "_DUMMY_API_KEY_")
        base_url = os.getenv("AI_INTEGRATIONS_OPENAI_BASE_URL", "https://api.openai.com/v1")
        
        # Fix for httpx version compatibility - don't pass None values
        client_kwargs = {"api_key": api_key}
        if base_url:
            client_kwargs["base_url"] = base_url
        
        self.client = OpenAI(**client_kwargs)
        self.model = "text-embedding-ada-002"
        self.dimensions = 1536
    
    def generate_embedding(self, text: str) -> Optional[List[float]]:
        """
        Generate embedding for a single text string
        
        Args:
            text: Input text to embed
            
        Returns:
            List of 1536 floats representing the embedding, or None on error
        """
        if not text or not text.strip():
            return None
            
        try:
            # Replace newlines with spaces as recommended by OpenAI
            cleaned_text = text.replace("\n", " ").strip()
            
            response = self.client.embeddings.create(
                input=[cleaned_text],
                model=self.model
            )
            
            return response.data[0].embedding
            
        except Exception as e:
            print(f"Error generating embedding: {e}")
            return None
    
    def generate_embeddings_batch(self, texts: List[str], batch_size: int = 100) -> List[Optional[List[float]]]:
        """
        Generate embeddings for multiple texts in batches
        
        Args:
            texts: List of input texts
            batch_size: Number of texts to process per API call (max 2048 for OpenAI)
            
        Returns:
            List of embeddings (same order as input texts)
        """
        all_embeddings = []
        
        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]
            
            try:
                # Clean texts
                cleaned_batch = [text.replace("\n", " ").strip() for text in batch]
                
                response = self.client.embeddings.create(
                    input=cleaned_batch,
                    model=self.model
                )
                
                # Extract embeddings in order
                batch_embeddings = [item.embedding for item in response.data]
                all_embeddings.extend(batch_embeddings)
                
            except Exception as e:
                print(f"Error in batch {i//batch_size}: {e}")
                # Add None for failed batch
                all_embeddings.extend([None] * len(batch))
        
        return all_embeddings
    
    async def generate_embedding_async(self, text: str) -> Optional[List[float]]:
        """Async wrapper for embedding generation"""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.generate_embedding, text)


# Singleton instance
_embedding_service = None

def get_embedding_service() -> EmbeddingService:
    """Get or create the singleton embedding service instance"""
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service
