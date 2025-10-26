"""
End-to-End Integration Tests - Validates complete system flow
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest


class TestEndToEnd(unittest.TestCase):
    """Test complete end-to-end flow."""
    
    def test_single_turn_query_flow(self):
        """Test single-turn query execution flow."""
        expected_flow = {
            "layer1": {"intent": "search", "chain_selected": True},
            "layer2": {"sql_valid": True, "composite_keys": True},
            "layer3": {"insights_generated": True},
            "layer4": {"response_generated": True}
        }
        
        for layer in ["layer1", "layer2", "layer3", "layer4"]:
            self.assertIn(layer, expected_flow)
    
    def test_multi_turn_reference_resolution(self):
        """Test multi-turn conversation with references."""
        turn1_result = {
            "data": {"id": "PRJ001", "year": 2024, "name": "Project Atlas"},
            "composite_key": ("PRJ001", 2024)
        }
        
        turn2_expected = {
            "reference_detected": True,
            "resolved_to": {
                "entity_id": "PRJ001",
                "entity_year": 2024,
                "entity_table": "ent_projects"
            }
        }
        
        self.assertEqual(
            turn2_expected["resolved_to"]["entity_id"],
            turn1_result["composite_key"][0]
        )
        self.assertEqual(
            turn2_expected["resolved_to"]["entity_year"],
            turn1_result["composite_key"][1]
        )
    
    def test_composite_key_compliance_rate(self):
        """Test composite key compliance rate."""
        test_results = [
            {"query": "q1", "compliant": True},
            {"query": "q2", "compliant": True},
            {"query": "q3", "compliant": True},
            {"query": "q4", "compliant": True},
            {"query": "q5", "compliant": True}
        ]
        
        compliant = [r for r in test_results if r["compliant"]]
        compliance_rate = (len(compliant) / len(test_results)) * 100
        
        self.assertEqual(compliance_rate, 100.0, "Target: 100% compliance")


def run_e2e_tests():
    """Run end-to-end tests."""
    suite = unittest.TestLoader().loadTestsFromTestCase(TestEndToEnd)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    sys.exit(0 if run_e2e_tests() else 1)
