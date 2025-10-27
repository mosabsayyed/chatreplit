import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

class DebugLogger:
    """RAW debug logger for agent layer outputs - captures everything unfiltered"""
    
    def __init__(self, conversation_id: str):
        self.conversation_id = conversation_id
        self.log_dir = Path(__file__).parent.parent.parent / "logs"
        self.log_dir.mkdir(exist_ok=True)
        
        # Remove timestamp from filename so same file is reused for all turns in conversation
        self.log_file = self.log_dir / f"chat_debug_{conversation_id}.json"
        
        # Try to load existing log file if it exists (for multi-turn conversations)
        if self.log_file.exists():
            try:
                with open(self.log_file, 'r') as f:
                    self.log_data = json.load(f)
                # Add metadata for this turn
                if "turns" not in self.log_data:
                    self.log_data["turns"] = []
                self.log_data["turns"].append({
                    "timestamp": datetime.now().isoformat(),
                    "turn_number": len(self.log_data["turns"]) + 1
                })
            except Exception as e:
                # If file exists but can't be read, start fresh
                print(f"Warning: Could not load existing log file: {e}")
                self._initialize_fresh_log_data()
        else:
            # Initialize new log file with empty structure
            self._initialize_fresh_log_data()
        
        self._write_to_file()
    
    def _initialize_fresh_log_data(self):
        """Initialize fresh log data structure"""
        self.log_data = {
            "conversation_id": self.conversation_id,
            "created_at": datetime.now().isoformat(),
            "turns": [{
                "timestamp": datetime.now().isoformat(),
                "turn_number": 1
            }],
            "layers": {
                "layer1": {"events": []},
                "layer2": {"events": []},
                "layer3": {"events": []},
                "layer4": {"events": []}
            }
        }
    
    def log_layer(self, layer_num: int, event_type: str, data: Any):
        """
        Log RAW data for a specific layer event.
        
        Args:
            layer_num: 1-4 (Layer 1, 2, 3, or 4)
            event_type: 'prompt_sent', 'response_received', 'sql_query', 'sql_results'
            data: RAW data to log (unfiltered)
        """
        layer_key = f"layer{layer_num}"
        
        # Ensure layer exists and has events list
        if layer_key not in self.log_data["layers"]:
            self.log_data["layers"][layer_key] = {"events": []}
        elif "events" not in self.log_data["layers"][layer_key]:
            self.log_data["layers"][layer_key]["events"] = []
        
        # Add timestamped event to events list (append, don't overwrite)
        event_time = datetime.now().isoformat()
        
        # Store RAW data (no filtering)
        event_data = None
        if isinstance(data, str):
            event_data = data
        elif isinstance(data, dict) or isinstance(data, list):
            event_data = data
        else:
            event_data = str(data)
        
        # Append event to list
        self.log_data["layers"][layer_key]["events"].append({
            "event_type": event_type,
            "timestamp": event_time,
            "data": event_data
        })
        
        # Write immediately to file
        self._write_to_file()
        
        # Print to console
        print(f"\n{'='*80}")
        print(f"🔍 DEBUG [{layer_key.upper()}] - {event_type}")
        print(f"{'='*80}")
        if isinstance(data, str):
            # Truncate very long strings for console (but save full to file)
            if len(data) > 2000:
                print(data[:2000] + f"\n... [TRUNCATED - Full data in log file] ...")
            else:
                print(data)
        else:
            print(json.dumps(data, indent=2)[:2000])
        print(f"{'='*80}\n")
    
    def _write_to_file(self):
        """Write current log data to file immediately"""
        with open(self.log_file, 'w') as f:
            json.dump(self.log_data, f, indent=2, default=str)


# Global debug logger instance (initialized per request)
_debug_logger = None

def init_debug_logger(conversation_id: str):
    """Initialize debug logger for a conversation"""
    global _debug_logger
    _debug_logger = DebugLogger(conversation_id)
    return _debug_logger

def get_debug_logger() -> DebugLogger:
    """Get current debug logger instance"""
    return _debug_logger

def log_debug(layer_num: int, event_type: str, data: Any):
    """Convenience function to log debug data"""
    if _debug_logger:
        _debug_logger.log_layer(layer_num, event_type, data)

def get_debug_logs(conversation_id: str) -> Dict[str, Any]:
    """
    Get debug logs for a conversation from file.
    Returns the log file for the given conversation_id (single file per conversation).
    """
    log_dir = Path(__file__).parent.parent.parent / "logs"
    
    if not log_dir.exists():
        return {"error": "No logs directory found", "layers": {}}
    
    # Log file pattern (no timestamp, single file per conversation)
    log_file = log_dir / f"chat_debug_{conversation_id}.json"
    
    if not log_file.exists():
        return {"error": f"No logs found for conversation {conversation_id}", "layers": {}}
    
    try:
        with open(log_file, 'r') as f:
            return json.load(f)
    except Exception as e:
        return {"error": f"Failed to read log file: {str(e)}", "layers": {}}
