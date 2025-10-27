"""
CLI Script to populate vector embeddings for schema and entities
Run this after database setup to enable semantic search
"""
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.schema_embedder import get_schema_embedder
from app.services.entity_embedder import get_entity_embedder

def main():
    print("=" * 60)
    print("JOSOOR Embedding Population Script")
    print("=" * 60)
    
    # Populate schema embeddings
    print("\n[1/2] Populating Schema Embeddings...")
    print("-" * 60)
    try:
        schema_embedder = get_schema_embedder()
        count = schema_embedder.populate_schema_embeddings()
        print(f"✅ Schema embeddings complete: {count} items")
    except Exception as e:
        print(f"❌ Error populating schema embeddings: {e}")
        return 1
    
    # Populate entity embeddings
    print("\n[2/2] Populating Entity Embeddings...")
    print("-" * 60)
    try:
        entity_embedder = get_entity_embedder()
        count = entity_embedder.populate_entity_embeddings()
        print(f"✅ Entity embeddings complete: {count} items")
    except Exception as e:
        print(f"❌ Error populating entity embeddings: {e}")
        return 1
    
    print("\n" + "=" * 60)
    print("✅ All embeddings populated successfully!")
    print("=" * 60)
    return 0

if __name__ == "__main__":
    sys.exit(main())
