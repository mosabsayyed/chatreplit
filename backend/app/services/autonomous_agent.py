from typing import List, Dict, Any, Optional
from app.services.llm_provider import llm_provider
from app.db.postgres_client import postgres_client
from app.models.schemas import AgentResponse, Visualization, ConfidenceInfo
from app.utils.temporal import get_current_year, get_temporal_context, CURRENT_YEAR
import json
import base64
import io
from datetime import datetime
from pathlib import Path

# Load worldview map (DTDL knowledge graph structure)
WORLDVIEW_MAP_PATH = Path(__file__).parent.parent / "config" / "worldview_map.json"
with open(WORLDVIEW_MAP_PATH, 'r') as f:
    WORLDVIEW_MAP = json.load(f)

class IntentUnderstandingMemory:
    """Layer 1: Extract intent from user query"""
    
    async def process(self, question: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Analyze question and extract intent, entities, time period WITH CONVERSATION MEMORY"""
        
        # Get conversation history if available
        conversation_history = ""
        if context and "conversation_history" in context:
            conversation_history = f"\n\nCONVERSATION HISTORY:\n{context['conversation_history']}"
        
        # Get current temporal context
        temporal_ctx = get_temporal_context()
        
        system_prompt = f"""You are analyzing questions for JOSOOR - an enterprise transformation analytics platform.

TEMPORAL AWARENESS (CRITICAL):
- TODAY'S DATE: {temporal_ctx['current_date']}
- CURRENT YEAR: {temporal_ctx['current_year']}
- CURRENT QUARTER: Q{temporal_ctx['current_quarter']}
- Analysis timeframe: 2024-2028
- When user asks about "current" or "this year", they mean {temporal_ctx['current_year']}
- Historical data: < {temporal_ctx['current_year']}
- Future projections: > {temporal_ctx['current_year']}

CONTEXT:
- Domain: Water sector transformation, sustainability, environmental compliance, organizational capability building
- Entity types: Projects (transformation initiatives), Capabilities (organizational skills), IT Systems, Processes, Strategic Objectives
- Data structure: Hierarchical (L1, L2, L3 levels), temporal (2024-2028), with relationships{conversation_history}

CONVERSATION MEMORY (CRITICAL):
- Use the conversation history above to understand references like "it", "that", "them", "previous", "list them"
- If the user says "compare it", look for what was analyzed in previous messages
- If the user says "list them" or "show them", extract the entities from the previous question
- Resolve pronouns and references based on conversation context
- EXAMPLE: If previous was "how many capabilities in 2025?" and current is "list them", then entities=["ent_capabilities"]

Extract from the user question:
1. intent_type: "dashboard_view", "drill_down", "comparison", "trend_analysis", "general_question"
2. entities: List of entities (e.g., ["ent_projects", "ent_capabilities", "sec_objectives"]) - MUST resolve from conversation history if pronouns used
3. time_period: {{"year": int (default {temporal_ctx['current_year']} if not specified), "quarter": int or null}}
4. analysis_type: "descriptive", "diagnostic", "predictive", "prescriptive"
5. resolved_references: If question has "it", "that", etc., what do they refer to based on history?
6. is_simple: boolean - TRUE if query is simple (one entity/table, direct lookup, or metadata question), FALSE if complex (multiple entities, comparisons)
7. confidence: "high" (clear intent), "medium" (partial understanding), "low" (unclear - need clarification)
8. clarification_needed: string or null - If confidence is low, what clarifying question should be asked?

ROUTING LOGIC:
- is_simple = TRUE: Single entity query, metadata question, direct lookups → Skip complex analysis layers
- is_simple = FALSE: Multiple entities, comparisons, trend analysis, worldview chains needed → Full 4-layer processing

Examples:
- "What year is it?" → is_simple: true
- "Show me projects" → is_simple: true  
- "Compare capabilities with objectives" → is_simple: false
- "What are trends in sustainability?" → is_simple: false

Respond in JSON format only."""
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Question: {question}\n\nExtract intent as JSON."}
        ]
        
        response = await llm_provider.chat_completion(messages, temperature=0.3)
        
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
    """Layer 2: Retrieve relevant data from PostgreSQL + Knowledge Graph"""
    
    async def process(self, intent: Dict[str, Any], context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Retrieve data from structured tables and knowledge graph"""
        
        year = intent.get("time_period", {}).get("year", CURRENT_YEAR)
        quarter = intent.get("time_period", {}).get("quarter")
        entities = intent.get("entities", [])
        
        retrieved_data = {}
        
        # Query structured entity tables with correct column names
        if "ent_projects" in str(entities).lower() or intent.get("intent_type") in ["dashboard_view", "general_question"]:
            query = """
                SELECT id, year, quarter, name, status, progress_percentage, 
                       budget, start_date, end_date, level
                FROM ent_projects 
                WHERE year = $1
                ORDER BY CAST(SUBSTRING(id FROM '^[0-9]+') AS INTEGER), id
                LIMIT 20
            """
            projects = await postgres_client.execute_query(query, [year])
            retrieved_data["projects"] = projects
        
        if "ent_capabilities" in str(entities).lower() or intent.get("intent_type") in ["dashboard_view"]:
            query = """
                SELECT id, year, name, maturity_level, status, level
                FROM ent_capabilities 
                WHERE year = $1
                ORDER BY CAST(SUBSTRING(id FROM '^[0-9]+') AS INTEGER), id
                LIMIT 20
            """
            capabilities = await postgres_client.execute_query(query, [year])
            retrieved_data["capabilities"] = capabilities
        
        if "sec_objectives" in str(entities).lower() or intent.get("intent_type") in ["dashboard_view"]:
            query = """
                SELECT id, year, name, level, status, expected_outcomes, priority_level
                FROM sec_objectives 
                WHERE year = $1
                LIMIT 20
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
        
        return retrieved_data


class AnalyticalReasoningMemory:
    """Layer 3: Analyze data and generate insights"""
    
    async def process(
        self, 
        question: str, 
        intent: Dict[str, Any], 
        retrieved_data: Dict[str, Any],
        context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Perform analytical reasoning on retrieved data using DBA worldview approach"""
        
        worldview_summary = json.dumps(WORLDVIEW_MAP, indent=2)
        temporal_ctx = get_temporal_context()
        
        system_prompt = f"""You are an expert DBA for a temporal enterprise database. Your reasoning should be logical and educational, helping you understand and explain the rules and relationships that govern the data. The worldview map is provided for reference, but do not expose its internal details or technical terms to users.

TEMPORAL AWARENESS (CRITICAL):
- TODAY'S DATE: {temporal_ctx['current_date']}
- CURRENT YEAR: {temporal_ctx['current_year']}
- CURRENT QUARTER: Q{temporal_ctx['current_quarter']}
- When analyzing data, remember we are in {temporal_ctx['current_year']}, not 2024
- Data from {temporal_ctx['current_year']} is CURRENT data
- Data from 2024 is HISTORICAL (1 year ago)
- Data from 2026+ is FUTURE/PLANNED

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
- Trends: year BETWEEN 2024 AND 2028
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
  "narrative": "Clear, professional analysis (2-3 paragraphs) using specific data points and chain relationships",
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
        
        response = await llm_provider.chat_completion(messages, temperature=0.3, max_tokens=2500)
        
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
        
        return analysis


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
    
    def __init__(self):
        self.layer1 = IntentUnderstandingMemory()
        self.layer2 = HybridRetrievalMemory()
        self.layer3 = AnalyticalReasoningMemory()
        self.layer4 = VisualizationGenerationMemory()
    
    async def _handle_simple_query(
        self, 
        question: str, 
        intent: Dict[str, Any],
        context: Optional[Dict[str, Any]] = None
    ) -> AgentResponse:
        """Handle simple queries with direct response and data retrieval"""
        
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
            # Retrieve data for simple queries
            retrieved_data = await self.layer2.process(intent, context)
        
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
        
        narrative = await llm_provider.chat_completion(messages, temperature=0.5, max_tokens=800)
        
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
                return await self._handle_simple_query(question, intent, context)
            
            # COMPLEX PATH: Full 4-layer processing
            print("🔷 LAYER 2: HybridRetrieval - Starting...")
            retrieved_data = await self.layer2.process(intent, context)
            print(f"✅ LAYER 2: Complete - Retrieved {len(retrieved_data)} data sources")
            
            print("🔷 LAYER 3: AnalyticalReasoning - Starting...")
            analysis = await self.layer3.process(question, intent, retrieved_data, context)
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

autonomous_agent = AutonomousAnalyticalAgent()
