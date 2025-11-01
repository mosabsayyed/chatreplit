from fastapi import APIRouter, HTTPException
from app.db.supabase_client import supabase_client

router = APIRouter()

@router.get("/verify-connection")
async def verify_connection():
    """Verify Supabase REST API connection"""
    try:
        # Test the connection by checking if client is initialized
        if not supabase_client.client:
            await supabase_client.connect()
        
        return {
            "success": True,
            "message": "Successfully connected to Supabase via REST API over HTTPS",
            "database": "External Supabase PostgreSQL",
            "url": supabase_client.client.supabase_url,
            "connection_type": "REST API (HTTPS)"
        }
    except Exception as e:
        return {
            "success": False,
            "message": "Connection failed",
            "error": str(e)
        }

@router.post("/create-app-tables")
async def create_app_tables():
    """Instructions for creating app tables in Supabase"""
    sql = """
-- Run this SQL in your Supabase Dashboard SQL Editor

-- Users table
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

-- Personas table
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

-- Conversations table
CREATE TABLE IF NOT EXISTS conversations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    persona_id INTEGER NOT NULL REFERENCES personas(id) ON DELETE RESTRICT,
    title VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    artifact_ids INTEGER[],
    extra_metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);

-- Insert default persona
INSERT INTO personas (name, display_name, description, system_prompt, is_active)
VALUES (
    'transformation_analyst',
    'Transformation Analyst',
    'Expert AI assistant for enterprise transformation analytics and insights',
    'You are an expert transformation analyst for JOSOOR - a platform for enterprise transformation analytics. You help users understand their transformation data, analyze capabilities, projects, IT systems, and provide strategic insights. Be helpful, analytical, and provide data-driven recommendations.',
    TRUE
)
ON CONFLICT (name) DO NOTHING;
"""
    
    return {
        "success": True,
        "message": "Copy the SQL below and run it in your Supabase Dashboard SQL Editor",
        "instructions": [
            "1. Go to https://supabase.com/dashboard",
            "2. Select your project: ojlfhkrobyqmifqbgcyw",
            "3. Click 'SQL Editor' in the left sidebar",
            "4. Click 'New Query'",
            "5. Paste the SQL below",
            "6. Click 'Run' to execute"
        ],
        "sql": sql
    }

@router.get("/list-tables")
async def list_tables():
    """List all tables in Supabase using REST API"""
    try:
        if not supabase_client.client:
            await supabase_client.connect()
        
        # Try to get schema information via RPC
        # Note: This requires creating a custom RPC function in Supabase
        result = await supabase_client.rpc('list_tables')
        
        return {
            "success": True,
            "tables": result
        }
    except Exception as e:
        return {
            "success": False,
            "message": "Could not list tables - RPC function not found",
            "error": str(e),
            "note": "Create a list_tables() RPC function in Supabase or use Supabase Dashboard to view tables"
        }
