#!/usr/bin/env python3
"""Dependency-free checks for the Toyota Next Move v0.1.0 contract registry."""
import json
import datetime
import sys
from pathlib import Path

ROOT = Path(__file__).parent
REGION_IDS = {"front", "front-left", "left", "rear-left", "rear", "rear-right", "right", "front-right", "roof", "interior-front", "interior-rear", "trunk"}

def load_registry():
    registry = json.loads((ROOT / "registry.json").read_text())
    loaded = {key: json.loads((ROOT / filename).read_text()) for key, filename in registry.items()}
    assert set(registry) == {doc["$id"] for doc in loaded.values()}
    return loaded

def validate_instance(value, schema, registry, path="$", root=None):
    root = root or schema
    if "$ref" in schema:
        target = registry.get(schema["$ref"])
        if target is None:
            raise ValueError(f"{path}: unresolved ref {schema['$ref']}")
        return validate_instance(value, target, registry, path, root)
    if "const" in schema and value != schema["const"]:
        raise ValueError(f"{path}: expected const {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"{path}: value not in enum")
    types = schema.get("type")
    if types:
        allowed = types if isinstance(types, list) else [types]
        matches = any((t == "null" and value is None) or (t == "object" and isinstance(value, dict)) or
                      (t == "array" and isinstance(value, list)) or (t == "string" and isinstance(value, str)) or
                      (t == "integer" and isinstance(value, int) and not isinstance(value, bool)) or
                      (t == "number" and isinstance(value, (int, float)) and not isinstance(value, bool)) or
                      (t == "boolean" and isinstance(value, bool)) for t in allowed)
        if not matches: raise ValueError(f"{path}: wrong type")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value: raise ValueError(f"{path}: missing required {key}")
        props = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extras = set(value) - set(props)
            if extras: raise ValueError(f"{path}: unexpected properties {sorted(extras)}")
        for key, child in props.items():
            if key in value: validate_instance(value[key], child, registry, f"{path}.{key}", root)
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0) or ("maxItems" in schema and len(value) > schema["maxItems"]):
            raise ValueError(f"{path}: invalid item count")
        if schema.get("uniqueItems") and len({json.dumps(x, sort_keys=True) for x in value}) != len(value):
            raise ValueError(f"{path}: items must be unique")
        if "items" in schema:
            for i, child in enumerate(value): validate_instance(child, schema["items"], registry, f"{path}[{i}]")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]: raise ValueError(f"{path}: below minimum")
        if "maximum" in schema and value > schema["maximum"]: raise ValueError(f"{path}: above maximum")
    if isinstance(value, str) and schema.get("format") in {"date", "date-time"}:
        try: datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError: raise ValueError(f"{path}: invalid {schema['format']}")

def validate_scan_session(session):
    regions = session.get("regions")
    if not isinstance(regions, list) or len(regions) != len(REGION_IDS):
        raise ValueError("ScanSession.regions must contain exactly 12 records")
    ids = [region.get("regionId") for region in regions]
    if set(ids) != REGION_IDS or len(ids) != len(set(ids)):
        raise ValueError("ScanSession.regions must contain each canonical regionId exactly once")
    if session.get("status") == "replay" and session.get("mode") != "synthetic_replay":
        raise ValueError("replay sessions must declare mode synthetic_replay")

def main(argv):
    loaded = load_registry()
    if argv:
        payload = json.loads(Path(argv[0]).read_text())
        validate_instance(payload, loaded["toyota-next-move/ScanSession/0.1.0"], loaded)
        validate_scan_session(payload)
        print(f"validated ScanSession: {argv[0]}")
    print(f"validated registry: {len(loaded)} schemas")

if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (AssertionError, KeyError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"contract validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
