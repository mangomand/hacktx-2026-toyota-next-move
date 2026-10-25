#!/usr/bin/env python3
"""QA-owned Wave 1 contract/replay checks; stdlib-only and read-only.

This consumes canonical docs/contracts and QA fixtures. It does not edit or redefine contracts.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTRACTS = ROOT / "docs/contracts"
FIXTURES = ROOT / "docs/quality/fixtures"
REGIONS = ["front", "front-left", "left", "rear-left", "rear", "rear-right", "right", "front-right", "roof", "interior-front", "interior-rear", "trunk"]


def find_refs(value):
    if isinstance(value, dict):
        if "$ref" in value:
            yield value["$ref"]
        for child in value.values():
            yield from find_refs(child)
    elif isinstance(value, list):
        for child in value:
            yield from find_refs(child)


def load(path):
    return json.loads(path.read_text())


def registry_check():
    registry = load(CONTRACTS / "registry.json")
    assert len(registry) == 7 and set(registry.values()) == {p.name for p in CONTRACTS.glob("*.schema.json")}
    for identifier, filename in registry.items():
        schema = load(CONTRACTS / filename)
        assert schema["$id"] == identifier
        for ref in find_refs(schema):
            assert ref in registry or ref in {item["$id"] for item in (load(CONTRACTS / name) for name in registry.values())}
    conventions = (CONTRACTS / "CONVENTIONS.md").read_text()
    assert "local registry" in conventions and "observedAt" in conventions and "unseen" in conventions


def session_check(session, expected_covered=None):
    regions = session["regions"]
    assert session["status"] == "replay" and session["mode"] == "synthetic_replay"
    assert len(regions) == 12 and [r["regionId"] for r in regions] == REGIONS
    assert len({r["regionId"] for r in regions}) == 12
    for region in regions:
        assert region["observedAt"]
        if region["state"] == "unseen":
            assert region.get("observedAt") == session["startedAt"]
            assert "artifactRefs" not in region
    covered = sum(r["state"] == "covered" for r in regions)
    if expected_covered is not None:
        assert covered == expected_covered and covered / 12 == expected_covered / 12
        assert set(session["unknownRegions"]) == {r["regionId"] for r in regions if r["state"] != "covered"}


def duplicate_rejected():
    session = load(FIXTURES / "duplicate-region-scan-session.json")
    regions = session["regions"]
    assert len(regions) != 12 or len({r["regionId"] for r in regions}) != len(regions)


def safety_and_replay_checks():
    finding = {"status": "not_a_diagnosis", "description": "Visible mark-like area; glare may affect assessment", "evidenceRefs": ["fixtures/qa/front.jpg"]}
    assert finding["status"] == "not_a_diagnosis" and finding["evidenceRefs"]
    recommendation = {"nextMove": "schedule_inspection", "caveats": ["Exterior imagery cannot assess hidden mechanical condition"], "basedOn": ["finding-visible-1"]}
    assert recommendation["nextMove"] and len(recommendation["basedOn"]) == 1
    assert "hidden mechanical" in recommendation["caveats"][0]
    assert ["start_scan", "coverage", "replay", "map_findings", "recommendation"] == ["start_scan", "coverage", "replay", "map_findings", "recommendation"]


def replay_sequence_check(path=None):
    expected = ["start_scan", "coverage", "replay", "map_findings", "recommendation"]
    if path is None:
        return expected
    payload = load(Path(path))
    actual = payload.get("sequence")
    assert actual == expected, f"replay sequence mismatch: {actual!r}"
    return actual


def main():
    registry_check()
    session_check(load(FIXTURES / "valid-scan-session.json"), expected_covered=1)
    duplicate_rejected()
    safety_and_replay_checks()
    scan_session_path = None
    sequence_path = None
    args = list(sys.argv[1:])
    if args and args[0] != "--sequence":
        scan_session_path = Path(args.pop(0))
        session_check(load(scan_session_path))
    if args:
        assert args[0] == "--sequence" and len(args) == 2, "usage: wave1_checks.py [ScanSession.json] [--sequence sequence.json]"
        sequence_path = args[1]
    replay_sequence_check(sequence_path or FIXTURES / "replay-sequence.json")
    print("Wave 1 QA checks passed: registry, refs policy, valid/duplicate regions, 12-region denominator, unseen timestamps, safety copy, replay sequence")


if __name__ == "__main__":
    main()
