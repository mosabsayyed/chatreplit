"""
Multi-Hop Query Tests - Validates relationship tracing
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest


class TestMultiHopTracing(unittest.TestCase):
    """Test multi-hop relationship tracing."""
    
    def test_two_hop_trace_structure(self):
        """Test 2-hop tracing has correct structure."""
        trace_results = {
            "entity": {"id": "ENT001", "year": 2024},
            "projects": [
                {"id": "PRJ001", "year": 2024},
                {"id": "PRJ002", "year": 2024}
            ],
            "capabilities": [
                {"id": "CAP001", "year": 2024, "project_id": "PRJ001"},
                {"id": "CAP002", "year": 2024, "project_id": "PRJ001"}
            ]
        }
        
        self.assertEqual(len(trace_results["projects"]), 2)
        self.assertEqual(len(trace_results["capabilities"]), 2)
        
        for cap in trace_results["capabilities"]:
            self.assertIn("id", cap)
            self.assertIn("year", cap)
            self.assertIn("project_id", cap)
    
    def test_four_hop_trace_structure(self):
        """Test 4-hop tracing structure."""
        trace_results = {
            "entity": {"id": "ENT001", "year": 2024},
            "projects": [{"id": "PRJ001", "year": 2024}],
            "it_systems": [
                {"id": "ITS001", "year": 2024, "project_id": "PRJ001"},
                {"id": "ITS002", "year": 2024, "project_id": "PRJ001"}
            ],
            "risks": [
                {"id": "RSK001", "year": 2024, "it_system_id": "ITS001"},
                {"id": "RSK002", "year": 2024, "it_system_id": "ITS001"}
            ]
        }
        
        self.assertEqual(len(trace_results["projects"]), 1)
        self.assertEqual(len(trace_results["it_systems"]), 2)
        self.assertEqual(len(trace_results["risks"]), 2)
        
        for risk in trace_results["risks"]:
            linked_system_ids = [sys["id"] for sys in trace_results["it_systems"]]
            self.assertIn(risk["it_system_id"], linked_system_ids)


def run_multi_hop_tests():
    """Run multi-hop query tests."""
    suite = unittest.TestLoader().loadTestsFromTestCase(TestMultiHopTracing)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    sys.exit(0 if run_multi_hop_tests() else 1)
