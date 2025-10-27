from typing import List, Dict, Any, Optional
from app.services.llm_provider import llm_provider
from app.db.postgres_client import postgres_client
from app.models.schemas import AgentResponse, Visualization, ConfidenceInfo
from app.utils.temporal import get_current_year, get_temporal_context, CURRENT_YEAR
from app.services.composite_key_resolver import CompositeKeyResolver, CompositeKeyEntity
from app.services.composite_key_validator import CompositeKeyValidator
from app.services.schema_loader import get_schema_loader
from app.utils.debug_logger import log_debug
from dataclasses import dataclass, field
import json
import base64
import io
from datetime import datetime
from pathlib import Path

# Load worldview map (DTDL knowledge graph structure)
WORLDVIEW_MAP_PATH = Path(__file__).parent.parent / "config" / "worldview_map.json"
with open(WORLDVIEW_MAP_PATH, 'r') as f:
    WORLDVIEW_MAP = json.load(f)


@dataclass
class ResolvedContext:
    """
    Comprehensive context object passed across all agent layers.
    Source: OPTIMIZATION_ANALYSIS.md lines 398-426
    """
    # User context
    user_id: str
    conversation_id: str
    current_turn: int
    
    # Intent analysis (Layer 1 output)
    user_intent: str
    entity_mentions: List[Dict] = field(default_factory=list)
    resolved_references: List[Dict] = field(default_factory=list)
    selected_chain: str = ""
    required_hops: int = 0
    
    # Query context
    target_entities: List[str] = field(default_factory=list)
    filters: Dict[str, Any] = field(default_factory=dict)
    temporal_scope: Dict[str, Any] = field(default_factory=dict)
    
    # Conversation memory
    previous_results: List[Dict] = field(default_factory=list)
    entity_cache: Dict[str, Dict] = field(default_factory=dict)
    exploration_path: List[str] = field(default_factory=list)
    
    # Metadata
    timestamp: datetime = field(default_factory=datetime.now)
    layer_metadata: Dict[str, Any] = field(default_factory=dict)
    
    @classmethod
    def from_intent(
        cls,
        intent: Dict[str, Any],
        user_id: str,
        conversation_id: str,
        current_turn: int
    ) -> 'ResolvedContext':
        """Create ResolvedContext from Layer 1 intent output."""
        return cls(
            user_id=user_id,
            conversation_id=conversation_id,
            current_turn=current_turn,
            user_intent=intent.get("intent_type", ""),
            entity_mentions=intent.get("entities", []),
            resolved_references=intent.get("resolved_references", []),
            selected_chain=intent.get("selected_chain", ""),
            required_hops=intent.get("required_hops", 0),
            target_entities=intent.get("target_entities", []),
            filters=intent.get("filters", {}),
            temporal_scope=intent.get("temporal_scope", {})
        )
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert ResolvedContext to dictionary for serialization."""
        return {
            "user_id": self.user_id,
            "conversation_id": self.conversation_id,
            "current_turn": self.current_turn,
            "user_intent": self.user_intent,
            "entity_mentions": self.entity_mentions,
            "resolved_references": self.resolved_references,
            "selected_chain": self.selected_chain,
            "required_hops": self.required_hops,
            "target_entities": self.target_entities,
            "filters": self.filters,
            "temporal_scope": self.temporal_scope,
            "previous_results": self.previous_results,
            "entity_cache": self.entity_cache,
            "exploration_path": self.exploration_path,
            "timestamp": self.timestamp.isoformat() if isinstance(self.timestamp, datetime) else str(self.timestamp),
            "layer_metadata": self.layer_metadata
        }


class IntentUnderstandingMemory:
    """Layer 1: Extract intent from user query with composite key resolution"""
    
    def __init__(self, conversation_manager=None):
        """Initialize Layer 1 with optional conversation manager for reference resolution"""
        self.conversation_manager = conversation_manager
        self.resolver = None
        if conversation_manager:
            self.resolver = CompositeKeyResolver(conversation_manager)
    
    async def process(self, question: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Analyze question and extract intent with COMPOSITE KEY RESOLUTION"""
        
        # Get conversation history if available
        conversation_history = ""
        entity_cache_data = {}
        if context:
            if "conversation_history" in context:
                conversation_history = context['conversation_history']
            if "conversation_id" in context and self.resolver:
                # Get entity cache for reference resolution
                conv_id = str(context["conversation_id"])
                entity_cache_data = self.resolver.entity_cache.get(conv_id, {})
        
        # Prepare placeholder values for EXACT prompt substitution
        worldview_chains = json.dumps(WORLDVIEW_MAP.get("chains", {}), indent=2)
        entity_cache_str = json.dumps(entity_cache_data, indent=2) if entity_cache_data else "None"
        exploration_path = "[]"  # TODO: Track user's exploration path across conversation
        
        # Load EXACT Layer 1 prompt from optimization package file (lines 5-244)
        # Do simple placeholder substitution: {user_input}, {conversation_history}, {worldview_chains}, {entity_cache}, {exploration_path}
        prompt_template = """You are the Intent Analysis Agent for JOSOOR's organizational transformation system.

Your role is to analyze user queries and resolve them to structured context objects that enable accurate relationship tracing across the Virtual Knowledge Graph (VKG).

## CRITICAL CAPABILITIES

### 1. Reference Resolution to Composite Keys
When users say "that project", "it", "the entity mentioned earlier", you MUST:
- Search conversation history for the referenced entity
- Extract the COMPOSITE KEY: (id, year)
- Return structured entity object, NOT just text string

Example:
User Turn 1: "Show me Project Atlas"
System returns: {{id: "PRJ001", year: 2024, name: "Project Atlas"}}

User Turn 2: "Show capabilities for that project"
YOU MUST RESOLVE: 
{{
  "entity_id": "PRJ001",
  "entity_year": 2024,
  "entity_table": "ent_projects",
  "entity_type": "project",
  "display_name": "Project Atlas"
}}

NOT: {{"reference": "Project Atlas"}} ❌

### 2. World-View Map Chain Selection
You MUST select the optimal chain based on:
- Source entity type (starting point)
- Target entity type (what user wants to find)
- Path length (minimum hops required)
- User's exploration history

Available Chains:
{worldview_chains}

Selection Criteria:
- Minimize unnecessary hops
- Cover the required path
- Match user's exploration pattern (look at previous queries)

### 3. Multi-Hop Path Planning
For complex queries like "Show risks affecting IT systems through projects":
- Identify required path: Entity → Projects → IT Systems → Risks (4 hops)
- Select chain that supports this traversal
- DO NOT select shorter chain that only covers 2 hops

---

## INPUT DATA

### User Query
{user_input}

### Conversation History (Last 10 Turns)
{conversation_history}

### Previously Retrieved Entities (Available for Reference Resolution)
{entity_cache}

### User's Exploration Path
{exploration_path}

---

## YOUR TASK

Analyze the user query and output a structured JSON object with:

```json
{{
  "user_intent": "search|compare|trace|analyze|summarize",
  
  "entity_mentions": [
    {{
      "text": "raw text extracted",
      "type": "project|entity|risk|capability|etc",
      "is_reference": true|false,
      "confidence": 0.0-1.0
    }}
  ],
  
  "resolved_references": [
    {{
      "entity_id": "PRJ001",
      "entity_year": 2024,
      "entity_table": "ent_projects",
      "entity_type": "project",
      "display_name": "Project Atlas",
      "source": "conversation_turn_3"
    }}
  ],
  
  "chain_selection": {{
    "chain_id": "4_Entity_to_Risk_via_Projects",
    "estimated_hops": 3,
    "source_table": "ent_entities",
    "target_tables": ["sec_risks"],
    "reasoning": "User wants to trace risks from entity through projects. Requires 3-hop traversal."
  }},
  
  "target_entities": ["sec_risks", "ent_it_systems"],
  
  "filters": {{
    "year": 2024,
    "status": "active",
    "custom": {{}}
  }},
  
  "temporal_scope": {{
    "mode": "single|comparison|trend",
    "years": [2024],
    "comparison_years": [2023, 2024]
  }},
  
  "complexity_score": 1-10,
  
  "requires_multi_turn": true|false
}}
```

---

## REASONING PROCESS (Chain-of-Thought)

Step 1: Parse user query for entities and intent
Step 2: Check if query contains references ("it", "that", "previous")
Step 3: If references found, search conversation history for composite keys
Step 4: Identify source entity and target entity
Step 5: Calculate minimum path length (hops) needed
Step 6: Select World-View Map chain that covers this path
Step 7: Extract any filters or temporal parameters
Step 8: Assess query complexity (simple lookup vs. complex tracing)

---

## EXAMPLES

### Example 1: Simple Reference Resolution
User: "Show me Project Atlas"
[System returns data]
User: "What capabilities does it have?"

Output:
```json
{{
  "user_intent": "search",
  "entity_mentions": [{{"text": "it", "type": "project", "is_reference": true}}],
  "resolved_references": [{{
    "entity_id": "PRJ001",
    "entity_year": 2024,
    "entity_table": "ent_projects",
    "entity_type": "project",
    "display_name": "Project Atlas",
    "source": "conversation_turn_1"
  }}],
  "chain_selection": {{
    "chain_id": "2_Project_to_Capability",
    "estimated_hops": 1,
    "source_table": "ent_projects",
    "target_tables": ["ent_capabilities"],
    "reasoning": "Direct project-to-capability relationship, single hop via jt_project_capabilities"
  }},
  "target_entities": ["ent_capabilities"],
  "complexity_score": 2
}}
```

### Example 2: Multi-Hop Tracing
User: "Show me risks affecting IT systems used by Entity ENT001"

Output:
```json
{{
  "user_intent": "trace",
  "entity_mentions": [{{"text": "Entity ENT001", "type": "entity", "is_reference": false}}],
  "resolved_references": [{{
    "entity_id": "ENT001",
    "entity_year": 2024,
    "entity_table": "ent_entities",
    "entity_type": "entity",
    "display_name": "Entity ENT001"
  }}],
  "chain_selection": {{
    "chain_id": "4_Entity_to_Risk_via_IT_Systems",
    "estimated_hops": 4,
    "source_table": "ent_entities",
    "target_tables": ["sec_risks", "ent_it_systems"],
    "reasoning": "Complex tracing: Entity → Projects → IT Systems → Risks. Requires 4-hop traversal through multiple join tables."
  }},
  "target_entities": ["sec_risks", "ent_it_systems"],
  "complexity_score": 8,
  "requires_multi_turn": false
}}
```

### Example 3: Temporal Comparison
User: "Compare Entity ENT001's projects between 2023 and 2024"

Output:
```json
{{
  "user_intent": "compare",
  "entity_mentions": [{{"text": "Entity ENT001", "type": "entity", "is_reference": false}}],
  "resolved_references": [{{
    "entity_id": "ENT001",
    "entity_year": 2024,
    "entity_table": "ent_entities",
    "entity_type": "entity"
  }}],
  "chain_selection": {{
    "chain_id": "2_Entity_to_Projects",
    "estimated_hops": 1,
    "source_table": "ent_entities",
    "target_tables": ["ent_projects"],
    "reasoning": "Temporal comparison requires same chain applied to multiple years"
  }},
  "target_entities": ["ent_projects"],
  "temporal_scope": {{
    "mode": "comparison",
    "years": [2023, 2024],
    "comparison_type": "year_over_year"
  }},
  "complexity_score": 5
}}
```

### Example 4: General Query (NO Specific Entity Reference)
User: "What projects do we have for 2027?"

Output:
```json
{{
  "user_intent": "search",
  "entity_mentions": [{{"text": "projects", "type": "project", "is_reference": false, "confidence": 0.9}}],
  "resolved_references": [],
  "chain_selection": {{
    "chain_id": "general_list",
    "estimated_hops": 0,
    "source_table": null,
    "target_tables": ["ent_projects"],
    "reasoning": "General listing query with no specific source entity. Direct table query with filters."
  }},
  "target_entities": ["ent_projects"],
  "filters": {{
    "year": 2027,
    "status": null
  }},
  "temporal_scope": {{
    "mode": "single",
    "years": [2027],
    "comparison_years": []
  }},
  "complexity_score": 1,
  "requires_multi_turn": false
}}
```

### Example 5: Another General Query
User: "Show me all active capabilities this year"

Output:
```json
{{
  "user_intent": "search",
  "entity_mentions": [{{"text": "capabilities", "type": "capability", "is_reference": false, "confidence": 0.95}}],
  "resolved_references": [],
  "chain_selection": {{
    "chain_id": "general_list",
    "estimated_hops": 0,
    "source_table": null,
    "target_tables": ["ent_capabilities"],
    "reasoning": "General listing query for capabilities. Direct table query."
  }},
  "target_entities": ["ent_capabilities"],
  "filters": {{
    "year": 2025,
    "status": "active"
  }},
  "temporal_scope": {{
    "mode": "single",
    "years": [2025]
  }},
  "complexity_score": 1
}}
```

---

## CRITICAL RULES

1. **NEVER return text-only references** - Always resolve to composite keys
2. **ALWAYS include entity_year** in resolved references
3. **ALWAYS select chain that covers full path** - Don't pick shorter chains
4. **USE conversation history** - Don't ignore previous turns
5. **PREFER longer chains** when uncertain - Better to have extra capacity than fall short
6. **FOR GENERAL QUERIES (no specific entity):** 
   - Set resolved_references to []
   - Set source_table to null
   - ALWAYS populate target_entities with table names (e.g., ["ent_projects"])
   - ALWAYS extract year from question and put in filters.year
   - Map user terms: "projects" → "ent_projects", "capabilities" → "ent_capabilities", "objectives" → "sec_objectives"

Output ONLY valid JSON. No markdown, no explanations outside JSON."""
        
        # Do placeholder substitutions (EXACT method from optimization package)
        system_prompt = prompt_template.replace("{user_input}", question)
        system_prompt = system_prompt.replace("{conversation_history}", conversation_history)
        system_prompt = system_prompt.replace("{worldview_chains}", worldview_chains)
        system_prompt = system_prompt.replace("{entity_cache}", entity_cache_str)
        system_prompt = system_prompt.replace("{exploration_path}", exploration_path)
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Question: {question}\n\nExtract intent as JSON."}
        ]
        
        # RAW DEBUG LOGGING - Layer 1
        log_debug(1, "prompt_sent", {
            "messages": messages,
            "temperature": 0.3
        })
        
        response = await llm_provider.chat_completion(messages, temperature=0.3)
        
        # RAW DEBUG LOGGING - Layer 1
        log_debug(1, "response_received", response)
        
        try:
            # Strip markdown code fences if present (```json ... ```)
            cleaned_response = response.strip()
            if cleaned_response.startswith("```json"):
                cleaned_response = cleaned_response[7:]  # Remove ```json
            if cleaned_response.startswith("```"):
                cleaned_response = cleaned_response[3:]  # Remove ```
            if cleaned_response.endswith("```"):
                cleaned_response = cleaned_response[:-3]  # Remove trailing ```
            cleaned_response = cleaned_response.strip()
            
            intent = json.loads(cleaned_response)
        except Exception as e:
            print(f"⚠️  JSON parsing error: {e}")
            print(f"⚠️  Raw response: {response[:200]}")
            intent = {
                "intent_type": "general_question",
                "entities": [],
                "time_period": {"year": CURRENT_YEAR, "quarter": None},
                "analysis_type": "descriptive",
                "is_simple": False,
                "confidence": "low",
                "clarification_needed": "I'm not sure what you're asking about. Could you please rephrase your question?"
            }
        
        return intent


