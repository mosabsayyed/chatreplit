"""
SQL Generation Tests - Validates composite key compliance
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest
import re


class SQLValidator:
    """Validates SQL queries for composite key compliance."""
    
    @staticmethod
    def extract_joins(sql: str):
        pattern = r'JOIN\s+[\w_]+\s+[\w_]+\s+ON\s+[^J]+?(?=JOIN|WHERE|GROUP|ORDER|LIMIT|;|$)'
        return re.findall(pattern, sql, re.IGNORECASE | re.DOTALL)
    
    @staticmethod
    def has_year_in_join(join_clause: str):
        return 'year' in join_clause.lower()
    
    @staticmethod
    def count_composite_key_violations(sql: str):
        violations = []
        joins = SQLValidator.extract_joins(sql)
        for i, join in enumerate(joins, 1):
            if not SQLValidator.has_year_in_join(join):
                violations.append(f"JOIN {i} missing year")
        return violations


class TestSQLGeneration(unittest.TestCase):
    """Test SQL generation with composite keys."""
    
    def test_entity_to_projects(self):
        """Test Entity → Projects query has composite keys."""
        sql = """
        SELECT p.*
        FROM ent_entities e
        JOIN jt_entity_projects ep 
            ON e.id = ep.entity_id 
            AND e.year = ep.entity_year
        JOIN ent_projects p 
            ON ep.project_id = p.id 
            AND ep.project_year = p.year
        WHERE e.id = 'ENT001' 
            AND e.year = 2024;
        """
        
        validator = SQLValidator()
        violations = validator.count_composite_key_violations(sql)
        
        self.assertEqual(len(violations), 0, f"Should have no violations: {violations}")
    
    def test_three_hop_query(self):
        """Test 3-hop query has composite keys."""
        sql = """
        SELECT r.*
        FROM ent_projects p
        JOIN jt_project_it_systems pits 
            ON p.id = pits.project_id 
            AND p.year = pits.project_year
        JOIN ent_it_systems its 
            ON pits.it_system_id = its.id 
            AND pits.it_system_year = its.year
        JOIN jt_it_system_risks itsr 
            ON its.id = itsr.it_system_id 
            AND its.year = itsr.it_system_year
        JOIN sec_risks r 
            ON itsr.risk_id = r.id 
            AND itsr.risk_year = r.year
        WHERE p.id = 'PRJ001' 
            AND p.year = 2024;
        """
        
        validator = SQLValidator()
        violations = validator.count_composite_key_violations(sql)
        joins = validator.extract_joins(sql)
        
        self.assertEqual(len(violations), 0, f"Should have no violations: {violations}")
        self.assertEqual(len(joins), 4, "3-hop query needs 4 JOINs")


def run_sql_tests():
    """Run SQL generation tests."""
    suite = unittest.TestLoader().loadTestsFromTestCase(TestSQLGeneration)
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == "__main__":
    sys.exit(0 if run_sql_tests() else 1)
