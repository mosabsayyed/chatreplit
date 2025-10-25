from typing import List, Dict, Any, Optional
from app.services.llm_provider import llm_provider
from app.db.postgres_client import postgres_client
from app.models.schemas import AgentResponse, Visualization, ConfidenceInfo
import json
import base64
import io
from datetime import datetime

class IntentUnderstandingMemory:
    """Layer 1: Extract intent from user query"""
    
    async def process(self, question: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Analyze question and extract intent, entities, time period"""
        
        system_prompt = """You are an intent understanding system for JOSOOR transformation analytics.
Extract the following from the user question:
1. intent_type: "dashboard_view", "drill_down", "comparison", "trend_analysis", "general_question"
2. entities: List of entities mentioned (e.g., ["ent_projects", "sec_objectives"])
3. time_period: {"year": int, "quarter": str or null}
4. analysis_type: "descriptive", "diagnostic", "predictive", "prescriptive"

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
        """Perform analytical reasoning on retrieved data"""
        
        system_prompt = """You are an expert enterprise transformation analyst for JOSOOR.
Analyze the provided data and generate insights to answer the user's question.

Provide:
1. narrative: Clear, concise narrative answer (2-3 paragraphs)
2. key_insights: List of 3-5 key insights
3. recommended_visualizations: List of chart types needed (e.g., "bar", "line", "spider", "bubble")
4. data_quality_warnings: Any data quality issues found

Respond in JSON format."""
        
        data_summary = json.dumps(retrieved_data, default=str, indent=2)[:3000]
        
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"""Question: {question}

Intent: {json.dumps(intent, indent=2)}

Data Retrieved:
{data_summary}

Analyze and respond in JSON format."""}
        ]
        
        response = await llm_provider.chat_completion(messages, temperature=0.5, max_tokens=1500)
        
        try:
            analysis = json.loads(response)
        except:
            analysis = {
                "narrative": response,
                "key_insights": ["Analysis completed based on available data"],
                "recommended_visualizations": ["bar"],
                "data_quality_warnings": []
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
