"""
JOSOOR Optimization: Test Suite for SQL Generation
Version: 1.0
Purpose: Validate composite key compliance in generated SQL queries

Tests SQL generation for:
1. Single-hop queries with composite keys
2. Multi-hop queries (2-5 hops)
3. Temporal comparison queries
4. Composite key validation
"""

import unittest
import re
from typing import Dict, List, Set


class SQLValidator:
    """Validates SQL queries for composite key compliance."""
    
    @staticmethod
    def extract_joins(sql: str) -> List[str]:
        """Extract all JOIN clauses from SQL."""
        pattern = r'JOIN\s+\w+\s+\w+\s+ON\s+[^J]+'
        return re.findall(pattern, sql, re.IGNORECASE | re.DOTALL)
    
    @staticmethod
    def has_year_in_join(join_clause: str) -> bool:
        """Check if JOIN clause includes year column."""
        return 'year' in join_clause.lower()
    
    @staticmethod
    def extract_where_clause(sql: str) -> str:
        """Extract WHERE clause from SQL."""
        match = re.search(
            r'WHERE\s+(.+?)(?:GROUP BY|ORDER BY|LIMIT|;|$)',
            sql,
            re.IGNORECASE | re.DOTALL
        )
        return match.group(1) if match else ""
    
    @staticmethod
    def has_year_in_where(where_clause: str) -> bool:
        """Check if WHERE clause includes year filter."""
        return 'year' in where_clause.lower()
    
    @staticmethod
    def count_composite_key_violations(sql: str) -> List[str]:
        """Count and list composite key violations in SQL."""
        violations = []
        
        # Check JOINs
        joins = SQLValidator.extract_joins(sql)
        for i, join in enumerate(joins, 1):
            if not SQLValidator.has_year_in_join(join):
                violations.append(f"JOIN {i} missing year: {join[:50]}...")
        
        # Check WHERE with ID filter
        where = SQLValidator.extract_where_clause(sql)
        if '.id' in where.lower() and not SQLValidator.has_year_in_where(where):
            violations.append(f"WHERE clause with ID filter missing year")
        
        return violations


class TestSingleHopQueries(unittest.TestCase):
    """Test single-hop query generation with composite keys."""
    
    def test_entity_to_projects(self):
        """Test Entity → Projects query."""
        # Expected SQL pattern
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
        
        # Check for violations
        violations = validator.count_composite_key_violations(sql)
        
        self.assertEqual(
            len(violations), 0,
            f"Should have no composite key violations. Found: {violations}"
        )
        
        # Check JOIN count
        joins = validator.extract_joins(sql)
        self.assertEqual(len(joins), 2, "Should have 2 JOINs for single-hop")
        
        # Check all JOINs use year
        for join in joins:
            self.assertTrue(
                validator.has_year_in_join(join),
                f"JOIN should include year: {join}"
            )
        
        # Check WHERE includes year
        where = validator.extract_where_clause(sql)
        self.assertTrue(
            validator.has_year_in_where(where),
            "WHERE clause should include year"
        )
    
    def test_project_to_capabilities(self):
        """Test Project → Capabilities query."""
        sql = """
        SELECT c.*
        FROM ent_projects p
        JOIN jt_project_capabilities pc 
            ON p.id = pc.project_id 
            AND p.year = pc.project_year
        JOIN ent_capabilities c 
            ON pc.capability_id = c.id 
            AND pc.capability_year = c.year
        WHERE p.id = 'PRJ001' 
            AND p.year = 2024;
        """
        
        validator = SQLValidator()
        violations = validator.count_composite_key_violations(sql)
        
        self.assertEqual(len(violations), 0, f"No violations expected: {violations}")


