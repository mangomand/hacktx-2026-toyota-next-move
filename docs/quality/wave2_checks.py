#!/usr/bin/env python3
"""QA-owned Wave 2 replay-to-recommendation checks; stdlib-only and read-only."""
import json
import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "docs/quality/fixtures"
REGIONS = ["front", "front-left", "left", "rear-left", "rear", "rear-right", "right", "front-right", "roof", "interior-front", "interior-rear", "trunk"]
FORBIDDEN = ("safe to drive", "roadworthy", "engine healthy", "frame is bent", "no damage", "mechanical diagnosis")
FORBIDDEN_WORDS = {"safe", "clear"}
EXPECTED_SEQUENCE = ["start_scan", "coverage", "replay", "map_findings", "recommendation"]
ALLOWED_OBSERVED_STATES = {"covered", "partial"}


def load(path):
    return json.loads(Path(path).read_text())


def artifact_refs(session):
    refs = list(session.get("artifactRefs", []))
    refs.extend(ref for region in session["regions"] for ref in region.get("artifactRefs", []))
    return refs


def expected_escalation(findings, regions):
    if any(f["severity"] == "high" or f["category"] == "warning_indicator" for f in findings):
        return "safety_review"
    if any(r["state"] in {"partial", "unseen", "blocked"} for r in regions) or any(f["status"] == "needs_review" for f in findings):
        return "more_evidence"
    return "none"


def check_blocked_case():
    blocked = load(FIXTURES / "blocked-region-case.json")
    region = blocked["region"]
    assert region["state"] == "blocked" and region["quality"] == "unknown"
    assert region["regionId"] in blocked["unknownRegions"]
    assert blocked["expectedEscalation"] == expected_escalation([], [region])
    assert blocked["expectedEscalation"] == "more_evidence"
    assert blocked["findings"] == [], "blocked regions cannot produce visible findings"
    copy = blocked["copy"].lower()
    assert "unable to assess" in copy and not any(term in copy for term in FORBIDDEN)


def check_replay(session_path, analysis_path):
    session = load(session_path)
    analysis = load(analysis_path)
    assert analysis["format"] == "qa-generated-analysis-envelope-v1"
    assert analysis["producer"]["module"].startswith("VisionCore.")
    assert analysis["producer"]["source"] == "vision/Sources/VisionCore/VisionCore.swift"
    assert analysis["producer"]["inputSession"] == "ios/replay/replay-scan-session.json"
    assert analysis["scenarioId"] == session["id"]
    assert analysis["findingIds"] == [finding["id"] for finding in analysis["findings"]]
    assert analysis["producer"]["command"] == "swift test --package-path vision"
    assert session["status"] == "replay" and session["mode"] == "synthetic_replay"
    assert "sequence" not in session, "stage sequence must remain outside ScanSession wire JSON"
    assert len(session["regions"]) == 12
    by_id = {region["regionId"]: region for region in session["regions"]}
    assert list(by_id) == REGIONS
    unknown = set(session["unknownRegions"])
    assert unknown == {region_id for region_id, region in by_id.items() if region["state"] != "covered"}
    assert {"interior-rear", "trunk"}.issubset(unknown)
    partial_low = {region_id for region_id, region in by_id.items() if region["state"] == "partial" and region["quality"] == "low"}
    assert {"rear-left", "front-right"}.issubset(partial_low)

    refs = set(artifact_refs(session))
    for ref in refs:
        assert (ROOT / ref).is_file(), f"unresolved evidence ref: {ref}"
    assert len(refs) == 11

    assert analysis["sequence"] == EXPECTED_SEQUENCE
    assert analysis["map"]["sourceSession"] == session["id"]
    assert set(analysis["map"]["unknownRegions"]) == unknown
    findings = {finding["id"]: finding for finding in analysis["findings"]}
    assert findings
    for finding in findings.values():
        assert finding["regionId"] in by_id
        assert by_id[finding["regionId"]]["state"] in ALLOWED_OBSERVED_STATES, "findings cannot attach to unseen or blocked regions"
        assert finding["evidenceRefs"] and set(finding["evidenceRefs"]).issubset(refs)
        assert finding["status"] in {"needs_review", "not_a_diagnosis", "unseen"}
        description = finding.get("description", "").lower()
        assert not any(term in description for term in FORBIDDEN)
        assert not any(re.search(rf"\b{re.escape(word)}\b", description) for word in FORBIDDEN_WORDS)
    recommendation = analysis["recommendation"]
    assert recommendation["nextMove"] and recommendation["escalation"] in {"more_evidence", "human_review", "safety_review", "none"}
    assert set(recommendation["basedOn"]).issubset(findings)
    assert recommendation["escalation"] == expected_escalation(list(findings.values()), list(by_id.values()))
    assert recommendation["escalation"] == "more_evidence"
    assert recommendation["nextMove"] in {"request_more_views", "schedule_inspection"}
    text = " ".join([recommendation["rationale"], *recommendation["caveats"]]).lower()
    assert "exterior imagery cannot assess hidden mechanical condition" in text
    assert not any(term in text for term in FORBIDDEN)
    assert not any(re.search(rf"\b{re.escape(word)}\b", text) for word in FORBIDDEN_WORDS)
    assert "glare-limited" in text and any("glare-limited" in finding.get("description", "").lower() for finding in findings.values())


def check_hazard_case(session_path):
    hazard = load(FIXTURES / "wave2-hazard-case.json")
    session = load(session_path)
    refs = set(artifact_refs(session))
    assert hazard["producer"]["inputSession"] == "ios/replay/replay-scan-session.json"
    findings = hazard["findings"]
    assert all(f["regionId"] in REGIONS and f["evidenceRefs"] and set(f["evidenceRefs"]).issubset(refs) for f in findings)
    assert hazard["recommendation"]["escalation"] == expected_escalation(findings, [session["regions"][0]])
    assert hazard["recommendation"]["escalation"] == "safety_review"
    assert "exterior imagery cannot assess hidden mechanical condition" in " ".join(hazard["recommendation"]["caveats"]).lower()


def main():
    session_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "ios/replay/replay-scan-session.json"
    analysis_path = Path(sys.argv[2]) if len(sys.argv) > 2 else FIXTURES / "wave2-analysis.json"
    check_blocked_case()
    check_hazard_case(session_path)
    check_replay(session_path, analysis_path)
    print("Wave 2 QA checks passed: replay→map→finding→recommendation, covered/partial/unseen/blocked, low-quality evidence, unknownRegions, evidence refs, escalation, no-diagnosis copy")


if __name__ == "__main__":
    main()
