"""
Feature metadata tracking and validation.
"""

from typing import Dict, List
from datetime import datetime
import json


class FeatureMetadata:
    """
    Track metadata for all generated features.
    """
    
    def __init__(self):
        self.features = {}
        self.version = None
        self.created_at = None
    
    def add_feature(
        self,
        name: str,
        dtype: str,
        description: str,
        source: str,
        computation: str
    ):
        """
        Register a feature with metadata.
        
        Args:
            name: Feature name
            dtype: Data type (float, int, bool, string)
            description: Human-readable description
            source: Source dataset (e.g., 'patient_vitals_stream')
            computation: How the feature is computed
        """
        self.features[name] = {
            "dtype": dtype,
            "description": description,
            "source": source,
            "computation": computation,
            "created_at": datetime.utcnow().isoformat()
        }
    
    def set_version(self, version: str):
        """Set feature set version."""
        self.version = version
        self.created_at = datetime.utcnow().isoformat()
    
    def to_json(self) -> str:
        """Export metadata as JSON."""
        return json.dumps({
            "version": self.version,
            "created_at": self.created_at,
            "feature_count": len(self.features),
            "features": self.features
        }, indent=2)
    
    def save(self, path: str):
        """Save metadata to file."""
        with open(path, 'w') as f:
            f.write(self.to_json())
        print(f"✓ Feature metadata saved: {path}")
    
    def get_feature_list(self) -> List[str]:
        """Get list of all feature names."""
        return list(self.features.keys())
    
    def summary(self) -> Dict:
        """Get summary statistics."""
        dtype_counts = {}
        source_counts = {}
        
        for feature in self.features.values():
            dtype = feature["dtype"]
            source = feature["source"]
            
            dtype_counts[dtype] = dtype_counts.get(dtype, 0) + 1
            source_counts[source] = source_counts.get(source, 0) + 1
        
        return {
            "total_features": len(self.features),
            "by_dtype": dtype_counts,
            "by_source": source_counts,
            "version": self.version
        }