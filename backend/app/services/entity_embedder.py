"""
Entity Embedder Service
Extracts entities from database and generates embeddings for semantic search
"""
import json
import psycopg2
from typing import List, Dict, Any, Optional
from pgvector.psycopg2 import register_vector
from .embedding_service import get_embedding_service
import os

class EntityEmbedder:
    """Service to embed database entities for semantic search"""
    
    def __init__(self):
        self.embedding_service = get_embedding_service()
        
        # Entity tables to embed (with their description columns)
        self.entity_tables = {
            "ent_projects": {
                "name_col": "name",
                "desc_col": "description",
                "type": "project"
            },
            "ent_capabilities": {
                "name_col": "name",
                "desc_col": "description",
                "type": "capability"
            },
            "sec_objectives": {
                "name_col": "name",
                "desc_col": "description",
                "type": "objective"
            },
            "sec_risks": {
                "name_col": "name",
                "desc_col": "description",
                "type": "risk"
            },
            "str_strategies": {
                "name_col": "name",
                "desc_col": "description",
                "type": "strategy"
            },
            "tac_tactics": {
                "name_col": "name",
                "desc_col": "description",
                "type": "tactic"
            },
            "ent_it_systems": {
                "name_col": "name",
                "desc_col": "description",
                "type": "it_system"
            },
            "ent_entities": {
                "name_col": "name",
                "desc_col": "description",
                "type": "entity"
            }
        }
    
    def get_db_connection(self):
        """Get database connection"""
        conn = psycopg2.connect(os.environ.get("DATABASE_URL"))
        register_vector(conn)
        return conn
    
    def extract_entities_from_table(self, table_name: str, table_config: Dict[str, str]) -> List[Dict[str, Any]]:
        """
        Extract entities from a single table
        
        Args:
            table_name: Name of the table
            table_config: Configuration with name_col, desc_col, type
            
        Returns:
            List of entity dicts
        """
        conn = self.get_db_connection()
        cursor = conn.cursor()
        
        try:
            name_col = table_config["name_col"]
            desc_col = table_config["desc_col"]
            entity_type = table_config["type"]
            
            # Query to get all entities with id, year, name, description
            query = f"""
                SELECT id, year, {name_col}, COALESCE({desc_col}, '') as description
                FROM {table_name}
                ORDER BY year DESC, id
            """
            
            cursor.execute(query)
            entities = []
            
            for row in cursor.fetchall():
                entity_id, year, name, description = row
                
                # Combine name and description for better semantic search
                text_for_embedding = f"{name}"
                if description and description.strip():
                    text_for_embedding += f" - {description}"
                
                entities.append({
                    "entity_type": entity_type,
                    "entity_id": entity_id,
                    "entity_year": year,
                    "name": name,
                    "description": description,
                    "text": text_for_embedding,
                    "table_name": table_name
                })
            
            return entities
            
        except Exception as e:
            print(f"Error extracting entities from {table_name}: {e}")
            return []
        finally:
            cursor.close()
            conn.close()
    
    def populate_entity_embeddings(self, batch_size: int = 100) -> int:
        """
        Generate embeddings for all entities and insert into database
        
        Args:
            batch_size: Number of entities to process per batch
            
        Returns:
            Number of embeddings created
        """
        conn = self.get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Clear existing entity embeddings
            cursor.execute("DELETE FROM entity_embeddings")
            print("Cleared existing entity embeddings")
            
            total_inserted = 0
            
            # Process each entity table
            for table_name, table_config in self.entity_tables.items():
                print(f"\nProcessing table: {table_name}")
                
                # Extract entities
                entities = self.extract_entities_from_table(table_name, table_config)
                print(f"  Found {len(entities)} entities")
                
                if not entities:
                    continue
                
                # Process in batches
                for i in range(0, len(entities), batch_size):
                    batch = entities[i:i + batch_size]
                    texts = [e["text"] for e in batch]
                    
                    # Generate embeddings
                    embeddings = self.embedding_service.generate_embeddings_batch(texts, batch_size=50)
                    
                    # Insert into database
                    for entity, embedding in zip(batch, embeddings):
                        if embedding is not None:
                            cursor.execute(
                                """
                                INSERT INTO entity_embeddings 
                                (entity_type, entity_id, entity_year, name, description, metadata, embedding)
                                VALUES (%s, %s, %s, %s, %s, %s, %s)
                                ON CONFLICT (entity_type, entity_id, entity_year) 
                                DO UPDATE SET
                                    name = EXCLUDED.name,
                                    description = EXCLUDED.description,
                                    embedding = EXCLUDED.embedding
                                """,
                                (
                                    entity["entity_type"],
                                    entity["entity_id"],
                                    entity["entity_year"],
                                    entity["name"],
                                    entity["description"],
                                    json.dumps({"table_name": entity["table_name"]}),
                                    embedding
                                )
                            )
                            total_inserted += 1
                    
                    conn.commit()
                    print(f"  Inserted batch {i//batch_size + 1} ({len(batch)} entities)")
            
            print(f"\nTotal embeddings inserted: {total_inserted}")
            return total_inserted
            
        except Exception as e:
            conn.rollback()
            print(f"Error populating entity embeddings: {e}")
            raise
        finally:
            cursor.close()
            conn.close()
    
    def search_entities(
        self, 
        query: str, 
        entity_type: Optional[str] = None,
        top_k: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Semantic search for entities
        
        Args:
            query: Natural language query
            entity_type: Optional filter by entity type (project, capability, etc.)
            top_k: Number of results to return
            
        Returns:
            List of matching entities with similarity scores
        """
        conn = self.get_db_connection()
        cursor = conn.cursor()
        
        try:
            # Generate query embedding
            query_embedding = self.embedding_service.generate_embedding(query)
            if query_embedding is None:
                return []
            
            # Build query with optional entity type filter
            if entity_type:
                sql = """
                    SELECT 
                        entity_type,
                        entity_id,
                        entity_year,
                        name,
                        description,
                        metadata,
                        1 - (embedding <=> %s::vector) AS similarity
                    FROM entity_embeddings
                    WHERE entity_type = %s
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                """
                params = (query_embedding, entity_type, query_embedding, top_k)
            else:
                sql = """
                    SELECT 
                        entity_type,
                        entity_id,
                        entity_year,
                        name,
                        description,
                        metadata,
                        1 - (embedding <=> %s::vector) AS similarity
                    FROM entity_embeddings
                    ORDER BY embedding <=> %s::vector
                    LIMIT %s
                """
                params = (query_embedding, query_embedding, top_k)
            
            cursor.execute(sql, params)
            
            results = []
            for row in cursor.fetchall():
                results.append({
                    "entity_type": row[0],
                    "entity_id": row[1],
                    "entity_year": row[2],
                    "name": row[3],
                    "description": row[4],
                    "metadata": json.loads(row[5]) if row[5] else {},
                    "similarity": float(row[6])
                })
            
            return results
            
        except Exception as e:
            print(f"Error searching entities: {e}")
            return []
        finally:
            cursor.close()
            conn.close()


# Singleton instance
_entity_embedder = None

def get_entity_embedder() -> EntityEmbedder:
    """Get or create singleton entity embedder instance"""
    global _entity_embedder
    if _entity_embedder is None:
        _entity_embedder = EntityEmbedder()
    return _entity_embedder
