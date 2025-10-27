import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict

class DebugLogger:
    """RAW debug logger for agent layer outputs - captures everything unfiltered"""
    
    def __init__(self, conversation_id: str):
        self.conversation_id = conversation_id
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_dir = Path(__file__).parent.parent.parent / "logs"
        self.log_dir.mkdir(exist_ok=True)
        
        self.log_file = self.log_dir / f"chat_debug_{conversation_id}_{self.timestamp}.json"
        
        # Initialize log file with empty structure
        self.log_data = {
            "conversation_id": conversation_id,
            "timestamp": datetime.now().isoformat(),
            "layers": {
                "layer1": {},
                "layer2": {},
                "layer3": {},
                "layer4": {}
            }
        }
        self._write_to_file()
    
    def log_layer(self, layer_num: int, event_type: str, data: Any):
        """
        Log RAW data for a specific layer event.
        
        Args:
            layer_num: 1-4 (Layer 1, 2, 3, or 4)
            event_type: 'prompt_sent', 'response_received', 'sql_query', 'sql_results'
            data: RAW data to log (unfiltered)
        """
        layer_key = f"layer{layer_num}"
        
        # Ensure layer exists
        if layer_key not in self.log_data["layers"]:
            self.log_data["layers"][layer_key] = {}
        
        # Add timestamped event
        event_time = datetime.now().isoformat()
        event_key = f"{event_type}_{event_time}"
        
        # Store RAW data (no filtering)
        if isinstance(data, str):
            self.log_data["layers"][layer_key][event_type] = data
        elif isinstance(data, dict) or isinstance(data, list):
            self.log_data["layers"][layer_key][event_type] = data
        else:
            self.log_data["layers"][layer_key][event_type] = str(data)
        
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