class HybridRetrievalMemory:
    """Layer 2: Retrieve relevant data from PostgreSQL + Knowledge Graph with composite key SQL generation"""
    
    def __init__(self):
        """Initialize Layer 2 with CompositeKeyValidator (lazy-loaded)"""
        self.validator: Optional[CompositeKeyValidator] = None
        self._schema_loader = get_schema_loader()
    
    async def _ensure_validator(self):
        """Lazy-load validator with schema from schema_definition.json"""
        if self.validator is None:
            schema = self._schema_loader.load_schema()
            self.validator = CompositeKeyValidator(schema)
    
    async def generate_sql_with_composite_keys(self, intent: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Generate SQL query with MANDATORY composite key enforcement - Supports TWO modes"""
        
        # Ensure validator is loaded with introspected schema
        await self._ensure_validator()
        
        # Extract data from Layer 1
        chain_selection = intent.get("chain_selection", {})
        resolved_refs = intent.get("resolved_references", [])
        target_entities = intent.get("target_entities", [])
        filters = intent.get("filters", {})
        
        # MODE 1: Specific entity query (with resolved references)
        if resolved_refs and len(resolved_refs) > 0:
            source_id = resolved_refs[0].get("entity_id")
            source_year = resolved_refs[0].get("entity_year")
            source_table = chain_selection.get("source_table")
            target_tables = chain_selection.get("target_tables", [])
            
            if not source_id or not source_year or not source_table:
                return None
            
            # Continue with entity-specific SQL generation (existing path)
            return await self._generate_entity_specific_sql(intent, source_id, source_year, source_table, target_tables, chain_selection)
        
        # MODE 2: General query (no specific entity, just filters)
        elif target_entities and len(target_entities) > 0:
            # Generate simple SELECT with WHERE filters
            return await self._generate_general_query_sql(intent, target_entities, filters)
        
        # MODE 3: No useful data from Layer 1 - fallback
        else:
            return None
    
    async def _generate_entity_specific_sql(self, intent: Dict[str, Any], source_id: str, source_year: int, source_table: str, target_tables: list, chain_selection: dict) -> Optional[Dict[str, Any]]:
        """Generate SQL for entity-specific queries with JOINs"""
        
        # EXACT Layer 2 SQL Generation Prompt from optimization package (layer2_sql_generation_prompt.txt)
        system_prompt = f"""You are an expert SQL query generator for JOSOOR's time-series organizational transformation database.

## ⚠️ CRITICAL CONSTRAINT: COMPOSITE KEY ENFORCEMENT

Every entity/sector table uses **(id, year)** as the composite primary key.

### THE RULE
**ALL JOINs MUST reference BOTH columns.**
**ALL WHERE clauses filtering by ID MUST include year.**

### INCORRECT (WILL FAIL OR RETURN WRONG DATA)
```sql
❌ JOIN jt_entity_projects ep ON e.id = ep.entity_id
❌ WHERE e.id = 'ENT001'
```

### CORRECT (REQUIRED)
```sql
✅ JOIN jt_entity_projects ep ON e.id = ep.entity_id AND e.year = ep.entity_year
✅ WHERE e.id = 'ENT001' AND e.year = 2024
```

**Violating this rule will cause:**
- Constraint violations (query fails)
- Incomplete data (missing time-series records)
- Wrong relationships (joining across wrong years)

---

## INPUT CONTEXT

### Source Entity
- ID: {source_id}
- Year: {source_year}
- Table: {source_table}

### Target Entities
{target_tables}

### Selected Chain
{chain_selection.get('chain_id')}

### Composite Key Tables (Reference)
All tables starting with `ent_`, `sec_`, `str_`, `tac_` use composite keys (id, year).
All join tables (`jt_*`) use composite foreign keys referencing both columns.

---

## FEW-SHOT EXAMPLES

### Example 1: Single-Hop Query with Composite Key
**Query:** "Show projects for Entity ENT001 in 2024"

**Reasoning:**
- Source: ent_entities (ENT001, 2024)
- Target: ent_projects
- Path: ent_entities → jt_entity_projects → ent_projects
- Hops: 1
- Composite keys needed: 2 JOINs, 1 WHERE

**SQL:**
```sql
SELECT 
    p.id,
    p.year,
    p.name,
    p.status,
    p.start_date,
    p.end_date
FROM ent_entities e
JOIN jt_entity_projects ep 
    ON e.id = ep.entity_id 
    AND e.year = ep.entity_year
JOIN ent_projects p 
    ON ep.project_id = p.id 
    AND ep.project_year = p.year
WHERE e.id = 'ENT001' 
    AND e.year = 2024;
```

**Key Points:**
- ✅ Both JOINs use composite keys (id AND year)
- ✅ WHERE clause filters by both id and year
- ✅ All three conditions on composite key columns

---

### Example 2: Two-Hop Query with Composite Keys
**Query:** "Show capabilities for Project PRJ001 in 2024"

**Reasoning:**
- Source: ent_projects (PRJ001, 2024)
- Target: ent_capabilities
- Path: ent_projects → jt_project_capabilities → ent_capabilities
- Hops: 1
- Composite keys needed: 2 JOINs, 1 WHERE

**SQL:**
```sql
SELECT 
    c.id,
    c.year,
    c.name,
    c.description,
    c.maturity_level,
    c.target_level
FROM ent_projects p
JOIN jt_project_capabilities pc 
    ON p.id = pc.project_id 
    AND p.year = pc.project_year
JOIN ent_capabilities c 
    ON pc.capability_id = c.id 
    AND pc.capability_year = c.year
WHERE p.id = 'PRJ001' 
    AND p.year = 2024;
```

---

### Example 3: Three-Hop Cross-Domain Query
**Query:** "Show risks affecting IT systems used by Project PRJ001 in 2024"

**Reasoning:**
- Source: ent_projects (PRJ001, 2024)
- Target: sec_risks, ent_it_systems
- Path: ent_projects → jt_project_it_systems → ent_it_systems → jt_it_system_risks → sec_risks
- Hops: 3
- Composite keys needed: 4 JOINs, 1 WHERE

**SQL:**
```sql
SELECT 
    r.id,
    r.year,
    r.name AS risk_name,
    r.category,
    r.severity,
    r.status,
    its.id AS it_system_id,
    its.name AS it_system_name,
    its.criticality
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
```

**Key Points:**
- ✅ 4 JOINs, all using composite keys
- ✅ Each JOIN references both id AND year from previous table
- ✅ Complex 3-hop traversal successfully navigated

---

### Example 4: Temporal Comparison (Multi-Year)
**Query:** "Compare Entity ENT001 projects between 2023 and 2024"

**Reasoning:**
- Source: ent_entities (ENT001) - multiple years
- Target: ent_projects aggregated by year
- Path: Same as Example 1, but with year aggregation
- Special case: WHERE uses IN clause for multiple years

**SQL:**
```sql
SELECT 
    p.year,
    COUNT(*) as project_count,
    json_agg(
        json_build_object(
            'id', p.id, 
            'name', p.name,
            'status', p.status
        )
    ) as projects
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
```

**Key Points:**
- ✅ Composite keys maintained across years
- ✅ WHERE uses IN clause for multiple years (still includes year)
- ✅ GROUP BY year for comparison view

---

### Example 5: Four-Hop Complex Traversal
**Query:** "Trace tactics to operational risks through projects and capabilities for Strategy STR001"

**Reasoning:**
- Source: str_strategies (STR001, 2024)
- Target: sec_risks
- Path: str_strategies → jt_strategy_tactics → tac_tactics → jt_tactic_projects → ent_projects → jt_project_capabilities → ent_capabilities → jt_capability_risks → sec_risks
- Hops: 5 (complex cross-domain traversal)

**SQL:**
```sql
SELECT 
    s.name AS strategy_name,
    t.name AS tactic_name,
    p.name AS project_name,
    c.name AS capability_name,
    r.name AS risk_name,
    r.severity,
    r.status
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
```

**Key Points:**
- ✅ 8 JOINs, all using composite keys
- ✅ Successfully traces through 5 hops across 4 domains
- ✅ Demonstrates full VKG traversal capability

---

## YOUR TASK: GENERATE SQL QUERY

### Chain-of-Thought Reasoning Process

**Step 1:** Identify source entity and composite key
- Entity ID: {source_id}
- Entity Year: {source_year}
- Source Table: {source_table}

**Step 2:** Identify target entity/entities
- Target Tables: {target_tables}

**Step 3:** Extract path from World-View Map
- Chain ID: {chain_selection.get('chain_id')}

**Step 4:** Verify composite key availability
- Check: Does source table have (id, year)?
- Check: Does each join table have foreign key pairs?
- Check: Does target table have (id, year)?

**Step 5:** Construct JOIN chain
- Start with source table
- JOIN each intermediate table using composite keys
- End with target table

**Step 6:** Add WHERE clause with composite key filter
- MUST include both id AND year
- Use IN clause if multiple years needed

**Step 7:** Validate query
- Count JOINs: Should match hop count + 1
- Check composite keys: Every JOIN should have AND year clause
- Check WHERE: Should include year condition

---

## OUTPUT FORMAT

Return ONLY valid JSON:

```json
{{
  "reasoning": {{
    "source": "table_name (id, year)",
    "target": "table_name",
    "path": ["jt_table1", "jt_table2", "..."],
    "hops": 3,
    "composite_key_count": 4,
    "validation": "all JOINs use composite keys"
  }},
  "sql": "SELECT ... (complete query with proper formatting)"
}}
```

---

## VALIDATION CHECKLIST

Before returning SQL, verify:
- [ ] All JOINs reference both id AND year
- [ ] WHERE clause includes year condition
- [ ] Number of JOINs matches path length
- [ ] All composite key tables properly handled
- [ ] No single-column JOINs present
- [ ] Query follows one of the few-shot example patterns

**If validation fails, regenerate SQL with corrections.**

---

Generate the SQL query now."""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": "Generate the SQL query now with composite key compliance."}
        ]
        
        # RAW DEBUG LOGGING - Layer 2 (initial prompt)
        log_debug(2, "prompt_sent", {
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 1500
        })
        
        # Retry up to 3 times with validation feedback
        max_retries = 3
        for attempt in range(max_retries):
            try:
                response = await llm_provider.chat_completion(messages, temperature=0.2, max_tokens=1500)
                
                # RAW DEBUG LOGGING - Layer 2
                log_debug(2, "response_received", response)
                
                # Parse SQL response
                cleaned = response.strip()
                if cleaned.startswith("```json"):
                    cleaned = cleaned[7:]
                if cleaned.startswith("```"):
                    cleaned = cleaned[3:]
                if cleaned.endswith("```"):
                    cleaned = cleaned[:-3]
                cleaned = cleaned.strip()
                
                sql_response = json.loads(cleaned)
                
                # VALIDATION: Check composite key compliance
                assert self.validator is not None, "Validator should be initialized by _ensure_validator()"
                validation_result = self.validator.validate_query(sql_response)
                
                if validation_result["valid"]:
                    print(f"✅ SQL validated successfully on attempt {attempt + 1}")
                    if validation_result["warnings"]:
                        print(f"⚠️  Warnings: {validation_result['warnings']}")
                    return sql_response
                else:
                    print(f"❌ SQL validation failed on attempt {attempt + 1}")
                    print(f"   Errors: {validation_result['errors']}")
                    
                    if attempt < max_retries - 1:
                        # Provide validation feedback for retry
                        error_feedback = "\n".join([
                            f"VALIDATION ERROR {i+1}: {err}" 
                            for i, err in enumerate(validation_result['errors'])
                        ])
                        messages.append({
                            "role": "assistant",
                            "content": json.dumps(sql_response, indent=2)
                        })
                        messages.append({
                            "role": "user",
                            "content": f"The SQL query has composite key violations. Please fix these errors:\n\n{error_feedback}\n\nRegenerate the SQL query with these issues corrected."
                        })
                    else:
                        print(f"⚠️  Max retries reached. Returning invalid SQL (will fallback to hardcoded queries).")
                        return None
                        
            except Exception as e:
                print(f"⚠️ SQL generation failed on attempt {attempt + 1}: {e}")
                if attempt == max_retries - 1:
                    return None
        
        return None
    
    async def _generate_general_query_sql(self, intent: Dict[str, Any], target_entities: list, filters: dict) -> Optional[Dict[str, Any]]:
        """Generate simple SQL for general queries without specific entity references"""
        
        # For now, support single table queries
        if len(target_entities) == 0:
            return None
        
        target_table = target_entities[0]  # Primary target table
        year = filters.get("year", CURRENT_YEAR)
        status = filters.get("status")
        
        # Build simple SELECT query with composite key awareness
        query_parts = []
        query_parts.append(f"SELECT * FROM {target_table}")
        
        where_clauses = []
        where_clauses.append(f"year = {year}")
        
        if status:
            where_clauses.append(f"status = '{status}'")
        
        if where_clauses:
            query_parts.append("WHERE " + " AND ".join(where_clauses))
        
        # Add ORDER BY for consistent results
        query_parts.append(f"ORDER BY CAST(SUBSTRING(id FROM '^[0-9]+') AS INTEGER), id")
        
        sql = "\n".join(query_parts)
        
        # RAW DEBUG LOGGING - General Query SQL
        log_debug(2, "general_query_sql", {
            "target_table": target_table,
            "filters": filters,
            "sql": sql,
            "reasoning": f"General query for {target_table} with year={year}"
        })
        
        return {
            "sql": sql,
            "reasoning": f"General listing query for {target_table} filtered by year={year}" + (f" and status={status}" if status else "")
        }
    
    async def process(
        self, 
        intent: Dict[str, Any], 
        resolved_context: Optional[ResolvedContext] = None,
        context: Optional[Dict[str, Any]] = None
    ) -> tuple[Dict[str, Any], Optional[ResolvedContext]]:
        """Retrieve data from structured tables and knowledge graph - Returns (data, updated_context)"""
        
        # TRY: Generate SQL with composite keys if chain_selection available
        generated_sql = await self.generate_sql_with_composite_keys(intent)
        if generated_sql and "sql" in generated_sql:
            print(f"✅ Generated SQL with composite keys: {generated_sql['reasoning']}")
            
            # RAW DEBUG LOGGING - Layer 2 SQL
            log_debug(2, "sql_query", {
                "sql": generated_sql["sql"],
                "reasoning": generated_sql["reasoning"]
            })
            
            try:
                # Execute generated SQL
                results = await postgres_client.execute_query(generated_sql["sql"], [])
                
                # RAW DEBUG LOGGING - Layer 2 SQL Results
                log_debug(2, "sql_results", {
                    "row_count": len(results) if results else 0,
                    "sample_rows": results[:5] if results else [],
                    "full_results": results  # RAW - all data
                })
                
                # Enrich context with Layer 2 metadata
                if resolved_context:
                    resolved_context.layer_metadata["layer2_sql"] = generated_sql["sql"]
                    resolved_context.layer_metadata["layer2_sql_reasoning"] = generated_sql["reasoning"]
                    resolved_context.layer_metadata["layer2_data_sources"] = ["generated_query"]
                
                return {
                    "generated_query_results": results,
                    "sql": generated_sql["sql"],
                    "query_metadata": generated_sql["reasoning"]
                }, resolved_context
            except Exception as e:
                print(f"⚠️ Generated SQL failed to execute: {e}")
                # Fall through to hardcoded queries
        
        # FALLBACK: Use hardcoded queries if generation fails
        year = intent.get("time_period", {}).get("year", CURRENT_YEAR)
        quarter = intent.get("time_period", {}).get("quarter")
        entities = intent.get("entities", [])
        
        # RAW DEBUG LOGGING - Layer 2 Fallback
        log_debug(2, "fallback_triggered", {
            "reason": "Generated SQL unavailable or failed",
            "year": year,
            "quarter": quarter,
            "entities": entities,
            "intent_type": intent.get("intent_type")
        })
        
        retrieved_data = {}
        
        # Query structured entity tables with correct column names
        # ALWAYS query projects for fallback (don't rely on entity mentions or intent_type)
        query = """
            SELECT id, year, quarter, name, status, progress_percentage, 
                   budget, start_date, end_date, level
            FROM ent_projects 
            WHERE year = $1
            ORDER BY CAST(SUBSTRING(id FROM '^[0-9]+') AS INTEGER), id
        """
        
        # RAW DEBUG LOGGING - Fallback SQL
        log_debug(2, "fallback_sql_projects", {
            "query": query,
            "params": [year],
            "warning": "NO LIMIT - Returning ALL projects for the year"
        })
        
        projects = await postgres_client.execute_query(query, [year])
        retrieved_data["projects"] = projects
        
        # RAW DEBUG LOGGING - Fallback SQL Results
        log_debug(2, "fallback_sql_results_projects", {
            "row_count": len(projects) if projects else 0,
            "full_results": projects
        })
        
        # ALWAYS query capabilities for fallback
        query = """
            SELECT id, year, name, maturity_level, status, level
            FROM ent_capabilities 
            WHERE year = $1
            ORDER BY CAST(SUBSTRING(id FROM '^[0-9]+') AS INTEGER), id
        """
        capabilities = await postgres_client.execute_query(query, [year])
        retrieved_data["capabilities"] = capabilities
        
        # ALWAYS query objectives for fallback
        query = """
            SELECT id, year, name, level, status, expected_outcomes, priority_level
            FROM sec_objectives 
            WHERE year = $1
        """
        objectives = await postgres_client.execute_query(query, [year])
        retrieved_data["objectives"] = objectives
        
        # Query knowledge graph for rich relationships and context
        try:
            # Get relevant KG nodes
            kg_types = ["ent_projects", "ent_capabilities", "ent_risks", "sec_objectives"]
            kg_nodes = await postgres_client.query_knowledge_graph(entity_types=kg_types, limit=50)
            if kg_nodes:
                retrieved_data["knowledge_graph_nodes"] = kg_nodes
            
            # Get key relationships from KG
            key_rels = [
                "jt_ent_capabilities_ent_processes_join",
                "jt_ent_projects_ent_change_adoption_join",
                "jt_sec_performance_ent_capabilities_join"
            ]
            kg_edges = await postgres_client.query_knowledge_graph_relationships(rel_types=key_rels, limit=100)
            if kg_edges:
                retrieved_data["knowledge_graph_relationships"] = kg_edges
        except Exception as e:
            # KG query failed, continue with structured data only
            retrieved_data["kg_error"] = str(e)
        
        retrieved_data["query_metadata"] = {
            "year": year,
            "quarter": quarter,
            "data_sources": list(retrieved_data.keys())
        }
        
        # Enrich context with Layer 2 metadata (fallback path)
        if resolved_context:
            resolved_context.layer_metadata["layer2_fallback"] = True
            resolved_context.layer_metadata["layer2_data_sources"] = list(retrieved_data.keys())
            resolved_context.layer_metadata["layer2_year"] = year
        
        return retrieved_data, resolved_context


class AnalyticalReasoningMemory:
    """Layer 3: Analyze data and generate insights"""
    
    async def process(
        self, 
        question: str, 
        intent: Dict[str, Any], 
        retrieved_data: Dict[str, Any],
        resolved_context: Optional[ResolvedContext] = None,
        context: Optional[Dict[str, Any]] = None
    ) -> tuple[Dict[str, Any], Optional[ResolvedContext]]:
        """Perform analytical reasoning on retrieved data using DBA worldview approach - Returns (analysis, updated_context)"""
        
        worldview_summary = json.dumps(WORLDVIEW_MAP, indent=2)
        temporal_ctx = get_temporal_context()
        
        system_prompt = f"""You are an expert DBA for a temporal enterprise database. Your reasoning should be logical and educational, helping you understand and explain the rules and relationships that govern the data. The worldview map is provided for reference, but do not expose its internal details or technical terms to users.

TEMPORAL AWARENESS (CRITICAL):
- TODAY'S DATE: {temporal_ctx['current_date']}
- CURRENT YEAR: {temporal_ctx['current_year']}
- CURRENT QUARTER: Q{temporal_ctx['current_quarter']}
- When analyzing data, remember we are in {temporal_ctx['current_year']}
- Data from {temporal_ctx['current_year']} is CURRENT data
- Data from {temporal_ctx['current_year'] - 1} is HISTORICAL (1 year ago)
- Data from {temporal_ctx['current_year'] + 1}+ is FUTURE/PLANNED

WORLDVIEW MAP (DTDL Knowledge Graph Structure):
{worldview_summary}

GUIDING PRINCIPLES:
- Always select a single chain from the worldview map to guide your analysis. Chains represent valid flows of information and relationships. Do not invent alternate routes.
- When joining tables, ensure you match levels (L1 to L1, L2 to L2, L3 to L3) and use only the join tables and relationships defined in the worldview map. Exception: ent_risks may join directly to ent_capabilities via foreign key.
- All joins between tables with temporal keys must use both id and year. Always filter by year (default: {temporal_ctx['current_year']}) unless the user requests historical or future data.
- If a required join or data is missing, stop and explain the limitation in your analysis. Do not attempt unsupported chains or fabricate results.

WORKFLOW:
1) Announce your chosen chain and reasoning
2) Analyze the retrieved data using the chain relationships
3) Generate insights based on the worldview connections
4) Respond with clear JSON analysis and suggestions