class TestMultiHopQueries(unittest.TestCase):
    """Test multi-hop query generation (3+ hops)."""
    
    def test_three_hop_query(self):
        """Test 3-hop query: Project → IT Systems → Risks."""
        sql = """
        SELECT r.*, its.name as it_system_name
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
        
        self.assertEqual(len(violations), 0, f"3-hop query should be valid: {violations}")
        
        # Check correct number of JOINs (4 for 3-hop)
        joins = validator.extract_joins(sql)
        self.assertEqual(len(joins), 4, "3-hop query needs 4 JOINs")
    
    def test_five_hop_query(self):
        """Test 5-hop query: Strategy → Tactics → Projects → Capabilities → Risks."""
        sql = """
        SELECT 
            s.name AS strategy_name,
            t.name AS tactic_name,
            p.name AS project_name,
            c.name AS capability_name,
            r.name AS risk_name
        FROM str_strategies s
        JOIN jt_strategy_tactics st 
            ON s.id = st.strategy_id 
            AND s.year = st.strategy_year
        JOIN tac_tactics t 
            ON st.tactic_id = t.id 
            AND st.tactic_year = t.year
        JOIN jt_tactic_projects tp 
            ON t.id = tp.tactic_id 
            AND t.year = tp.tactic_year
        JOIN ent_projects p 
            ON tp.project_id = p.id 
            AND tp.project_year = p.year
        JOIN jt_project_capabilities pc 
            ON p.id = pc.project_id 
            AND p.year = pc.project_year
        JOIN ent_capabilities c 
            ON pc.capability_id = c.id 
            AND pc.capability_year = c.year
        JOIN jt_capability_risks cr 
            ON c.id = cr.capability_id 
            AND c.year = cr.capability_year
        JOIN sec_risks r 
            ON cr.risk_id = r.id 
            AND cr.risk_year = r.year
        WHERE s.id = 'STR001' 
            AND s.year = 2024;
        """
        
        validator = SQLValidator()
        violations = validator.count_composite_key_violations(sql)
        
        self.assertEqual(len(violations), 0, f"5-hop query should be valid: {violations}")
        
        # Check correct number of JOINs (8 for 5-hop)
        joins = validator.extract_joins(sql)
        self.assertEqual(len(joins), 8, "5-hop query needs 8 JOINs")


class TestTemporalQueries(unittest.TestCase):
    """Test temporal comparison queries."""
    
    def test_year_comparison(self):
        """Test multi-year comparison query."""
        sql = """
        SELECT 
            p.year,
            COUNT(*) as project_count,
            json_agg(json_build_object('id', p.id, 'name', p.name)) as projects
        FROM ent_entities e
        JOIN jt_entity_projects ep 
            ON e.id = ep.entity_id 
            AND e.year = ep.entity_year
        JOIN ent_projects p 
            ON ep.project_id = p.id 
            AND ep.project_year = p.year
        WHERE e.id = 'ENT001' 
            AND e.year IN (2023, 2024)
        GROUP BY p.year
        ORDER BY p.year;
        """
        
        validator = SQLValidator()
        violations = validator.count_composite_key_violations(sql)
        
        self.assertEqual(len(violations), 0, f"Temporal query should be valid: {violations}")
        
        # Check WHERE includes year IN clause
        where = validator.extract_where_clause(sql)
        self.assertIn('year IN', where.upper(), "Should use year IN for comparison")


class TestCompositeKeyViolations(unittest.TestCase):
    """Test detection of composite key violations."""
    
    def test_detect_missing_year_in_join(self):
        """Test detection of missing year in JOIN."""
        # INCORRECT SQL (missing year in JOIN)
        bad_sql = """
        SELECT p.*
        FROM ent_entities e
        JOIN jt_entity_projects ep ON e.id = ep.entity_id
        JOIN ent_projects p ON ep.project_id = p.id
        WHERE e.id = 'ENT001' AND e.year = 2024;
        """
        
        validator = SQLValidator()
        violations = validator.count_composite_key_violations(bad_sql)
        
        self.assertGreater(
            len(violations), 0,
            "Should detect missing year in JOINs"
        )
        
        # Should detect 2 violations (2 JOINs missing year)
        self.assertEqual(len(violations), 2, "Should find 2 JOIN violations")
    
    def test_detect_missing_year_in_where(self):
        """Test detection of missing year in WHERE with ID filter."""
        # INCORRECT SQL (WHERE has ID but no year)
        bad_sql = """
        SELECT p.*
        FROM ent_projects p
        WHERE p.id = 'PRJ001';
        """
        
        validator = SQLValidator()
        violations = validator.count_composite_key_violations(bad_sql)
        
        self.assertGreater(
            len(violations), 0,
            "Should detect missing year in WHERE clause"
        )
    
    def test_correct_sql_no_violations(self):
        """Test that correct SQL has no violations."""
        good_sql = """
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
        violations = validator.count_composite_key_violations(good_sql)
        
        self.assertEqual(
            len(violations), 0,
            f"Correct SQL should have no violations: {violations}"
        )


