import asyncpg
from typing import List, Dict, Any, Optional
from app.config import settings

class PostgresClient:
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None
    
    async def connect(self):
        """Create database connection pool"""
        if not self.pool:
            self.pool = await asyncpg.create_pool(
                host=settings.PGHOST,
                port=settings.PGPORT,
                user=settings.PGUSER,
                password=settings.PGPASSWORD,
                database=settings.PGDATABASE,
                min_size=5,
                max_size=20
            )
    
    async def disconnect(self):
        """Close database connection pool"""
        if self.pool:
            await self.pool.close()
            self.pool = None
    
    async def execute_query(self, query: str, params: List[Any] = None) -> List[Dict[str, Any]]:
        """Execute a SELECT query and return results as list of dicts"""
        if not self.pool:
            await self.connect()
        
        async with self.pool.acquire() as conn:
            if params:
                rows = await conn.fetch(query, *params)
            else:
                rows = await conn.fetch(query)
            
            return [dict(row) for row in rows]
    
    async def execute_mutation(self, query: str, params: List[Any] = None) -> str:
        """Execute INSERT/UPDATE/DELETE and return status"""
        if not self.pool:
            await self.connect()
        
        async with self.pool.acquire() as conn:
            if params:
                result = await conn.execute(query, *params)
            else:
                result = await conn.execute(query)
            return result
    
    async def execute_many(self, query: str, params_list: List[List[Any]]) -> int:
        """Execute many statements in batch"""
        if not self.pool:
            await self.connect()
        
        async with self.pool.acquire() as conn:
            async with conn.transaction():
                result = await conn.executemany(query, params_list)
                return len(params_list)
    
    async def query_knowledge_graph(
        self, 
        entity_types: Optional[List[str]] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Query knowledge graph nodes by type"""
        if not self.pool:
            await self.connect()
        
        if entity_types:
            query = f"""
                SELECT id, type, props, valid_from, valid_to
                FROM kg_nodes
                WHERE type = ANY($1::text[])
                ORDER BY valid_from DESC
                LIMIT {limit}
            """
            return await self.execute_query(query, [entity_types])
        else:
            query = f"""
                SELECT id, type, props, valid_from, valid_to
                FROM kg_nodes
                ORDER BY valid_from DESC
                LIMIT {limit}
            """
            return await self.execute_query(query)
    
    async def query_knowledge_graph_relationships(
        self,
        node_id: Optional[str] = None,
        rel_types: Optional[List[str]] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Query knowledge graph edges/relationships"""
        if not self.pool:
            await self.connect()
        
        conditions = []
        params = []
        param_idx = 1
        
        if node_id:
            conditions.append(f"(src_id::text = ${param_idx} OR dst_id::text = ${param_idx})")
            params.append(node_id)
            param_idx += 1
        
        if rel_types:
            placeholders = ','.join([f'${i+param_idx}' for i in range(len(rel_types))])
            conditions.append(f"rel_type = ANY(ARRAY[{placeholders}])")
            params.extend(rel_types)
        
        where_clause = " AND ".join(conditions) if conditions else "TRUE"
        
        query = f"""
            SELECT e.id, e.src_id, e.rel_type, e.dst_id, e.props,
                   n1.type as src_type, n1.props as src_props,
                   n2.type as dst_type, n2.props as dst_props
            FROM kg_edges e
            LEFT JOIN kg_nodes n1 ON e.src_id = n1.id
            LEFT JOIN kg_nodes n2 ON e.dst_id = n2.id
            WHERE {where_clause}
            ORDER BY e.valid_from DESC
            LIMIT {limit}
        """
        
        return await self.execute_query(query, params if params else None)
    
    async def vector_similarity_search(
        self,
        query_embedding: List[float],
        limit: int = 10,
        similarity_threshold: float = 0.7
    ) -> List[Dict[str, Any]]:
        """Perform vector similarity search using pgvector"""
        if not self.pool:
            await self.connect()
        
        query = """
            SELECT 
                vc.id,
                vc.node_id,
                vc.text,
                vc.meta,
                1 - (vc.embedding <=> $1::vector) as similarity,
                n.type as node_type,
                n.props as node_props
            FROM vec_chunks vc
            LEFT JOIN kg_nodes n ON vc.node_id = n.id
            WHERE 1 - (vc.embedding <=> $1::vector) > $2
            ORDER BY vc.embedding <=> $1::vector
            LIMIT $3
        """
        
        embedding_str = f"[{','.join(map(str, query_embedding))}]"
        return await self.execute_query(query, [embedding_str, similarity_threshold, limit])

# Global instance
postgres_client = PostgresClient()
