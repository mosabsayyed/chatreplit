#!/usr/bin/env python3.11
"""
Script to create app-related tables in Supabase database using asyncpg
"""
import os
import asyncio
import asyncpg

# Get database connection details
DATABASE_URL = os.getenv('SUPABASE_CONN') or os.getenv('DATABASE_URL')

async def setup_tables():
    print(f"Connecting to Supabase database...")
    
    # Connect to database
    conn = await asyncpg.connect(DATABASE_URL)
    
    try:
        # Create users table
        print("Creating users table...")
        await conn.execute("""
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
        await conn.execute("""
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
        await conn.execute("""
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
        await conn.execute("""
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
        await conn.execute("CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id);")
        await conn.execute("CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);")
        
        # Insert default persona
        print("Inserting default transformation analyst persona...")
        await conn.execute("""
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
        
        print("✅ All app tables created successfully!")
        
        # Verify tables exist
        tables = await conn.fetch("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('users', 'personas', 'conversations', 'messages')
            ORDER BY table_name;
        """)
        print(f"\nVerified tables: {', '.join([t['table_name'] for t in tables])}")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise
    finally:
        await conn.close()
        print("\nDatabase connection closed.")

if __name__ == "__main__":
    asyncio.run(setup_tables())
