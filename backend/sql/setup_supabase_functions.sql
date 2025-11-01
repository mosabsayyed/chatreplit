-- Supabase PostgreSQL Functions Setup
-- Run this SQL in your Supabase Dashboard SQL Editor to enable raw SQL execution via REST API

-- ===================================================================
-- Function: execute_sql
-- Purpose: Execute arbitrary SQL queries via Supabase RPC
-- Required for: Transformation analytics queries with pgvector
-- ===================================================================

CREATE OR REPLACE FUNCTION execute_sql(query_text text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER  -- Run with elevated privileges
AS $$
DECLARE
    result json;
BEGIN
    -- Execute the query and convert results to JSON
    EXECUTE 'SELECT json_agg(row_to_json(t)) FROM (' || query_text || ') t' INTO result;
    
    -- Return empty array if no results
    RETURN COALESCE(result, '[]'::json);
EXCEPTION
    WHEN OTHERS THEN
        -- Return error as JSON
        RETURN json_build_object(
            'error', SQLERRM,
            'detail', SQLSTATE
        );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION execute_sql(text) TO authenticated;
GRANT EXECUTE ON FUNCTION execute_sql(text) TO service_role;

-- ===================================================================
-- Optional: Add pgvector extension if not already enabled
-- Required for semantic search functionality
-- ===================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ===================================================================
-- Instructions:
-- 1. Go to https://supabase.com/dashboard
-- 2. Select your project: ojlfhkrobyqmifqbgcyw
-- 3. Click "SQL Editor" in left sidebar
-- 4. Click "New Query"
-- 5. Copy and paste this entire file
-- 6. Click "Run" to execute
-- ===================================================================