TEMPORAL PATTERNS:
- Default/Current: year = {temporal_ctx['current_year']}
- Trends: year BETWEEN {temporal_ctx['current_year'] - 1} AND {temporal_ctx['current_year'] + 3}
- Historical: year < {temporal_ctx['current_year']}
- Future: year > {temporal_ctx['current_year']}

DOMAIN CONTEXT (Water Sector Transformation):
- Focus areas: Sustainability, environmental compliance, ESG standards, capability building
- Hierarchical structure: L1 (strategic), L2 (tactical), L3 (operational)
- Key entities: Projects (transformation initiatives), Capabilities (organizational skills), IT Systems, Strategic Objectives
- Knowledge Graph: 34,409 nodes and 42,084 relationships representing DTDL digital twin architecture

RESPONSE PROTOCOL:
Return valid JSON only:
{{
  "chain_selected": "name of chain from worldview map (e.g., '2A_Strategy_to_Tactics_Tools')",
  "chain_reasoning": "why this chain was chosen",
  "narrative": "STRUCTURED analysis using markdown formatting:
  - Use **bold** for key metrics and entities
  - Use bullet points (•) for lists
  - Use tables when comparing data
  - Start with executive summary (1-2 sentences)
  - Follow with detailed breakdown (bullets or numbered lists)
  - End with conclusion or recommendation
  
  Example format:
  **Executive Summary:** Projects show 75% completion with strong performance in Q4 {temporal_ctx['current_year']}.
  
  **Key Findings:**
  • Project Alpha: 85% complete, on track
  • Project Beta: 65% complete, needs attention
  • Resource allocation: Optimal for Q1 {temporal_ctx['current_year'] + 1}
  
  **Recommendation:** Focus resources on Project Beta to maintain timeline.",
  "key_insights": ["insight 1 with evidence", "insight 2 with evidence", "insight 3 with evidence"],
  "recommended_visualizations": ["chart_type1", "chart_type2"],
  "data_quality_warnings": ["warning if applicable"],
  "suggestions": ["actionable recommendation 1", "actionable recommendation 2"]
}}

