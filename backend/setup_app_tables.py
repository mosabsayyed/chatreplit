#!/usr/bin/env python3.11
"""
Script to create app-related tables in Supabase database
"""
import os
import psycopg2

# Get database connection string
DATABASE_URL = os.getenv('SUPABASE_CONN') or os.getenv('DATABASE_URL')

print(f"Connecting to Supabase database...")

# Connect to database
conn = psycopg2.connect(DATABASE_URL)
cur = conn.cursor()

try:
    # Create users table
    print("Creating users table...")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email VARCHAR(255) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            full_name VARCHAR(255),
            role VARCHAR(50) DEFAULT 'user',
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        );
    """)
    
    # Create personas table
    print("Creating personas table...")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS personas (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) UNIQUE NOT NULL,
            display_name VARCHAR(255) NOT NULL,
            description TEXT,
            system_prompt TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        );
    """)
    
    # Create conversations table
    print("Creating conversations table...")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS conversations (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            persona_id INTEGER NOT NULL REFERENCES personas(id) ON DELETE RESTRICT,
            title VARCHAR(255),
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW()
        );
    """)
    
    # Create messages table
    print("Creating messages table...")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id SERIAL PRIMARY KEY,
            conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
            role VARCHAR(20) NOT NULL,
            content TEXT NOT NULL,
            artifact_ids INTEGER[],
            extra_metadata JSONB,
            created_at TIMESTAMP DEFAULT NOW()
        );
    """)
    
    # Create indexes
    print("Creating indexes...")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);")
    
    # Insert default persona
    print("Inserting default transformation analyst persona...")
    cur.execute("""
        INSERT INTO personas (name, display_name, description, system_prompt, is_active)
        VALUES (
            'transformation_analyst',
            'Transformation Analyst',
            'Expert AI assistant for enterprise transformation analytics and insights',
            'You are an expert transformation analyst for JOSOOR - a platform for enterprise transformation analytics. You help users understand their transformation data, analyze capabilities, projects, IT systems, and provide strategic insights. Be helpful, analytical, and provide data-driven recommendations.',
            TRUE
        )
        ON CONFLICT (name) DO NOTHING;
    """)
    
    # Commit changes
    conn.commit()
    print("✅ All app tables created successfully!")
    
    # Verify tables exist
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN ('users', 'personas', 'conversations', 'messages')
        ORDER BY table_name;
    """)
    tables = cur.fetchall()
    print(f"\nVerified tables: {', '.join([t[0] for t in tables])}")
    
except Exception as e:
    conn.rollback()
    print(f"❌ Error: {e}")
    raise
finally:
    cur.close()
    conn.close()
    print("\nDatabase connection closed.")
