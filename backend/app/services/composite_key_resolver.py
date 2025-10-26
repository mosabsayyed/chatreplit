"""
JOSOOR Optimization: Composite Key Reference Resolver
Version: 1.0
Purpose: Resolve conversational references to composite key tuples

This module addresses Layer 1 context engineering weakness by ensuring
references like "that project" are resolved to complete composite keys
(id, year) instead of text strings.
"""

from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from datetime import datetime
import re


@dataclass
class CompositeKeyEntity:
    """
    Represents a fully resolved entity with composite key.
    """
    entity_id: str
    entity_year: int
    entity_table: str
    entity_type: str
    display_name: str
    confidence: float = 1.0
    source_turn: Optional[int] = None
    additional_fields: Optional[Dict[str, Any]] = None


class CompositeKeyResolver:
    """
    Resolves conversational references to composite key structures.
    
    This is the critical fix for Layer 1 reference resolution failure.
    Instead of returning text strings, we extract complete composite keys
    from conversation history.
    
    Example:
        Turn 1: User asks "Show Project Atlas"
                System returns: {id: "PRJ001", year: 2024, name: "Project Atlas"}
        
        Turn 2: User asks "Show capabilities for that project"
                Resolver extracts: CompositeKeyEntity(
                    entity_id="PRJ001",
                    entity_year=2024,
                    entity_table="ent_projects",
                    entity_type="project",
                    display_name="Project Atlas"
                )
    """
    
    def __init__(self, conversation_manager: Any):
        """
        Initialize resolver with conversation manager.
        
        Args:
            conversation_manager: Instance of ConversationManager from 04B
        """
        self.conversation_manager = conversation_manager
        self.entity_cache: Dict[str, Dict[str, CompositeKeyEntity]] = {}
        
        # Reference keywords that trigger resolution
        self.reference_keywords = [
            'it', 'that', 'this', 'those', 'these',
            'the previous', 'the last', 'mentioned',
            'above', 'earlier', 'said', 'same'
        ]
        
        # Entity type mappings
        self.table_to_type = {
            'ent_entities': 'entity',
            'ent_projects': 'project',
            'ent_capabilities': 'capability',
            'ent_it_systems': 'it_system',
            'ent_processes': 'process',
            'sec_risks': 'risk',
            'sec_controls': 'control',
            'sec_issues': 'issue',
            'str_strategies': 'strategy',
            'tac_tactics': 'tactic'
        }
    
    def resolve_reference(
        self,
        reference_text: str,
        conversation_id: str,
        current_year: int = 2024,
        context_hint: Optional[str] = None
    ) -> Optional[CompositeKeyEntity]:
        """
        Resolve a textual reference to a composite key entity.
        
        Args:
            reference_text: The reference phrase (e.g., "that project", "it")
            conversation_id: Current conversation ID
            current_year: Default year if not found (default: 2024)
            context_hint: Optional hint about entity type expected
        
        Returns:
            CompositeKeyEntity if resolved, None if not found
        
        Example:
            >>> resolver.resolve_reference(
            ...     reference_text="that project",
            ...     conversation_id="conv_123"
            ... )
            CompositeKeyEntity(
                entity_id='PRJ001',
                entity_year=2024,
                entity_table='ent_projects',
                entity_type='project',
                display_name='Project Atlas'
            )
        """
        # Check cache first
        cache_key = f"{conversation_id}:{reference_text.lower()}"
        if cache_key in self.entity_cache.get(conversation_id, {}):
            return self.entity_cache[conversation_id][cache_key]
        
        # Get conversation history
        history = self.conversation_manager.get_history(
            conversation_id,
            limit=10
        )
        
        # Search history for matching entity
        for turn in reversed(history):
            if turn.role == "assistant" and turn.data_returned:
                # Extract entities from this turn's data
                entities = self._extract_entities_from_data(
                    turn.data_returned,
                    turn.query_metadata
                )
                
                # Find best match
                for entity in entities:
                    if self._matches_reference(entity, reference_text, context_hint):
                        # Build composite key entity
                        resolved = CompositeKeyEntity(
                            entity_id=entity['id'],
                            entity_year=entity.get('year', current_year),
                            entity_table=entity.get('_table', 'unknown'),
                            entity_type=entity.get('_type', 'unknown'),
                            display_name=self._get_display_name(entity),
                            confidence=entity.get('_confidence', 0.9),
                            source_turn=turn.turn_number,
                            additional_fields={
                                k: v for k, v in entity.items()
                                if k not in ['id', 'year', '_table', '_type', '_confidence']
                            }
                        )
                        
                        # Cache for future use
                        if conversation_id not in self.entity_cache:
                            self.entity_cache[conversation_id] = {}
                        self.entity_cache[conversation_id][cache_key] = resolved
                        
                        return resolved
        
        return None
    
    def resolve_multiple_references(
        self,
        user_input: str,
        conversation_id: str,
        current_year: int = 2024
    ) -> List[CompositeKeyEntity]:
        """
        Detect and resolve multiple references in user input.
        
        Args:
            user_input: Full user query
            conversation_id: Current conversation ID
            current_year: Default year
        
        Returns:
            List of resolved composite key entities
        
        Example:
            User: "Show risks for that project and the entity we discussed"
            Returns: [
                CompositeKeyEntity(...project...),
                CompositeKeyEntity(...entity...)
            ]
        """
        resolved = []
        
        # Detect reference phrases
        for keyword in self.reference_keywords:
            if keyword in user_input.lower():
                # Extract context around keyword
                context = self._extract_context_around_keyword(
                    user_input,
                    keyword
                )
                
                # Resolve reference
                entity = self.resolve_reference(
                    context,
                    conversation_id,
                    current_year
                )
                
                if entity and entity not in resolved:
                    resolved.append(entity)
        
        return resolved
    
    def _extract_entities_from_data(
        self,
        data: Any,
        query_metadata: Dict
    ) -> List[Dict]:
        """
        Extract all entities with composite keys from query results.
        
        This is the core function that parses various data structures
        (dict, list, nested objects) to find entities with id/year pairs.
        """
        entities = []
        
        # Infer table from query metadata
        source_table = self._infer_table(query_metadata)
        entity_type = self.table_to_type.get(source_table, 'unknown')
        
        def extract_recursive(obj, current_table=source_table, depth=0):
            """Recursive extraction with depth limit."""
            if depth > 5:  # Prevent infinite recursion
                return
            
            if isinstance(obj, dict):
                # Check if this dict is an entity (has id and optionally year)
                if 'id' in obj:
                    entity = obj.copy()
                    entity['_table'] = current_table
                    entity['_type'] = self.table_to_type.get(current_table, 'unknown')
                    entity['_confidence'] = 1.0 if 'year' in obj else 0.7
                    entities.append(entity)
                
                # Recurse into nested structures
                for key, value in obj.items():
                    # Try to infer table from key
                    nested_table = self._infer_table_from_key(key) or current_table
                    extract_recursive(value, nested_table, depth + 1)
            
            elif isinstance(obj, list):
                for item in obj:
                    extract_recursive(item, current_table, depth + 1)
        
        extract_recursive(data)
        return entities
    
    def _matches_reference(
        self,
        entity: Dict,
        reference_text: str,
        context_hint: Optional[str] = None
    ) -> bool:
        """
        Check if entity matches reference text.
        
        Matching strategies:
        1. Generic pronouns (it, that, this) match any recent entity
        2. "that [type]" matches entity type (e.g., "that project" matches _type="project")
        3. Name field contains reference text
        4. Type matches context hint
        5. ID contains reference text
        """
        reference_lower = reference_text.lower()
        
        # Strategy 1: Generic pronoun matching (highest priority)
        if reference_lower in ['it', 'that', 'this', 'those', 'these']:
            return True
        
        # Strategy 2: "that [type]" pattern matching
        # Extract type from reference like "that project", "the entity", "those capabilities"
        entity_type = entity.get('_type', '')
        for type_keyword in ['project', 'entity', 'capability', 'risk', 'it_system', 'control', 'strategy', 'tactic', 'process']:
            if type_keyword in reference_lower and type_keyword in entity_type:
                return True
        
        # Strategy 3: Name field matching
        name_fields = ['name', 'title', 'description', 'display_name']
        for field in name_fields:
            if field in entity:
                entity_value = str(entity[field]).lower()
                # Check if any word from reference is in the name
                if reference_lower in entity_value:
                    return True
        
        # Strategy 4: Type matching with context hint
        if context_hint:
            if context_hint.lower() in entity_type.lower():
                return True
        
        # Strategy 5: ID matching
        if 'id' in entity:
            if reference_lower in str(entity['id']).lower():
                return True
        
        return False
    
    def _get_display_name(self, entity: Dict) -> str:
        """Extract best display name from entity data."""
        name_fields = ['name', 'title', 'display_name', 'description']
        for field in name_fields:
            if field in entity and entity[field]:
                return str(entity[field])
        
        # Fallback to ID
        return f"{entity.get('_type', 'Entity')} {entity.get('id', 'Unknown')}"
    
    def _infer_table(self, query_metadata: Dict) -> str:
        """Infer source table from query metadata."""
        if 'table' in query_metadata:
            return query_metadata['table']
        
        if 'sql' in query_metadata:
            # Parse FROM clause
            match = re.search(
                r'FROM\s+(\w+)',
                query_metadata['sql'],
                re.IGNORECASE
            )
            if match:
                return match.group(1)
        
        return 'unknown'
    
    def _infer_table_from_key(self, key: str) -> Optional[str]:
        """Infer table name from nested object key."""
        # Common patterns: "projects", "capabilities", "risks"
        key_lower = key.lower()
        
        table_mappings = {
            'project': 'ent_projects',
            'capability': 'ent_capabilities',
            'risk': 'sec_risks',
            'entity': 'ent_entities',
            'it_system': 'ent_it_systems',
            'control': 'sec_controls',
            'strategy': 'str_strategies',
            'tactic': 'tac_tactics'
        }
        
        for keyword, table in table_mappings.items():
            if keyword in key_lower:
                return table
        
        return None
    
    def _extract_context_around_keyword(
        self,
        text: str,
        keyword: str,
        window: int = 3
    ) -> str:
        """
        Extract context around reference keyword.
        
        Example:
            Text: "Show capabilities for that project we discussed"
            Keyword: "that"
            Returns: "that project"
        """
        words = text.split()
        keyword_lower = keyword.lower()
        
        for i, word in enumerate(words):
            if keyword_lower in word.lower():
                # Extract window words before and after
                start = max(0, i - window)
                end = min(len(words), i + window + 1)
                return ' '.join(words[start:end])
        
        return keyword
    
    def clear_cache(self, conversation_id: Optional[str] = None):
        """Clear entity cache for conversation or all conversations."""
        if conversation_id:
            self.entity_cache.pop(conversation_id, None)
        else:
            self.entity_cache.clear()


