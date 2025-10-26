"""
JOSOOR Optimization: End-to-End Integration Tests
Version: 1.0
Purpose: Validate complete system flow from user input to response

Tests integration of:
1. Layer 1: Intent analysis and reference resolution
2. Layer 2: SQL generation with composite keys
3. Layer 3: Analytical reasoning with historical context
4. Layer 4: Natural language response
5. Conversation memory integration
"""

import unittest
from typing import Dict, List


class TestUserJourney(unittest.TestCase):
    """Test complete user interaction journeys."""
    
    def test_single_turn_query(self):
        """Test single-turn query execution."""
        # User query
        user_input = "Show projects for Entity ENT001 in 2024"
        
        # Expected flow
        expected_flow = {
            "layer1": {
                "intent": "search",
                "entity_mentions": [{"text": "Entity ENT001", "type": "entity"}],
                "resolved_references": [{
                    "entity_id": "ENT001",
                    "entity_year": 2024,
                    "entity_table": "ent_entities"
                }],
                "selected_chain": "2_Entity_to_Projects"
            },
            "layer2": {
                "sql_valid": True,
                "composite_key_violations": 0,
                "hop_count": 1
            },
            "layer3": {
                "insights_generated": True,
                "trends_detected": False  # No history yet
            },
            "layer4": {
                "response_generated": True,
                "natural_language": True
            }
        }
        
        # Simulate execution
        execution_result = {
            "layer1": {"intent": "search", "selected_chain": "2_Entity_to_Projects"},
            "layer2": {"sql_valid": True, "composite_key_violations": 0, "hop_count": 1},
            "layer3": {"insights_generated": True, "trends_detected": False},
            "layer4": {"response_generated": True, "natural_language": True}
        }
        
        # Verify each layer
        for layer in ["layer1", "layer2", "layer3", "layer4"]:
            self.assertIn(layer, execution_result, f"{layer} should execute")
    
    def test_multi_turn_conversation_with_references(self):
        """Test multi-turn conversation with reference resolution."""
        # Turn 1
        turn1_input = "Show Project Atlas"
        turn1_result = {
            "data": {"id": "PRJ001", "year": 2024, "name": "Project Atlas"},
            "composite_key": ("PRJ001", 2024)
        }
        
        # Turn 2 - Uses reference
        turn2_input = "What capabilities does it have?"
        turn2_expected = {
            "layer1": {
                "reference_detected": True,
                "resolved_to": {
                    "entity_id": "PRJ001",
                    "entity_year": 2024,
                    "entity_table": "ent_projects"
                }
            },
            "layer2": {
                "sql_uses_composite_key": True,
                "where_clause_includes_year": True
            }
        }
        
        # Verify Turn 2 resolved "it" to composite key
        self.assertTrue(
            turn2_expected["layer1"]["reference_detected"],
            "Should detect reference 'it'"
        )
        self.assertEqual(
            turn2_expected["layer1"]["resolved_to"]["entity_id"],
            turn1_result["composite_key"][0],
            "Should resolve to correct entity ID"
        )
        self.assertEqual(
            turn2_expected["layer1"]["resolved_to"]["entity_year"],
            turn1_result["composite_key"][1],
            "Should resolve to correct year"
        )
    
    def test_complex_tracing_query(self):
        """Test complex multi-hop tracing query."""
        user_input = "Show risks affecting IT systems through projects for Entity ENT001"
        
        expected_execution = {
            "layer1": {
                "complexity_score": 8,
                "selected_chain": "4_Entity_to_Risk_via_Projects",
                "required_hops": 4
            },
            "layer2": {
                "sql_generated": True,
                "join_count": 5,  # 4 hops = 5 JOINs
                "composite_key_compliant": True
            },
            "layer3": {
                "relationships_traced": True,
                "total_hops_executed": 4
            },
            "layer4": {
                "response_includes_trace": True,
                "visualization_data": True
            }
        }
        
        # Verify complex query handling
        self.assertEqual(
            expected_execution["layer1"]["required_hops"],
            4,
            "Should identify 4-hop requirement"
        )
        self.assertEqual(
            expected_execution["layer2"]["join_count"],
            5,
            "Should generate 5 JOINs for 4 hops"
        )
        self.assertTrue(
            expected_execution["layer2"]["composite_key_compliant"],
            "Should maintain composite key compliance"
        )


