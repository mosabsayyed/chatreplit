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
        from .schema_loader import SchemaLoader
        self.schema_loader = SchemaLoader()
    
    def get_db_connection(self):
        """Get database connection"""
        conn = psycopg2.connect(os.environ.get("DATABASE_URL"))
        register_vector(conn)
        return conn
    
    def load_schema_definition(self) -> Dict[str, Any]:
        """Load schema definition using SchemaLoader"""
        return self.schema_loader.load_schema()
    
    def extract_schema_descriptions(self) -> List[Dict[str, Any]]:
        """
        Extract all tables and their descriptions for embedding
        
        Returns:
            List of dicts with table_name, description, metadata
        """
        schema_def = self.load_schema_definition()
        descriptions = []
        
        # Process all tables from schema loader
        for table_name, table_info in schema_def.items():
            columns = table_info.get("columns", [])
            primary_key = table_info.get("primary_key", [])
            
            # Get column names
            column_names = [col["name"] for col in columns]
            
            # Determine table type
            if table_name.startswith("ent_"):
                table_type = "entity_table"
                domain = "enterprise"
            elif table_name.startswith("sec_"):
                table_type = "entity_table"
                domain = "sector"
            elif table_name.startswith("jt_"):
                table_type = "join_table"
                domain = "relationship"
            elif table_name.startswith("kg_"):
                table_type = "knowledge_graph"
                domain = "graph"
            else:
                table_type = "support_table"
                domain = "system"
            
            # Build description
            desc_parts = [
                f"Table: {table_name}",
                f"Type: {table_type}",
                f"Primary Key: {', '.join(primary_key)}",
                f"Columns: {', '.join(column_names)}"
            ]
            
            descriptions.append({
                "table_name": table_name,
                "description": " | ".join(desc_parts),
                "metadata": {
                    "type": table_type,
                    "domain": domain,
                    "columns": column_names,
                    "primary_key": primary_key,
                    "has_composite_key": len(primary_key) > 1
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
