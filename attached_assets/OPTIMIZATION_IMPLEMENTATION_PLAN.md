# JOSOOR Optimization Implementation Plan
**Date:** October 26, 2025  
**Status:** Phase 1 - Critical Fixes In Progress

---

## 🎯 Implementation Overview

**Problem Statement:**
- Current GenAI system has ~80% SQL query failure rate due to composite key violations
- Reference resolution fails ("that project" → text string instead of (id, year) tuple)
- Multi-hop queries (<10% success rate) cannot trace complex relationships

**Solution Approach:**
- Install CompositeKeyResolver for reference resolution ✅ DONE
- Enhance Layer 1 prompts for composite key-aware context engineering
- Add LLM-based SQL generation to Layer 2 with composite key enforcement
- Test and validate improvements

---

## 📋 Phase 1: Critical Fixes (Days 1-3)

### Day 1: Layer 2 SQL Generation Enhancement
**Status:** IN PROGRESS

**Changes:**
1. ✅ Install `composite_key_resolver.py` to `backend/app/services/`
2. ⏳ Add LLM-based SQL generation method to `HybridRetrievalMemory` (Layer 2)
3. ⏳ Integrate enhanced Layer 2 prompt with few-shot examples
4. ⏳ Add SQL validation for composite key compliance

**Files Modified:**
- `backend/app/services/autonomous_agent.py`
  - Add `generate_sql_with_composite_keys()` method to Layer 2
  - Integrate enhanced SQL generation prompt
  - Add composite key validation logic

### Day 2: Layer 1 Reference Resolution
**Status:** PENDING

**Changes:**
1. Integrate `CompositeKeyResolver` with Layer 1 (`IntentUnderstandingMemory`)
2. Update Layer 1 prompt for reference resolution
3. Add context object enrichment with resolved composite keys

**Files Modified:**
- `backend/app/services/autonomous_agent.py`
  - Import and initialize `CompositeKeyResolver`
  - Update `IntentUnderstandingMemory.process()` prompt
  - Add reference resolution logic

### Day 3: Testing & Validation
**Status:** PENDING

**Test Cases:**
1. Composite key compliance in generated SQL (target: 100%)
2. Reference resolution accuracy ("that project" → (PRJ001, 2024))
3. Multi-hop query success rate (target: >95%)

---

## 🔧 Current System vs. Enhanced System

### Current System (Before Optimization)
```
Layer 1: Intent Analysis
├─ Hardcoded system prompt
├─ No reference resolution
└─ Returns basic intent JSON

Layer 2: Hybrid Retrieval
├─ Hardcoded SQL queries
├─ No composite key handling
└─ Direct database queries

Layer 3: Analytical Reasoning
└─ Uses worldview map for insights
```

### Enhanced System (After Phase 1)
```
Layer 1: Intent Analysis + Reference Resolution
├─ Enhanced prompt with composite key awareness
├─ CompositeKeyResolver integration
├─ Reference resolution to (id, year) tuples
└─ Returns enriched context with resolved entities

Layer 2: Hybrid Retrieval + SQL Generation
├─ LLM-based SQL generation
├─ Enhanced prompt with few-shot examples
├─ Composite key enforcement in all JOINs
├─ SQL validation before execution
└─ Fallback to hardcoded queries if generation fails

Layer 3: Analytical Reasoning
└─ Receives enriched context with composite keys
```

---

## 📊 Success Metrics

### Target Metrics (Post-Phase 1)
| Metric | Before | Target | How to Measure |
|--------|--------|--------|----------------|
| Composite Key Compliance | ~20% | 100% | SQL query validation |
| Reference Resolution | Text-only | 90%+ | Test with pronouns |
| Multi-Hop Queries (3+ hops) | <10% | >95% | Complex query test suite |
| SQL Query Success Rate | ~20% | >95% | Database execution logs |

### Test Queries
```sql
-- Test 1: Simple composite key reference
User: "Show Project Atlas"
User: "What capabilities does it have?"
Expected: Resolves "it" to (PRJ001, 2024)

-- Test 2: Multi-hop traversal
User: "Show risks affecting IT systems through projects for Entity ENT001"
Expected: 4-hop query with composite keys in all JOINs

-- Test 3: Temporal comparison
User: "Compare Entity ENT001 between 2023 and 2024"
Expected: Composite keys with year IN (2023, 2024)
```

---

## 🚀 Implementation Strategy

### Approach: Incremental Enhancement
1. **Preserve existing functionality** - Keep hardcoded queries as fallback
2. **Add LLM-based SQL generation** - New method in Layer 2
3. **Gradual rollout** - Test each layer independently before full integration

### Risk Mitigation
- ✅ Backup created: `autonomous_agent.py.backup`
- ✅ Backward compatible: No breaking changes to API
- ✅ Graceful degradation: Falls back to hardcoded queries if LLM fails

---

## 📝 Next Steps

### Immediate Actions
1. Add `generate_sql_with_composite_keys()` method to Layer 2
2. Integrate enhanced SQL generation prompt
3. Add validation logic for composite key compliance
4. Test with sample queries
5. Measure success metrics

### After Phase 1 Completion
1. Implement Phase 2: Full context flow (ResolvedContext object)
2. Implement Phase 3: Comprehensive testing
3. Monitor production metrics
4. Iterate based on results

---

**Implementation Time Estimate:** 3 days (Phase 1)  
**Risk Level:** Low (incremental, backward compatible)  
**Impact Level:** HIGH (fixes critical GenAI failure)