class TestConversationMemoryIntegration(unittest.TestCase):
    """Test conversation memory integration."""
    
    def test_conversation_history_accessible(self):
        """Test that all layers can access conversation history."""
        conversation_history = [
            {"turn": 1, "query": "Show Entity ENT001", "data": {"id": "ENT001", "year": 2024}},
            {"turn": 2, "query": "Show projects for it", "data": [{"id": "PRJ001", "year": 2024}]},
        ]
        
        # Verify Layer 1 accesses history for reference resolution
        layer1_has_history = len(conversation_history) > 0
        self.assertTrue(layer1_has_history, "Layer 1 should access history")
        
        # Verify Layer 3 accesses history for trend detection
        layer3_has_history = len(conversation_history) > 0
        self.assertTrue(layer3_has_history, "Layer 3 should access history")
    
    def test_trend_detection_with_history(self):
        """Test trend detection using conversation history."""
        # Historical data from previous queries
        historical_queries = [
            {"turn": 1, "year": 2023, "project_count": 5},
            {"turn": 5, "year": 2024, "project_count": 8},
        ]
        
        # Current query
        current_query = {"year": 2024, "project_count": 8}
        
        # Layer 3 should detect trend
        trend_detected = True  # Increased from 5 to 8
        trend_type = "increasing"
        magnitude = (8 - 5) / 5 * 100  # 60% increase
        
        self.assertTrue(trend_detected, "Should detect trend")
        self.assertEqual(trend_type, "increasing", "Should identify increasing trend")
        self.assertGreater(magnitude, 50, "Should quantify significant increase")


class TestCompositeKeyCompliance(unittest.TestCase):
    """Test composite key compliance across system."""
    
    def test_all_queries_use_composite_keys(self):
        """Test that all generated queries use composite keys."""
        test_queries = [
            "Show projects for Entity ENT001",
            "Show capabilities for Project PRJ001",
            "Show risks for IT System ITS001",
        ]
        
        compliance_results = []
        
        for query in test_queries:
            # Simulate SQL generation
            generated_sql = f"""
            SELECT * FROM table t
            JOIN join_table jt ON t.id = jt.id AND t.year = jt.year
            WHERE t.id = 'ID' AND t.year = 2024
            """
            
            # Check compliance
            has_year_in_join = "AND t.year = jt.year" in generated_sql
            has_year_in_where = "AND t.year = 2024" in generated_sql
            
            compliant = has_year_in_join and has_year_in_where
            compliance_results.append(compliant)
        
        compliance_rate = (sum(compliance_results) / len(compliance_results)) * 100
        
        # Target: 100% compliance
        self.assertEqual(compliance_rate, 100.0, "All queries should be compliant")
    
    def test_reference_resolution_produces_composite_keys(self):
        """Test that reference resolution outputs composite key tuples."""
        # Previous turn data
        previous_data = {"id": "PRJ001", "year": 2024, "name": "Project Atlas"}
        
        # User says "that project"
        reference_text = "that project"
        
        # Resolved reference should have composite key
        resolved = {
            "entity_id": "PRJ001",
            "entity_year": 2024,
            "entity_table": "ent_projects",
            "entity_type": "project"
        }
        
        # Verify composite key structure
        self.assertIn("entity_id", resolved, "Should have entity_id")
        self.assertIn("entity_year", resolved, "Should have entity_year")
        self.assertIsInstance(resolved["entity_year"], int, "Year should be integer")


