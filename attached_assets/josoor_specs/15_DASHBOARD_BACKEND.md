# 15: DASHBOARD DATA GENERATION SERVICE

```yaml
META:
  version: 1.0
  status: EXTRACTED_FROM_EXISTING_SPEC
  priority: HIGH
  dependencies: [01_DATABASE_FOUNDATION, 06_AUTONOMOUS_AGENT_COMPLETE]
  implements: Dashboard generation service for 4-zone visualization
  file_location: backend/app/services/dashboard_generator.py
```

---

## **6\. DASHBOARD DATA GENERATION SERVICE**

This is the **core service** that calculates all 4 zones' data.

Copy  
\# app/services/dashboard\_generator.py  
from typing import Optional, Dict, List, Any  
from datetime import datetime  
from app.db.supabase\_client import SupabaseClient  
from app.db.redis\_client import RedisClient  
from app.services.dimension\_calculator import DimensionCalculator  
from app.services.autonomous\_agent import AutonomousAnalyticalAgent  
from app.models.schemas import (  
    DashboardResponse, DrillDownRequest, DrillDownResponse,  
    Zone1Data, Zone2Data, Zone3Data, Zone4Data  
)  
import json

class DashboardGenerator:  
    """  
    Generates master dashboard data for all 4 zones.  
    Handles caching and drill-down orchestration.  
    """  
      
    def \_\_init\_\_(  
        self,  
        supabase: SupabaseClient,  
        redis: RedisClient,  
        dimension\_calculator: DimensionCalculator,  
        autonomous\_agent: AutonomousAnalyticalAgent  
    ):  
        self.supabase \= supabase  
        self.redis \= redis  
        self.dimension\_calc \= dimension\_calculator  
        self.agent \= autonomous\_agent  
          
        \# Cache TTL: 15 minutes for dashboard data  
        self.dashboard\_cache\_ttl \= 900  
      
    async def generate\_dashboard(self, year: int, quarter: Optional\[str\] \= None) \-\> DashboardResponse:  
        """  
        Generate complete dashboard data for all 4 zones.  
        Uses Redis cache to avoid redundant calculations.  
        """  
          
        \# Check cache first  
        cache\_key \= f"dashboard:{year}:{quarter or 'all'}"  
        cached\_data \= self.redis.get(cache\_key)  
          
        if cached\_data:  
            print(f"\[Dashboard\] Cache hit for {cache\_key}")  
            data \= json.loads(cached\_data)  
            data\["cache\_hit"\] \= True  
            return DashboardResponse(\*\*data)  
          
        print(f"\[Dashboard\] Generating fresh data for year={year}, quarter={quarter}")  
          
        \# Generate each zone in parallel  
        import asyncio  
          
        zone1\_task \= asyncio.create\_task(self.\_generate\_zone1(year, quarter))  
        zone2\_task \= asyncio.create\_task(self.\_generate\_zone2(year, quarter))  
        zone3\_task \= asyncio.create\_task(self.\_generate\_zone3(year, quarter))  
        zone4\_task \= asyncio.create\_task(self.\_generate\_zone4(year, quarter))  
          
        zone1, zone2, zone3, zone4 \= await asyncio.gather(  
            zone1\_task, zone2\_task, zone3\_task, zone4\_task  
        )  
          
        dashboard\_data \= DashboardResponse(  
            year=year,  
            quarter=quarter,  
            zone1=zone1,  
            zone2=zone2,  
            zone3=zone3,  
            zone4=zone4,  
            generated\_at=datetime.now(),  
            cache\_hit=False  
        )  
          
        \# Cache the result  
        self.redis.set(  
            cache\_key,  
            dashboard\_data.json(),  
            ex=self.dashboard\_cache\_ttl  
        )  
          
        return dashboard\_data  
      
    async def \_generate\_zone1(self, year: int, quarter: Optional\[str\]) \-\> Zone1Data:  
        """  
        Zone 1: Transformation Health (Spider Chart with 8 Dimensions)  
        """  
          
        dimensions \= await self.dimension\_calc.calculate\_all\_dimensions(year, quarter)  
        overall\_health \= sum(d\["score"\] for d in dimensions) / len(dimensions)  
          
        return Zone1Data(  
            dimensions=dimensions,  
            overall\_health=overall\_health  
        )  
      
    async def \_generate\_zone2(self, year: int, quarter: Optional\[str\]) \-\> Zone2Data:  
        """  
        Zone 2: Strategic Insights (Bubble Chart: Objectives vs Projects)  
        """  
          
        \# Query: Projects with their objectives  
        query \= """  
        SELECT   
            p.id as project\_id,  
            p.project\_name,  
            p.progress\_percentage,  
            p.budget\_allocated,  
            o.id as objective\_id,  
            o.objective\_name,  
            o.achievement\_rate,  
            \-- Impact score: weighted combination of progress and achievement  
            (p.progress\_percentage \* 0.6 \+ o.achievement\_rate \* 0.4) as impact\_score  
        FROM ent\_projects p  
        INNER JOIN jt\_ent\_projects\_sec\_objectives\_join jt  
            ON p.id \= jt.projects\_id AND p.year \= jt.year  
        INNER JOIN sec\_objectives o  
            ON jt.objectives\_id \= o.id AND jt.year \= o.year  
        WHERE p.year \= $1  
            AND p.level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND p.quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
          
        bubbles \= \[  
            {  
                "id": row\["project\_id"\],  
                "name": row\["project\_name"\],  
                "x": row\["progress\_percentage"\],  
                "y": row\["impact\_score"\],  
                "z": float(row\["budget\_allocated"\]) / 1\_000\_000,  \# Millions  
                "objective\_id": row\["objective\_id"\],  
                "project\_id": row\["project\_id"\]  
            }  
            for row in result.data  
        \]  
          
        return Zone2Data(bubbles=bubbles)  
      
    async def \_generate\_zone3(self, year: int, quarter: Optional\[str\]) \-\> Zone3Data:  
        """  
        Zone 3: Internal Outputs (Bullet Charts: Capabilities, Processes, IT Systems)  
        """  
          
        metrics \= \[\]  
          
        \# Capability Maturity  
        cap\_query \= """  
        SELECT   
            AVG(maturity\_level) as current\_value,  
            4.0 as target\_value  
        FROM ent\_capabilities  
        WHERE year \= $1 AND level \= 'L1'  
        """  
        cap\_result \= await self.supabase.execute\_query(cap\_query, \[year\])  
        if cap\_result.data:  
            row \= cap\_result.data\[0\]  
            metrics.append({  
                "entity\_type": "Capabilities",  
                "current\_value": row\["current\_value"\],  
                "target\_value": row\["target\_value"\],  
                "performance\_percentage": (row\["current\_value"\] / row\["target\_value"\]) \* 100  
            })  
          
        \# Process Efficiency  
        proc\_query \= """  
        SELECT   
            AVG(efficiency\_score) as current\_value,  
            85.0 as target\_value  
        FROM ent\_processes  
        WHERE year \= $1 AND level \= 'L1'  
        """  
        proc\_result \= await self.supabase.execute\_query(proc\_query, \[year\])  
        if proc\_result.data:  
            row \= proc\_result.data\[0\]  
            metrics.append({  
                "entity\_type": "Processes",  
                "current\_value": row\["current\_value"\],  
                "target\_value": row\["target\_value"\],  
                "performance\_percentage": (row\["current\_value"\] / row\["target\_value"\]) \* 100  
            })  
          
        \# IT System Health  
        it\_query \= """  
        SELECT   
            AVG(health\_score) as current\_value,  
            90.0 as target\_value  
        FROM ent\_it\_systems  
        WHERE year \= $1 AND level \= 'L1'  
        """  
        it\_result \= await self.supabase.execute\_query(it\_query, \[year\])  
        if it\_result.data:  
            row \= it\_result.data\[0\]  
            metrics.append({  
                "entity\_type": "IT Systems",  
                "current\_value": row\["current\_value"\],  
                "target\_value": row\["target\_value"\],  
                "performance\_percentage": (row\["current\_value"\] / row\["target\_value"\]) \* 100  
            })  
          
        return Zone3Data(metrics=metrics)  
      
    async def \_generate\_zone4(self, year: int, quarter: Optional\[str\]) \-\> Zone4Data:  
        """  
        Zone 4: Sector Outcomes (Combo Chart: Performance across sectors)  
        """  
          
        outcomes \= \[\]  
          
        \# Citizen Satisfaction Trend  
        citizen\_query \= """  
        SELECT   
            quarter,  
            AVG(satisfaction\_score) as avg\_score,  
            80.0 as target\_value  
        FROM sec\_citizens  
        WHERE year \= $1 AND level \= 'L1'  
        GROUP BY quarter  
        ORDER BY quarter  
        """  
        citizen\_result \= await self.supabase.execute\_query(citizen\_query, \[year\])  
        if citizen\_result.data:  
            trend \= \[row\["avg\_score"\] for row in citizen\_result.data\]  
            outcomes.append({  
                "sector": "Citizens",  
                "kpi\_name": "Satisfaction Score",  
                "value": trend\[-1\] if trend else 0,  
                "target": 80.0,  
                "trend": trend  
            })  
          
        \# Business Satisfaction Trend  
        business\_query \= """  
        SELECT   
            quarter,  
            AVG(satisfaction\_score) as avg\_score,  
            75.0 as target\_value  
        FROM sec\_businesses  
        WHERE year \= $1 AND level \= 'L1'  
        GROUP BY quarter  
        ORDER BY quarter  
        """  
        business\_result \= await self.supabase.execute\_query(business\_query, \[year\])  
        if business\_result.data:  
            trend \= \[row\["avg\_score"\] for row in business\_result.data\]  
            outcomes.append({  
                "sector": "Businesses",  
                "kpi\_name": "Satisfaction Score",  
                "value": trend\[-1\] if trend else 0,  
                "target": 75.0,  
                "trend": trend  
            })  
          
        \# Transaction Success Rate  
        transaction\_query \= """  
        SELECT   
            quarter,  
            AVG(success\_rate) as avg\_rate,  
            95.0 as target\_value  
        FROM sec\_data\_transactions  
        WHERE year \= $1 AND level \= 'L1'  
        GROUP BY quarter  
        ORDER BY quarter  
        """  
        transaction\_result \= await self.supabase.execute\_query(transaction\_query, \[year\])  
        if transaction\_result.data:  
            trend \= \[row\["avg\_rate"\] for row in transaction\_result.data\]  
            outcomes.append({  
                "sector": "Transactions",  
                "kpi\_name": "Success Rate",  
                "value": trend\[-1\] if trend else 0,  
                "target": 95.0,  
                "trend": trend  
            })  
          
        return Zone4Data(outcomes=outcomes)  
      
    async def drill\_down(self, request: DrillDownRequest) \-\> DrillDownResponse:  
        """  
        Orchestrate drill-down analysis by routing to autonomous agent.  
        """  
          
        \# Construct context-aware question for agent  
        question \= self.\_construct\_drill\_down\_question(request)  
          
        \# Call autonomous agent  
        agent\_response \= await self.agent.answer\_question(  
            question=question,  
            context=request.context.dict()  
        )  
          
        \# Get related entities  
        related\_entities \= await self.\_get\_related\_entities(request.context)  
          
        \# Generate recommended actions  
        recommended\_actions \= self.\_generate\_recommendations(request, agent\_response)  
          
        return DrillDownResponse(  
            narrative=agent\_response\["narrative"\],  
            visualizations=agent\_response\["visualizations"\],  
            confidence=agent\_response\["confidence"\],  
            related\_entities=related\_entities,  
            recommended\_actions=recommended\_actions,  
            metadata=agent\_response\["metadata"\]  
        )  
      
    def \_construct\_drill\_down\_question(self, request: DrillDownRequest) \-\> str:  
        """  
        Convert drill-down request into natural language question for agent.  
        """  
          
        ctx \= request.context  
        zone \= request.zone  
        target \= request.target  
          
        if zone \== "transformation\_health":  
            return f"Show me detailed analysis of {target} performance in {ctx.year}. Include trends over quarters, contributing factors, and specific entities that need attention. Provide recommendations for improvement."  
          
        elif zone \== "strategic\_insights":  
            if ctx.entity\_table \== "ent\_projects":  
                return f"Analyze project '{target}' in {ctx.year}. Show its progress, linked objectives, budget utilization, key risks, and recommendations."  
            else:  
                return f"Analyze objective '{target}' in {ctx.year}. Show linked projects, achievement status, and gaps."  
          
        elif zone \== "internal\_outputs":  
            return f"Analyze {target} in {ctx.year}. Show performance metrics, trends, related entities, and improvement opportunities."  
          
        elif zone \== "sector\_outcomes":  
            return f"Analyze {target} outcomes in {ctx.year}. Show KPI trends, stakeholder breakdown, and policy impact."  
          
        else:  
            return f"Provide detailed analysis of {target} for {ctx.year}."  
      
    async def \_get\_related\_entities(self, context: DrillDownContext) \-\> List\[Dict\[str, Any\]\]:  
        """  
        Find entities related to the drill-down target using world-view map chains.  
        """  
          
        \# Use world-view map to find connected entities  
        \# Example: If drilling into "ent\_it\_systems", find related:  
        \# \- ent\_projects (via jt\_ent\_projects\_ent\_it\_systems\_join)  
        \# \- ent\_vendors (via jt\_ent\_it\_systems\_ent\_vendors\_join)  
        \# \- ent\_processes (via jt\_ent\_processes\_ent\_it\_systems\_join)  
          
        related \= \[\]  
          
        if context.entity\_table \== "ent\_it\_systems" and context.entity\_id:  
            \# Get related projects  
            query \= """  
            SELECT p.id, p.project\_name, 'Delivers' as relationship  
            FROM ent\_projects p  
            INNER JOIN jt\_ent\_projects\_ent\_it\_systems\_join jt  
                ON p.id \= jt.projects\_id AND p.year \= jt.year  
            WHERE jt.it\_systems\_id \= $1 AND jt.year \= $2  
            """  
            result \= await self.supabase.execute\_query(query, \[context.entity\_id, context.year\])  
            for row in result.data:  
                related.append({  
                    "entity\_type": "Project",  
                    "entity\_id": row\["id"\],  
                    "entity\_name": row\["project\_name"\],  
                    "relationship": row\["relationship"\]  
                })  
          
        return related  
      
    def \_generate\_recommendations(self, request: DrillDownRequest, agent\_response: Dict) \-\> List\[str\]:  
        """  
        Generate actionable recommendations based on analysis.  
        """  
          
        \# Extract from agent's insights  
        insights \= agent\_response.get("metadata", {}).get("insights", {})  
        recommendations \= insights.get("recommendations", \[\])  
          
        \# Add drill-down specific actions  
        if request.zone \== "transformation\_health":  
            recommendations.append(f"Export detailed report for {request.target}")  
            recommendations.append(f"Schedule review meeting with stakeholders")  
          
        return recommendations\[:5\]  \# Limit to top 5  
      
    async def get\_dimension\_details(self, dimension\_name: str, year: int, quarter: Optional\[str\]) \-\> Dict\[str, Any\]:  
        """  
        Get detailed breakdown of a specific health dimension.  
        """  
          
        dimension\_data \= await self.dimension\_calc.calculate\_single\_dimension(  
            dimension\_name=dimension\_name,  
            year=year,  
            quarter=quarter  
        )  
          
        return dimension\_data

---

## **7\. DIMENSION CALCULATOR**

This calculates the 8 health dimensions for Zone 1\.

Copy  
\# app/services/dimension\_calculator.py  
from typing import List, Dict, Optional, Any  
from app.db.supabase\_client import SupabaseClient  
from app.models.schemas import DimensionScore

class DimensionCalculator:  
    """  
    Calculates the 8 transformation health dimensions for spider chart (Zone 1).  
    """  
      
    def \_\_init\_\_(self, supabase: SupabaseClient):  
        self.supabase \= supabase  
          
        \# Dimension definitions  
        self.dimensions \= {  
            "Strategic Alignment": {  
                "description": "Objectives cascaded to operations",  
                "entity\_tables": \["sec\_objectives", "ent\_capabilities"\],  
                "target": 90,  
                "calculator": self.\_calc\_strategic\_alignment  
            },  
            "Project Delivery": {  
                "description": "Projects on time & budget",  
                "entity\_tables": \["ent\_projects"\],  
                "target": 85,  
                "calculator": self.\_calc\_project\_delivery  
            },  
            "Change Adoption": {  
                "description": "Behavioral changes embedded",  
                "entity\_tables": \["ent\_change\_adoption"\],  
                "target": 80,  
                "calculator": self.\_calc\_change\_adoption  
            },  
            "IT Modernization": {  
                "description": "Systems modernized & reliable",  
                "entity\_tables": \["ent\_it\_systems"\],  
                "target": 75,  
                "calculator": self.\_calc\_it\_modernization  
            },  
            "Capability Maturity": {  
                "description": "Business capabilities developed",  
                "entity\_tables": \["ent\_capabilities"\],  
                "target": 4,  \# Out of 5  
                "calculator": self.\_calc\_capability\_maturity  
            },  
            "Risk Management": {  
                "description": "Risks identified & mitigated",  
                "entity\_tables": \["ent\_risks"\],  
                "target": 95,  
                "calculator": self.\_calc\_risk\_management  
            },  
            "Culture Health": {  
                "description": "Organizational health index",  
                "entity\_tables": \["ent\_culture\_health"\],  
                "target": 70,  
                "calculator": self.\_calc\_culture\_health  
            },  
            "Citizen Impact": {  
                "description": "Sector-level outcomes delivered",  
                "entity\_tables": \["sec\_performance", "sec\_citizens"\],  
                "target": 80,  
                "calculator": self.\_calc\_citizen\_impact  
            }  
        }  
      
    async def calculate\_all\_dimensions(self, year: int, quarter: Optional\[str\]) \-\> List\[DimensionScore\]:  
        """  
        Calculate all 8 dimensions in parallel.  
        """  
          
        import asyncio  
          
        tasks \= \[  
            asyncio.create\_task(self.calculate\_single\_dimension(dim\_name, year, quarter))  
            for dim\_name in self.dimensions.keys()  
        \]  
          
        results \= await asyncio.gather(\*tasks)  
          
        return \[DimensionScore(\*\*r) for r in results\]  
      
    async def calculate\_single\_dimension(self, dimension\_name: str, year: int, quarter: Optional\[str\]) \-\> Dict\[str, Any\]:  
        """  
        Calculate a single dimension score.  
        """  
          
        if dimension\_name not in self.dimensions:  
            raise ValueError(f"Unknown dimension: {dimension\_name}")  
          
        dim\_def \= self.dimensions\[dimension\_name\]  
          
        \# Call dimension-specific calculator  
        score \= await dim\_def\["calculator"\](year, quarter)  
          
        \# Determine trend (compare to previous period)  
        previous\_score \= await dim\_def\["calculator"\](year \- 1, quarter) if year \> 2020 else score  
          
        if score \> previous\_score \+ 5:  
            trend \= "improving"  
        elif score \< previous\_score \- 5:  
            trend \= "declining"  
        else:  
            trend \= "stable"  
          
        return {  
            "name": dimension\_name,  
            "score": round(score, 1),  
            "target": dim\_def\["target"\],  
            "description": dim\_def\["description"\],  
            "entity\_tables": dim\_def\["entity\_tables"\],  
            "trend": trend  
        }  
      
    \# \========== DIMENSION-SPECIFIC CALCULATORS \==========  
      
    async def \_calc\_strategic\_alignment(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Strategic Alignment \= % of L1 objectives with L2/L3 cascade  
        """  
          
        query \= """  
        WITH l1\_objectives AS (  
            SELECT id FROM sec\_objectives WHERE year \= $1 AND level \= 'L1'  
        ),  
        cascaded\_objectives AS (  
            SELECT DISTINCT parent\_id   
            FROM sec\_objectives   
            WHERE year \= $1 AND level IN ('L2', 'L3') AND parent\_id IS NOT NULL  
        )  
        SELECT   
            (COUNT(DISTINCT c.parent\_id)::FLOAT / NULLIF(COUNT(DISTINCT l1.id), 0)) \* 100 as score  
        FROM l1\_objectives l1  
        LEFT JOIN cascaded\_objectives c ON l1.id \= c.parent\_id  
        """  
          
        result \= await self.supabase.execute\_query(query, \[year\])  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_project\_delivery(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Project Delivery \= % of projects completed or on-track (progress \>= 80%)  
        """  
          
        query \= """  
        SELECT   
            (COUNT(CASE WHEN status \= 'completed' OR progress\_percentage \>= 80 THEN 1 END)::FLOAT /   
             NULLIF(COUNT(\*), 0)) \* 100 as score  
        FROM ent\_projects  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_change\_adoption(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Change Adoption \= Average adoption rate across all domains  
        """  
          
        query \= """  
        SELECT AVG(adoption\_rate) as score  
        FROM ent\_change\_adoption  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_it\_modernization(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        IT Modernization \= % cloud-enabled systems with uptime \> 99%  
        """  
          
        query \= """  
        SELECT   
            (COUNT(CASE WHEN system\_type \= 'cloud' AND uptime\_percentage \>= 99 THEN 1 END)::FLOAT /   
             NULLIF(COUNT(\*), 0)) \* 100 as score  
        FROM ent\_it\_systems  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_capability\_maturity(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Capability Maturity \= Average maturity level (1-5 scale) \* 20 to normalize to 0-100  
        """  
          
        query \= """  
        SELECT AVG(maturity\_level) \* 20 as score  
        FROM ent\_capabilities  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_risk\_management(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Risk Management \= % of high/critical risks (score \>= 6\) with active mitigation  
        """  
          
        query \= """  
        SELECT   
            (COUNT(CASE WHEN risk\_score \>= 6 AND mitigation\_status IN ('mitigating', 'mitigated') THEN 1 END)::FLOAT /   
             NULLIF(COUNT(CASE WHEN risk\_score \>= 6 THEN 1 END), 0)) \* 100 as score  
        FROM ent\_risks  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_culture\_health(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Culture Health \= Average OHI score across all units  
        """  
          
        query \= """  
        SELECT AVG(ohi\_score) as score  
        FROM ent\_culture\_health  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        result \= await self.supabase.execute\_query(query, params)  
        return result.data\[0\]\["score"\] if result.data else 0.0  
      
    async def \_calc\_citizen\_impact(self, year: int, quarter: Optional\[str\]) \-\> float:  
        """  
        Citizen Impact \= Weighted average of:  
        \- 60%: % KPIs meeting target  
        \- 40%: Average citizen satisfaction  
        """  
          
        \# KPIs meeting target  
        kpi\_query \= """  
        SELECT   
            (COUNT(CASE WHEN kpi\_value \>= target\_value THEN 1 END)::FLOAT /   
             NULLIF(COUNT(\*), 0)) \* 100 as kpi\_score  
        FROM sec\_performance  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        \# Citizen satisfaction  
        citizen\_query \= """  
        SELECT AVG(satisfaction\_score) as citizen\_score  
        FROM sec\_citizens  
        WHERE year \= $1 AND level \= 'L1'  
        """  
          
        params \= \[year\]  
        if quarter:  
            kpi\_query \+= " AND quarter \= $2"  
            citizen\_query \+= " AND quarter \= $2"  
            params.append(quarter)  
          
        kpi\_result \= await self.supabase.execute\_query(kpi\_query, params)  
        citizen\_result \= await self.supabase.execute\_query(citizen\_query, params)  
          
        kpi\_score \= kpi\_result.data\[0\]\["kpi\_score"\] if kpi\_result.data else 0  
        citizen\_score \= citizen\_result.data\[0\]\["citizen\_score"\] if citizen\_result.data else 0  
          
        \# Weighted average  
        return (kpi\_score \* 0.6) \+ (citizen\_score \* 0.4)



---

**DOCUMENT STATUS:** ✅ COMPLETE - Extracted from existing comprehensive spec