# Example usage and testing
if __name__ == "__main__":
    from datetime import datetime
    
    # Mock conversation manager for testing
    class MockTurn:
        def __init__(self, turn_num, data, metadata):
            self.turn_number = turn_num
            self.role = "assistant"
            self.data_returned = data
            self.query_metadata = metadata
            self.timestamp = datetime.utcnow()
    
    class MockConversationManager:
        def get_history(self, conversation_id, limit=10):
            # Simulate conversation history
            return [
                MockTurn(
                    1,
                    {
                        'id': 'PRJ001',
                        'year': 2024,
                        'name': 'Project Atlas',
                        'status': 'active'
                    },
                    {'table': 'ent_projects', 'sql': 'SELECT * FROM ent_projects...'}
                ),
                MockTurn(
                    2,
                    {
                        'id': 'ENT001',
                        'year': 2024,
                        'name': 'Digital Transformation Entity',
                        'type': 'government'
                    },
                    {'table': 'ent_entities'}
                )
            ]
    
    # Test resolver
    mock_manager = MockConversationManager()
    resolver = CompositeKeyResolver(mock_manager)
    
    # Test 1: Resolve "that project"
    result = resolver.resolve_reference(
        "that project",
        "conv_123"
    )
    
    if result:
        print("✅ Test 1 PASSED: Resolved reference")
        print(f"   Entity: {result.display_name}")
        print(f"   Composite Key: ({result.entity_id}, {result.entity_year})")
        print(f"   Table: {result.entity_table}")
    else:
        print("❌ Test 1 FAILED: Could not resolve reference")
    
    # Test 2: Resolve "it" (should get most recent entity)
    result2 = resolver.resolve_reference(
        "it",
        "conv_123"
    )
    
    if result2:
        print("\n✅ Test 2 PASSED: Resolved pronoun")
        print(f"   Entity: {result2.display_name}")
        print(f"   Composite Key: ({result2.entity_id}, {result2.entity_year})")
    else:
        print("\n❌ Test 2 FAILED: Could not resolve pronoun")
    
    # Test 3: Resolve multiple references
    results = resolver.resolve_multiple_references(
        "Show risks for that project and the entity mentioned earlier",
        "conv_123"
    )
    
    print(f"\n✅ Test 3: Found {len(results)} references")
    for r in results:
        print(f"   - {r.display_name} ({r.entity_type})")
