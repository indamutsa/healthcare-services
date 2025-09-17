#!/usr/bin/env python3
"""
Generate TypeScript types from FastAPI OpenAPI schema
Usage: python scripts/generate_types.py
"""

import json
import requests
from pathlib import Path

def generate_typescript_types():
    """Generate TypeScript interfaces from FastAPI OpenAPI schema"""
    
    # Get OpenAPI schema from running FastAPI server
    try:
        response = requests.get("http://localhost:8000/openapi.json")
        schema = response.json()
    except requests.RequestException:
        print("Error: FastAPI server not running on localhost:8000")
        return
    
    # Extract components/schemas
    schemas = schema.get("components", {}).get("schemas", {})
    
    # Generate TypeScript interfaces
    ts_content = "// Auto-generated TypeScript types from FastAPI\n\n"
    
    for name, definition in schemas.items():
        ts_content += f"export interface {name} {{\n"
        
        properties = definition.get("properties", {})
        required = definition.get("required", [])
        
        for prop_name, prop_def in properties.items():
            optional = "" if prop_name in required else "?"
            ts_type = python_to_ts_type(prop_def)
            ts_content += f"  {prop_name}{optional}: {ts_type};\n"
        
        ts_content += "}\n\n"
    
    # Write to types file
    types_dir = Path("types") / "api"
    types_dir.mkdir(parents=True, exist_ok=True)
    
    with open(types_dir / "generated.ts", "w") as f:
        f.write(ts_content)
    
    print("✅ TypeScript types generated successfully")

def python_to_ts_type(prop_def):
    """Convert Python/JSON schema type to TypeScript type"""
    prop_type = prop_def.get("type", "any")
    
    type_mapping = {
        "string": "string",
        "integer": "number",
        "number": "number",
        "boolean": "boolean",
        "array": f"Array<{python_to_ts_type(prop_def.get('items', {}))}>",
        "object": "Record<string, any>"
    }
    
    return type_mapping.get(prop_type, "any")

if __name__ == "__main__":
    generate_typescript_types()