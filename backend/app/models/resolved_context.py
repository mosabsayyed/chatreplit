"""
JOSOOR Optimization: ResolvedContext Structure
Version: 1.0
Purpose: Comprehensive context object passed across all agent layers

This structure ensures consistent context sharing between Layer 1 (Intent),
Layer 2 (Retrieval), and Layer 3 (Analysis) to maintain conversation continuity
and enable accurate composite key resolution.
"""

from dataclasses import dataclass, field
from typing import List, Dict, Any
from datetime import datetime


@dataclass
class ResolvedContext:
    """
    Comprehensive context object passed across all agent layers.
    
    This object carries all necessary information from Layer 1 through Layer 3,
    ensuring composite key resolution, conversation memory, and accurate
    SQL generation across the entire agent pipeline.
    """
    # User context
    user_id: str
    conversation_id: str
    current_turn: int
    
    # Intent analysis (Layer 1 output)
    user_intent: str
    entity_mentions: List[Dict]  # Raw entity extraction
    resolved_references: List[Dict]  # Composite key tuples (id, year)
    selected_chain: str  # World-View Map chain
    required_hops: int  # Estimated path length
    
    # Query context
    target_entities: List[str]  # Target tables
    filters: Dict[str, Any]
    temporal_scope: Dict[str, Any]  # year range, comparison mode
    
    # Conversation memory
    previous_results: List[Dict] = field(default_factory=list)  # Last N query results
    entity_cache: Dict[str, Dict] = field(default_factory=dict)  # Known entities (composite keys)
    exploration_path: List[str] = field(default_factory=list)  # User's navigation history
    
    # Metadata
    timestamp: datetime = field(default_factory=datetime.utcnow)
    layer_metadata: Dict[str, Any] = field(default_factory=dict)  # Layer-specific data
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert context to dictionary for serialization"""
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
            "timestamp": self.timestamp.isoformat(),
            "layer_metadata": self.layer_metadata
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ResolvedContext':
        """Create context from dictionary"""
        data_copy = data.copy()
        if "timestamp" in data_copy and isinstance(data_copy["timestamp"], str):
            data_copy["timestamp"] = datetime.fromisoformat(data_copy["timestamp"])
        return cls(**data_copy)
    
    @classmethod
    def from_intent(
        cls,
        intent: Dict[str, Any],
        user_id: str,
        conversation_id: str,
        current_turn: int,
        conversation_history: List[Dict] = None
    ) -> 'ResolvedContext':
        """
        Create ResolvedContext from Layer 1 intent output.
        This is a convenience method for backwards compatibility.
        """
        return cls(
            user_id=user_id,
            conversation_id=conversation_id,
            current_turn=current_turn,
            user_intent=intent.get("user_intent", "unknown"),
            entity_mentions=intent.get("entity_mentions", []),
            resolved_references=intent.get("resolved_references", []),
            selected_chain=intent.get("chain_selection", {}).get("chain_id", ""),
            required_hops=intent.get("chain_selection", {}).get("estimated_hops", 0),
            target_entities=intent.get("target_entities", []),
            filters=intent.get("filters", {}),
            temporal_scope=intent.get("temporal_scope", {}),
            previous_results=[],
            entity_cache={},
            exploration_path=[],
            timestamp=datetime.utcnow(),
            layer_metadata={}
        )