EDUCATIONAL APPROACH:
- Always explain your reasoning, sources, and logic in the narrative
- Help the user understand how you arrived at your answer using the chain relationships
- Be specific with numbers, names, and statuses from actual data
- DON'T make up data - only use what's provided
- Never mention internal worldview rules or technical constraints to users"""
        
        data_summary = json.dumps(retrieved_data, default=str, indent=2)[:3000]
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"""Question: {question}

Intent: {json.dumps(intent, indent=2)}

Data Retrieved:
{data_summary}

Analyze and respond in JSON format."""}
        ]
        
        # RAW DEBUG LOGGING - Layer 3
        log_debug(3, "prompt_sent", {
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 2500
        })
        
        response = await llm_provider.chat_completion(messages, temperature=0.3, max_tokens=2500)
        
        # RAW DEBUG LOGGING - Layer 3
        log_debug(3, "response_received", response)
        
        # Strip markdown code fences if present (```json ... ```)
        cleaned_response = response.strip()
        if cleaned_response.startswith("```"):
            # Remove opening fence (```json or ```)
            lines = cleaned_response.split('\n')
            if lines[0].startswith("```"):
                lines = lines[1:]
            # Remove closing fence (```)
            if lines and lines[-1].strip() == "```":
                lines = lines[:-1]
            cleaned_response = '\n'.join(lines)
        
        # Fix invalid control characters (unescaped newlines, tabs, etc.)
        import re
        # Remove or escape control characters that break JSON
        cleaned_response = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', cleaned_response)
        
        try:
            analysis = json.loads(cleaned_response)
            # Ensure all expected fields exist
            if "chain_selected" not in analysis:
                analysis["chain_selected"] = "Unknown"
            if "chain_reasoning" not in analysis:
                analysis["chain_reasoning"] = "Chain not specified"
            if "suggestions" not in analysis:
                analysis["suggestions"] = []
            if "narrative" not in analysis:
                analysis["narrative"] = "Analysis completed based on available data."
        except Exception as e:
            # Fallback if JSON parsing fails - log the error
            print(f"⚠️ Layer 3 JSON parsing failed: {e}")
            print(f"Raw response: {response[:500]}")
            analysis = {
                "chain_selected": "Unknown",
                "chain_reasoning": "Unable to parse chain information",
                "narrative": "I analyzed the data but encountered a formatting issue. Please try rephrasing your question.",
                "key_insights": ["Analysis attempted but formatting error occurred"],
                "recommended_visualizations": ["bar"],
                "data_quality_warnings": ["Response parsing error"],
                "suggestions": []
            }
        
        # Enrich context with Layer 3 analytical insights
        if resolved_context:
            resolved_context.layer_metadata["layer3_chain_selected"] = analysis.get("chain_selected", "Unknown")
            resolved_context.layer_metadata["layer3_key_insights"] = analysis.get("key_insights", [])
            # Append this analysis to previous_results for cross-turn memory
            result_summary = {
                "chain": analysis.get("chain_selected"),
                "insights": analysis.get("key_insights", [])[:3]  # Top 3 insights
            }
            resolved_context.previous_results.append(result_summary)
            # Track exploration path
            if analysis.get("chain_selected") and analysis.get("chain_selected") != "Unknown":
                resolved_context.exploration_path.append(analysis["chain_selected"])
        
        return analysis, resolved_context


class VisualizationGenerationMemory:
    """Layer 4: Generate visualizations"""
    
    async def process(self, analysis: Dict[str, Any], retrieved_data: Dict[str, Any]) -> List[Visualization]:
        """Generate visualizations based on analysis"""
        
        visualizations = []
        
        try:
            import matplotlib
            matplotlib.use('Agg')
            import matplotlib.pyplot as plt
            
            if "projects" in retrieved_data and retrieved_data["projects"]:
                fig, ax = plt.subplots(figsize=(10, 6))
                
                projects = retrieved_data["projects"][:10]
                names = [p.get('name', 'Unknown')[:30] for p in projects]
                progress = [float(p.get('progress_percentage', 0) or 0) * 100 for p in projects]
                
                ax.barh(names, progress, color='#9C27B0')
                ax.set_xlabel('Progress (%)')
                ax.set_title('Project Progress Overview - JOSOOR Digital Twin')
                ax.set_xlim(0, 100)
                plt.tight_layout()
                
                buf = io.BytesIO()
                plt.savefig(buf, format='png', dpi=100, bbox_inches='tight')
                buf.seek(0)
                img_base64 = base64.b64encode(buf.read()).decode('utf-8')
                plt.close()
                
                visualizations.append(Visualization(
                    type="bar",
                    title="Project Progress Overview",
                    image_base64=img_base64,
                    description="Progress percentage for active projects"
                ))
        
        except Exception as e:
            pass
        
        return visualizations


class AutonomousAnalyticalAgent:
    """Main orchestrator for the 4-layer autonomous agent"""
    
    def __init__(self, conversation_manager=None):
        """Initialize agent with optional conversation_manager for optimization features"""
        self.conversation_manager = conversation_manager
        self.layer1 = IntentUnderstandingMemory(conversation_manager)
        self.layer2 = HybridRetrievalMemory()
        self.layer3 = AnalyticalReasoningMemory()
        self.layer4 = VisualizationGenerationMemory()
    
    async def _handle_simple_query(
        self, 
        question: str, 
        intent: Dict[str, Any],
        resolved_context: ResolvedContext,
        context: Optional[Dict[str, Any]] = None
    ) -> AgentResponse:
        """Handle simple queries with direct response and data retrieval (uses ResolvedContext)"""
        
        temporal_ctx = get_temporal_context()
        entities = intent.get("entities", [])
        
        # Build simple prompt for direct answers with data awareness
        system_prompt = f"""You are a helpful assistant for JOSOOR transformation analytics platform.

