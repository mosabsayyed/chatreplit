"""
JOSOOR Test Suite Runner
Runs all optimization tests with proper import paths
"""

import sys
import os

# Add parent directory to path for backend imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import unittest

# Import test modules
from test_composite_key_resolution_runner import run_composite_key_tests
from test_sql_generation_runner import run_sql_tests  
from test_multi_hop_runner import run_multi_hop_tests
from test_e2e_runner import run_e2e_tests

if __name__ == "__main__":
    print("="*70)
    print("JOSOOR OPTIMIZATION TEST SUITE")
    print("="*70)
    
    print("\n[1/4] Running Composite Key Resolution Tests...")
    result1 = run_composite_key_tests()
    
    print("\n[2/4] Running SQL Generation Tests...")
    result2 = run_sql_tests()
    
    print("\n[3/4] Running Multi-Hop Query Tests...")
    result3 = run_multi_hop_tests()
    
    print("\n[4/4] Running End-to-End Integration Tests...")
    result4 = run_e2e_tests()
    
    print("\n" + "="*70)
    print("TEST SUITE SUMMARY")
    print("="*70)
    
    all_passed = all([result1, result2, result3, result4])
    
    if all_passed:
        print("✅ ALL TESTS PASSED")
        print("\nPhase 1 optimization validated successfully!")
        print("Ready to proceed to Phase 2.")
        sys.exit(0)
    else:
        print("❌ SOME TESTS FAILED")
        print("\nPlease review failures above.")
        sys.exit(1)
