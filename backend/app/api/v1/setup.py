from fastapi import APIRouter, HTTPException
from app.db.postgres_client import postgres_client

router = APIRouter()

@router.post("/create-app-tables")
async def create_app_tables():
    """Create app-related tables (users, personas, conversations, messages)"""
    try:
        # Create users table
        await postgres_client.execute_mutation("""
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
        await postgres_client.execute_mutation("""
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
        await postgres_client.execute_mutation("""
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
        await postgres_client.execute_mutation("""
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
        await postgres_client.execute_mutation("CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id);")
        await postgres_client.execute_mutation("CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);")
        
        # Insert default persona
        await postgres_client.execute_mutation("""
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
        
        # Verify tables
        tables = await postgres_client.execute_query("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name IN ('users', 'personas', 'conversations', 'messages')
            ORDER BY table_name;
        """)
        
        return {
            "success": True,
            "message": "App tables created successfully",
            "tables": [t['table_name'] for t in tables]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
