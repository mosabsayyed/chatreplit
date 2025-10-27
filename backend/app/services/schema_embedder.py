"""
Schema Embedder Service
Extracts schema information and generates embeddings for semantic search
"""
import json
import psycopg2
from typing import List, Dict, Any
from pgvector.psycopg2 import register_vector
from .embedding_service import get_embedding_service
import os

class SchemaEmbedder:
    """Service to embed database schema for semantic search"""
    
    def __init__(self):
        self.embedding_service = get_embedding_service()
        self.schema_path = "backend/app/config/schema_definition.json"
    
    def get_db_connection(self):
        """Get database connection"""
        conn = psycopg2.connect(os.environ.get("DATABASE_URL"))
        register_vector(conn)
        return conn
    
    def load_schema_definition(self) -> Dict[str, Any]:
        """Load schema definition from JSON file"""
        with open(self.schema_path, 'r') as f:
            return json.load(f)
    
    def extract_schema_descriptions(self) -> List[Dict[str, Any]]:
        """
        Extract all tables and their descriptions for embedding
        
        Returns:
            List of dicts with table_name, description, metadata
        """
        schema_def = self.load_schema_definition()
        descriptions = []
        
        # Extract entity tables
        for table_name, table_info in schema_def.get("entity_tables", {}).items():
            desc_parts = [
                f"Table: {table_name}",
                f"Description: {table_info.get('description', '')}",
                f"Columns: {', '.join(table_info.get('columns', []))}",
                f"Domain: {table_info.get('domain', '')}"
            ]
            
            descriptions.append({
                "table_name": table_name,
                "description": " | ".join(desc_parts),
                "metadata": {
                    "type": "entity_table",
                    "domain": table_info.get("domain"),
                    "columns": table_info.get("columns", []),
                    "has_composite_key": True
                }
            })
        
        # Extract join tables
        for table_name, table_info in schema_def.get("join_tables", {}).items():
            desc_parts = [
                f"Join Table: {table_name}",
                f"Connects: {table_info.get('description', '')}",
                f"Columns: {', '.join(table_info.get('columns', []))}"
            ]
            
            descriptions.append({
                "table_name": table_name,
                "description": " | ".join(desc_parts),
                "metadata": {
                    "type": "join_table",
                    "columns": table_info.get("columns", []),
                    "connects": table_info.get("connects", [])
                }
            })
        
        # Extract worldview chains
        for chain in schema_def.get("worldview", {}).get("relationship_chains", []):
            desc_parts = [
                f"Relationship Chain: {chain.get('chain_id')}",
                f"Path: {' -> '.join(chain.get('path', []))}",
                f"Use Case: {chain.get('description', '')}",
                f"Hops: {chain.get('hops', 0)}"
            ]
            
            descriptions.append({
                "table_name": f"chain_{chain.get('chain_id')}",
                "description": " | ".join(desc_parts),
                "metadata": {
                    "type": "relationship_chain",
                    "chain_id": chain.get("chain_id"),
                    "path": chain.get("path", []),
                    "hops": chain.get("hops", 0),
                    "source": chain.get("source"),
                    "target": chain.get("target")
                }
            })
        
        return descriptions
    
    def populate_schema_embeddings(self) -> int:
        """
        Generate embeddings for all schema elements and insert into database
        
        Returns:
            Number of embeddings created
        """
        conn = self.get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Clear existing schema embeddings
            cursor.execute("DELETE FROM schema_embeddings")
            
            # Extract schema descriptions
            schema_items = self.extract_schema_descriptions()
            print(f"Extracted {len(schema_items)} schema items")
            
            # Generate embeddings in batch
            texts = [item["description"] for item in schema_items]
            embeddings = self.embedding_service.generate_embeddings_batch(texts, batch_size=50)
            
            # Insert into database
            inserted_count = 0
            for item, embedding in zip(schema_items, embeddings):
                if embedding is not None:
                    cursor.execute(
                        """
                        INSERT INTO schema_embeddings (table_name, description, metadata, embedding)
                        VALUES (%s, %s, %s, %s)
                        """,
                        (
                            item["table_name"],
                            item["description"],
                            json.dumps(item["metadata"]),
                            embedding
                        )
                    )
                    inserted_count += 1
            
            conn.commit()
            print(f"Inserted {inserted_count} schema embeddings")
            return inserted_count
            
        except Exception as e:
            conn.rollback()
            print(f"Error populating schema embeddings: {e}")
            raise
        finally:
            cursor.close()
            conn.close()
    
    def search_schema(self, query: str, top_k: int = 5) -> List[Dict[str, Any]]:
        """
        Semantic search for relevant schema elements
        
        Args:
            query: Natural language query
            top_k: Number of results to return
            
        Returns:
            List of matching schema items with similarity scores
        """
        conn = self.get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Generate query embedding
            query_embedding = self.embedding_service.generate_embedding(query)
            if query_embedding is None:
                return []
            
            # Perform similarity search using cosine distance
            cursor.execute(
                """
                SELECT 
                    table_name,
                    description,
                    metadata,
                    1 - (embedding <=> %s::vector) AS similarity
                FROM schema_embeddings
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (query_embedding, query_embedding, top_k)
            )
            
            results = []
            for row in cursor.fetchall():
                results.append({
                    "table_name": row[0],
                    "description": row[1],
                    "metadata": json.loads(row[2]) if row[2] else {},
                    "similarity": float(row[3])
                })
            
            return results
            
        except Exception as e:
            print(f"Error searching schema: {e}")
            return []
        finally:
            cursor.close()
            conn.close()


# Singleton instance
_schema_embedder = None

def get_schema_embedder() -> SchemaEmbedder:
    """Get or create singleton schema embedder instance"""
    global _schema_embedder
    if _schema_embedder is None:
        _schema_embedder = SchemaEmbedder()
    return _schema_embedder
