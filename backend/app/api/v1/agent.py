from fastapi import APIRouter, HTTPException
from app.models.schemas import AgentRequest, AgentResponse
from app.services.autonomous_agent import autonomous_agent

router = APIRouter()

@router.post("/ask", response_model=AgentResponse)
async def ask_agent(request: AgentRequest):
    """
    Ask the autonomous analytical agent a question.
    
    The agent will:
    1. Understand your intent
    2. Retrieve relevant data from PostgreSQL
    3. Analyze and generate insights
    4. Create visualizations
    
    Example questions:
    - "What is the overall transformation health for 2024?"
    - "Show me project progress for digital initiatives"
    - "Which capabilities have the lowest maturity?"
    """
    try:
        response = await autonomous_agent.process_query(
            question=request.question,
            context=request.context
        )
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