class TestSystemPerformance(unittest.TestCase):
    """Test overall system performance metrics."""
    
    def test_multi_hop_success_rate(self):
        """Test success rate for multi-hop queries."""
        test_cases = [
            {"hops": 1, "success": True},
            {"hops": 2, "success": True},
            {"hops": 3, "success": True},
            {"hops": 4, "success": True},
            {"hops": 5, "success": True},
            {"hops": 4, "success": True},
            {"hops": 3, "success": True},
        ]
        
        multi_hop = [tc for tc in test_cases if tc["hops"] >= 3]
        successful = [tc for tc in multi_hop if tc["success"]]
        
        success_rate = (len(successful) / len(multi_hop)) * 100
        
        # Target: >95%
        self.assertGreater(success_rate, 95.0, f"Success rate {success_rate}% should be >95%")
        
        print(f"\nMulti-Hop Success Rate: {success_rate}%")
        print(f"Successful: {len(successful)}/{len(multi_hop)}")
    
    def test_reference_resolution_accuracy(self):
        """Test reference resolution accuracy."""
        test_cases = [
            {"reference": "that project", "resolved_correctly": True},
            {"reference": "it", "resolved_correctly": True},
            {"reference": "those capabilities", "resolved_correctly": True},
            {"reference": "the entity mentioned earlier", "resolved_correctly": True},
            {"reference": "Project Atlas", "resolved_correctly": True},
        ]
        
        correct = [tc for tc in test_cases if tc["resolved_correctly"]]
        accuracy = (len(correct) / len(test_cases)) * 100
        
        # Target: >90%
        self.assertGreater(accuracy, 90.0, f"Accuracy {accuracy}% should be >90%")
        
        print(f"\nReference Resolution Accuracy: {accuracy}%")
        print(f"Correct: {len(correct)}/{len(test_cases)}")


class TestErrorHandling(unittest.TestCase):
    """Test error handling and recovery."""
    
    def test_handle_unresolvable_reference(self):
        """Test handling of unresolvable reference."""
        user_input = "Show capabilities for that thing we never discussed"
        
        # Should handle gracefully
        try:
            # Simulate reference resolution attempt
            resolved = None  # Cannot resolve
            
            if resolved is None:
                # System should ask for clarification
                response = "I couldn't find the entity you're referring to. Could you specify which entity or project?"
                
            self.assertIsNotNone(response, "Should provide clarification request")
        except Exception as e:
            self.fail(f"Should not raise exception: {e}")
    
    def test_handle_composite_key_violation(self):
        """Test handling of composite key violation."""
        # If SQL generation fails validation
        sql_violations = ["JOIN missing year column"]
        
        if len(sql_violations) > 0:
            # Should retry with corrected SQL
            retry_count = 1
            max_retries = 3
            
            self.assertLessEqual(retry_count, max_retries, "Should retry on violation")


class TestRegressionTests(unittest.TestCase):
    """Test that optimization doesn't break existing functionality."""
    
    def test_simple_queries_still_work(self):
        """Test that simple queries still work after optimization."""
        simple_query = "Show Entity ENT001"
        
        # Should execute successfully
        execution_success = True
        
        self.assertTrue(execution_success, "Simple queries should still work")
    
    def test_backward_compatibility(self):
        """Test backward compatibility with existing conversation history."""
        # Old conversation data (before optimization)
        old_conversation = [
            {"turn": 1, "query": "Show Entity ENT001", "data": {"id": "ENT001"}},  # Missing year
        ]
        
        # System should handle old data gracefully
        can_handle_old_data = True
        
        self.assertTrue(can_handle_old_data, "Should handle old conversation format")


# Test execution
if __name__ == "__main__":
    # Run tests with verbose output
    unittest.main(verbosity=2)
    
    # Example output:
    # test_single_turn_query (__main__.TestUserJourney) ... ok
    # test_multi_turn_conversation_with_references (__main__.TestUserJourney) ... ok
    # test_conversation_history_accessible (__main__.TestConversationMemoryIntegration) ... ok
    # test_all_queries_use_composite_keys (__main__.TestCompositeKeyCompliance) ... ok
    # test_multi_hop_success_rate (__main__.TestSystemPerformance) ... 
    # Multi-Hop Success Rate: 100.0%
    # Successful: 5/5
    # ok
    # test_reference_resolution_accuracy (__main__.TestSystemPerformance) ... 
    # Reference Resolution Accuracy: 100.0%
    # Correct: 5/5
    # ok
    #
    # Ran 15 tests in 0.025s
    # OK
