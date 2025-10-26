"""
Composite Key Resolution Tests - Adapted for JOSOOR backend
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest
from datetime import datetime
from typing import Dict, List
from backend.app.services.composite_key_resolver import CompositeKeyResolver


class MockConversationTurn:
    """Mock conversation turn for testing."""
    def __init__(self, turn_num: int, data: Dict, metadata: Dict):
        self.turn_number = turn_num
        self.role = "assistant"
        self.data_returned = data
        self.query_metadata = metadata
        self.timestamp = datetime.utcnow()


class MockConversationManager:
    """Mock conversation manager for testing."""
    def __init__(self, history: List[MockConversationTurn]):
        self.history = history
    
    def get_history(self, conversation_id: str, limit: int = 10) -> List[MockConversationTurn]:
        return self.history[-limit:]


class TestCompositeKeyResolution(unittest.TestCase):
    """Test suite for composite key reference resolution."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.history = [
            MockConversationTurn(
                turn_num=1,
                data={
                    'id': 'PRJ001',
                    'year': 2024,
                    'name': 'Project Atlas',
                    'status': 'active'
                },
                metadata={
                    'table': 'ent_projects',
                    'sql': 'SELECT * FROM ent_projects WHERE id = \'PRJ001\''
                }
            ),
            MockConversationTurn(
                turn_num=2,
                data={
                    'id': 'ENT001',
                    'year': 2024,
                    'name': 'Digital Transformation Entity'
                },
                metadata={
                    'table': 'ent_entities'
                }
            )
        ]
        
        self.conversation_manager = MockConversationManager(self.history)
    
    def test_resolve_direct_reference(self):
        """Test resolution of direct reference like 'that project'."""
        resolver = CompositeKeyResolver(self.conversation_manager)
        
        result = resolver.resolve_reference(
            reference_text="that project",
            conversation_id="conv_123"
        )
        
        self.assertIsNotNone(result, "Should resolve reference")
        self.assertEqual(result.entity_id, "PRJ001")
        self.assertEqual(result.entity_year, 2024)
        self.assertEqual(result.entity_table, "ent_projects")
    
    def test_composite_key_structure(self):
        """Test that resolved entities have complete composite key structure."""
        resolver = CompositeKeyResolver(self.conversation_manager)
        
        result = resolver.resolve_reference(
            reference_text="that project",
            conversation_id="conv_123"
        )
        
        self.assertIsNotNone(result)
        
        required_fields = ['entity_id', 'entity_year', 'entity_table', 'entity_type', 'display_name']
        
        for field in required_fields:
            self.assertTrue(hasattr(result, field), f"Should have {field} field")
            self.assertIsNotNone(getattr(result, field), f"{field} should not be None")


def run_composite_key_tests():
    """Run composite key resolution tests."""
    suite = unittest.TestLoader().loadTestsFromTestCase(TestCompositeKeyResolution)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    sys.exit(0 if run_composite_key_tests() else 1)
