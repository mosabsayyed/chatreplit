# backend/app/utils/temporal.py
from datetime import datetime, timezone

def get_current_year() -> int:
    """
    Get the current year for temporal analysis.
    
    CRITICAL: This ensures the system is always aware of the current year
    for temporal data queries (2024-2028 timeframe).
    
    Returns:
        Current year as integer (e.g., 2025)
    """
    return datetime.now(timezone.utc).year


def get_current_quarter() -> int:
    """
    Get the current quarter (1-4).
    
    Returns:
        Quarter number: 1 (Jan-Mar), 2 (Apr-Jun), 3 (Jul-Sep), 4 (Oct-Dec)
    """
    month = datetime.now(timezone.utc).month
    return (month - 1) // 3 + 1


def get_temporal_context() -> dict:
    """
    Get comprehensive temporal context for the agent.
    
    Returns:
        Dict with current_year, current_quarter, current_date, temporal_scope
    """
    now = datetime.now(timezone.utc)
    return {
        "current_year": now.year,
        "current_quarter": get_current_quarter(),
        "current_date": now.strftime("%Y-%m-%d"),
        "current_datetime": now.isoformat(),
        "temporal_scope": {
            "past": f"< {now.year}",
            "current": now.year,
            "future": f"> {now.year}",
            "analysis_range": "2024-2028"
        }
    }


# Constants for temporal awareness
CURRENT_YEAR = get_current_year()  # 2025
CURRENT_QUARTER = get_current_quarter()  # 4 (October is Q4)
ANALYSIS_START_YEAR = 2024
ANALYSIS_END_YEAR = 2028