TEMPORAL CONTEXT:
- Current Date: {temporal_ctx['current_date']}
- Current Year: {temporal_ctx['current_year']}
- Current Quarter: Q{temporal_ctx['current_quarter']}

DOMAIN: Water sector transformation, sustainability, environmental compliance.

RESPONSE RULES:
- If asking for a list or specific data: Provide actual data from the available data section
- If asking a simple fact (like "what year?"): Respond in 1-2 sentences
- Be concise but include specific details (names, IDs, statuses) when data is available
- If no data provided but user asks for specific items, acknowledge you need more context"""

        # ALWAYS retrieve data if entities are present (even for simple queries)
        retrieved_data = {}
        if entities:
            # Retrieve data for simple queries with ResolvedContext
            retrieved_data, updated_context = await self.layer2.process(intent, resolved_context, context)
            if updated_context:
                resolved_context = updated_context
        
        # Generate simple response WITH data
        user_prompt = f"Question: {question}"
        if retrieved_data:
            # Include more data for simple queries (up to 2000 chars instead of 1000)
            data_summary = json.dumps(retrieved_data, default=str)[:2000]
            user_prompt += f"\n\nAvailable data:\n{data_summary}\n\nProvide a direct answer using the specific data above."
        else:
            user_prompt += "\n\nNo specific data available for this query."
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
        
        # RAW DEBUG LOGGING - Simple Query Handler
        log_debug(4, "prompt_sent", {
            "messages": messages,
            "temperature": 0.5,
            "max_tokens": 800,
            "note": "simple_query_handler"
        })
        
        narrative = await llm_provider.chat_completion(messages, temperature=0.5, max_tokens=800)
        
        # RAW DEBUG LOGGING - Simple Query Handler
        log_debug(4, "response_received", narrative)
        
        return AgentResponse(
            narrative=narrative,
            visualizations=[],
            confidence=ConfidenceInfo(
                level="high",
                score=0.95,
                warnings=[]
            ),
            metadata={
                "intent": intent,
                "routing": "simple_query",
                "entities_resolved": entities,
                "data_retrieved": bool(retrieved_data),
                "timestamp": datetime.now().isoformat()
            }
        )
    
    async def process_query(
        self, 
        question: str, 
        context: Optional[Dict[str, Any]] = None
    ) -> AgentResponse:
        """Process natural language question through all 4 layers with smart routing"""
        
        try:
            # LAYER 1: Understand intent and determine routing
            print("🔷 LAYER 1: IntentUnderstanding - Starting...")
            intent = await self.layer1.process(question, context)
            print(f"✅ LAYER 1: Complete - Intent: {intent.get('intent_type')}, Entities: {intent.get('entities')}")
            
            # CREATE RESOLVED CONTEXT from Layer 1 output
            # Extract user_id and conversation_id from context
            user_id = context.get("user_id", "unknown") if context else "unknown"
            conversation_id = context.get("conversation_id", "default") if context else "default"
            current_turn = context.get("current_turn", 1) if context else 1
            
            resolved_context = ResolvedContext.from_intent(
                intent=intent,
                user_id=user_id,
                conversation_id=conversation_id,
                current_turn=current_turn
            )
            
            # Store conversation history in context
            if context and "conversation_history" in context:
                resolved_context.layer_metadata["conversation_history"] = context["conversation_history"]
            
            print(f"✅ ResolvedContext created: {len(resolved_context.resolved_references)} refs, chain={resolved_context.selected_chain}")
            
            # CHECK FOR CLARIFICATION NEEDED
            confidence = intent.get("confidence", "high")
            clarification = intent.get("clarification_needed")
            
            if confidence == "low" and clarification:
                # EARLY EXIT: Ask clarifying question instead of processing
                return AgentResponse(
                    narrative=clarification,
                    visualizations=[],
                    confidence=ConfidenceInfo(
                        level="low",
                        score=0.3,
                        warnings=["Unclear intent - clarification requested"]
                    ),
                    metadata={
                        "intent": intent,
                        "routing": "clarification_needed",
                        "timestamp": datetime.now().isoformat()
                    }
                )
            
            # SMART ROUTING: Check if this is a simple query
            is_simple = intent.get("is_simple", False)
            
            if is_simple:
                # SHORT-CIRCUIT: Answer simple queries directly without full analysis
                print("⚡ SIMPLE QUERY ROUTE: Skipping layers 3-4")
                return await self._handle_simple_query(question, intent, resolved_context, context)
            
            # COMPLEX PATH: Full 4-layer processing with ResolvedContext
            print("🔷 LAYER 2: HybridRetrieval - Starting...")
            retrieved_data, resolved_context = await self.layer2.process(intent, resolved_context, context)
            print(f"✅ LAYER 2: Complete - Retrieved {len(retrieved_data)} data sources")
            
            print("🔷 LAYER 3: AnalyticalReasoning - Starting...")
            analysis, resolved_context = await self.layer3.process(question, intent, retrieved_data, resolved_context, context)
            print(f"✅ LAYER 3: Complete - Chain: {analysis.get('chain_selected')}")
            
            print("🔷 LAYER 4: VisualizationGeneration - Starting...")
            visualizations = await self.layer4.process(analysis, retrieved_data)
            print(f"✅ LAYER 4: Complete - Generated {len(visualizations)} visualizations")
            
            confidence_level = "high"
            confidence_score = 0.85
            warnings = analysis.get("data_quality_warnings", [])
            
            if not retrieved_data or len(str(retrieved_data)) < 100:
                confidence_level = "low"
                confidence_score = 0.4
                warnings.append("Limited data available for analysis")
            elif warnings:
                confidence_level = "medium"
                confidence_score = 0.65
            
            narrative = analysis.get("narrative", "Analysis completed based on available data.")
            
            return AgentResponse(
                narrative=narrative,
                visualizations=visualizations,
                confidence=ConfidenceInfo(
                    level=confidence_level,
                    score=confidence_score,
                    warnings=warnings
                ),
                metadata={
                    "intent": intent,
                    "resolved_context": resolved_context.to_dict() if resolved_context else {},
                    "data_sources": list(retrieved_data.keys()),
                    "chain_selected": analysis.get("chain_selected", "Unknown"),
                    "chain_reasoning": analysis.get("chain_reasoning", "Not specified"),
                    "suggestions": analysis.get("suggestions", []),
                    "key_insights": analysis.get("key_insights", []),
                    "timestamp": datetime.now().isoformat()
                }
            )
        
        except Exception as e:
            return AgentResponse(
                narrative=f"I encountered an issue while processing your question: {str(e)}. Please try rephrasing your question.",
                visualizations=[],
                confidence=ConfidenceInfo(
                    level="low",
                    score=0.1,
                    warnings=[f"Error: {str(e)}"]
                ),
                metadata={"error": str(e)}
            )

# Singleton for backward compatibility (initialized without conversation_manager)
# For optimized performance, instantiate with conversation_manager in chat.py
autonomous_agent = AutonomousAnalyticalAgent()