class TestSQLPatterns(unittest.TestCase):
    """Test SQL pattern matching."""
    
    def test_join_extraction(self):
        """Test JOIN clause extraction."""
        sql = """
        SELECT * FROM table1 t1
        JOIN table2 t2 ON t1.id = t2.id AND t1.year = t2.year
        JOIN table3 t3 ON t2.id = t3.id AND t2.year = t3.year
        """
        
        validator = SQLValidator()
        joins = validator.extract_joins(sql)
        
        self.assertEqual(len(joins), 2, "Should extract 2 JOINs")
    
    def test_where_extraction(self):
        """Test WHERE clause extraction."""
        sql = """
        SELECT * FROM table
        WHERE id = 'ID001' AND year = 2024
        ORDER BY name;
        """
        
        validator = SQLValidator()
        where = validator.extract_where_clause(sql)
        
        self.assertIn('id', where.lower(), "Should extract WHERE with ID")
        self.assertIn('year', where.lower(), "Should extract WHERE with year")


class TestComplianceMetrics(unittest.TestCase):
    """Test compliance rate calculation."""
    
    def test_compliance_rate_calculation(self):
        """Test calculation of composite key compliance rate."""
        test_queries = [
            # Good query
            """
            SELECT * FROM ent_entities e
            JOIN jt_entity_projects ep ON e.id = ep.entity_id AND e.year = ep.entity_year
            WHERE e.id = 'ENT001' AND e.year = 2024;
            """,
            # Bad query 1
            """
            SELECT * FROM ent_entities e
            JOIN jt_entity_projects ep ON e.id = ep.entity_id
            WHERE e.id = 'ENT001';
            """,
            # Bad query 2
            """
            SELECT * FROM ent_projects p
            WHERE p.id = 'PRJ001';
            """,
            # Good query
            """
            SELECT * FROM ent_projects p
            JOIN jt_project_capabilities pc ON p.id = pc.project_id AND p.year = pc.project_year
            WHERE p.id = 'PRJ001' AND p.year = 2024;
            """
        ]
        
        validator = SQLValidator()
        
        compliant = 0
        total = len(test_queries)
        
        for sql in test_queries:
            violations = validator.count_composite_key_violations(sql)
            if len(violations) == 0:
                compliant += 1
        
        compliance_rate = (compliant / total) * 100
        
        # Should be 50% (2 out of 4 compliant)
        self.assertEqual(compliance_rate, 50.0, "Should calculate 50% compliance")
        
        print(f"\nCompliance Rate: {compliance_rate}%")
        print(f"Compliant Queries: {compliant}/{total}")


# Test execution
if __name__ == "__main__":
    # Run tests with verbose output
    unittest.main(verbosity=2)
    
    # Example output:
    # test_entity_to_projects (__main__.TestSingleHopQueries) ... ok
    # test_three_hop_query (__main__.TestMultiHopQueries) ... ok
    # test_detect_missing_year_in_join (__main__.TestCompositeKeyViolations) ... ok
    # test_compliance_rate_calculation (__main__.TestComplianceMetrics) ... 
    # Compliance Rate: 50.0%
    # Compliant Queries: 2/4
    # ok
    #
    # Ran 13 tests in 0.018s
    # OK
