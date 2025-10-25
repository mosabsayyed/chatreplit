from typing import List, Dict, Any, Optional
from app.services.llm_provider import llm_provider
from app.db.postgres_client import postgres_client
from app.models.schemas import AgentResponse, Visualization, ConfidenceInfo
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
        
        system_prompt = f"""You are analyzing questions for JOSOOR - an enterprise transformation analytics platform.

CONTEXT:
- Domain: Water sector transformation, sustainability, environmental compliance, organizational capability building
- Entity types: Projects (transformation initiatives), Capabilities (organizational skills), IT Systems, Processes, Strategic Objectives
- Data structure: Hierarchical (L1, L2, L3 levels), temporal (2024-2028), with relationships{conversation_history}

CONVERSATION MEMORY:
- Use the conversation history above to understand references like "it", "that", "them", "previous"
- If the user says "compare it", look for what was analyzed in previous messages
- Resolve pronouns and references based on conversation context

Extract from the user question:
1. intent_type: "dashboard_view", "drill_down", "comparison", "trend_analysis", "general_question"
2. entities: List of entities (e.g., ["ent_projects", "ent_capabilities", "sec_objectives"])
3. time_period: {{"year": int (default 2024 if not specified), "quarter": int or null}}
4. analysis_type: "descriptive", "diagnostic", "predictive", "prescriptive"
5. resolved_references: If question has "it", "that", etc., what do they refer to based on history?

Respond in JSON format only."""
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Question: {question}\n\nExtract intent as JSON."}
        ]
        
        response = await llm_provider.chat_completion(messages, temperature=0.3)
        
        try:
            intent = json.loads(response)
        except:
            intent = {
                "intent_type": "general_question",
                "entities": [],
                "time_period": {"year": 2024, "quarter": None},
                "analysis_type": "descriptive"
            }
        
        return intent


class HybridRetrievalMemory:
    """Layer 2: Retrieve relevant data from PostgreSQL + Knowledge Graph"""
    
    async def process(self, intent: Dict[str, Any], context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Retrieve data from structured tables and knowledge graph"""
        
        year = intent.get("time_period", {}).get("year", 2024)
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
                SELECT id, year, name, description
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
        
        system_prompt = f"""You are an expert DBA for a temporal enterprise database. Your reasoning should be logical and educational, helping you understand and explain the rules and relationships that govern the data. The worldview map is provided for reference, but do not expose its internal details or technical terms to users.

WORLDVIEW MAP (DTDL Knowledge Graph Structure):
{worldview_summary}

GUIDING PRINCIPLES:
- Always select a single chain from the worldview map to guide your analysis. Chains represent valid flows of information and relationships. Do not invent alternate routes.
- When joining tables, ensure you match levels (L1 to L1, L2 to L2, L3 to L3) and use only the join tables and relationships defined in the worldview map. Exception: ent_risks may join directly to ent_capabilities via foreign key.
- All joins between tables with temporal keys must use both id and year. Always filter by year (default: 2024) unless the user requests historical or future data.
- If a required join or data is missing, stop and explain the limitation in your analysis. Do not attempt unsupported chains or fabricate results.

WORKFLOW:
1) Announce your chosen chain and reasoning
2) Analyze the retrieved data using the chain relationships
3) Generate insights based on the worldview connections
4) Respond with clear JSON analysis and suggestions

TEMPORAL PATTERNS:
- Default: year = 2024
- Trends: year BETWEEN 2024 AND 2028
- Historical: year < 2024
- Future: year > 2024

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
        
        try:
            analysis = json.loads(response)
            # Ensure all expected fields exist
            if "chain_selected" not in analysis:
                analysis["chain_selected"] = "Unknown"
            if "chain_reasoning" not in analysis:
                analysis["chain_reasoning"] = "Chain not specified"
            if "suggestions" not in analysis:
                analysis["suggestions"] = []
        except:
            # Fallback if JSON parsing fails
            analysis = {
                "chain_selected": "Unknown",
                "chain_reasoning": "Unable to parse chain information",
                "narrative": response,
                "key_insights": ["Analysis completed based on available data"],
                "recommended_visualizations": ["bar"],
                "data_quality_warnings": [],
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
    
    async def process_query(
        self, 
        question: str, 
        context: Optional[Dict[str, Any]] = None
    ) -> AgentResponse:
        """Process natural language question through all 4 layers"""
        
        try:
            intent = await self.layer1.process(question, context)
            
            retrieved_data = await self.layer2.process(intent, context)
            
            analysis = await self.layer3.process(question, intent, retrieved_data, context)
            
            visualizations = await self.layer4.process(analysis, retrieved_data)
            
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
