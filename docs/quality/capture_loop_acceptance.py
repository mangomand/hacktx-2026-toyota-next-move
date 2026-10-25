#!/usr/bin/env python3
"""Deterministic QA envelope checks for capture-loop acceptance metadata."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "docs/quality/fixtures/capture-loop.json"
REGIONS = {"front","front-left","left","rear-left","rear","rear-right","right","front-right","roof","interior-front","interior-rear","trunk"}

def load(): return json.loads(FIXTURE.read_text())
def prompt(states):
    for state, kind in (("partial","clearer_view"),("blocked","alternate_access"),("unseen","request_view")):
        region = next((r for r,v in states.items() if v == state), None)
        if region: return kind, region
    return "complete", None

def check(case, live, gate):
    assert case["source"] == ("camera" if live else "replay")
    if live: assert case["mode"] == "live"
    else:
        assert case["mode"] == "synthetic_replay" and case["replayArtifact"] == "ios/replay/replay-scan-session.json"
        assert (ROOT / case["replayArtifact"]).is_file()
    states = case["regions"]
    assert set(states) <= REGIONS and set(states.values()) <= {"covered","partial","unseen","blocked"}
    by_uri = {f["uri"]: f for f in case["frames"]}
    for frame in case["frames"]:
        passed = frame["sharpness"] >= gate["minSharpness"] and frame["exposure"] >= gate["minExposure"]
        assert frame["gate"] == ("pass" if passed else "fail")
        assert frame["regionId"] in states and states[frame["regionId"]] not in {"unseen","blocked"}
    assert (case["nextPrompt"]["kind"],case["nextPrompt"]["regionId"]) == prompt(states)
    for finding in case["findings"]:
        assert states[finding["regionId"]] in {"covered","partial"} and finding["evidenceRefs"]
        assert all(ref in by_uri and by_uri[ref]["gate"] == "pass" for ref in finding["evidenceRefs"])

def main():
    data=load(); assert data["format"] == "qa-capture-loop-envelope-v1"; gate=data["qualityGate"]
    check(data["cameraAvailable"]["camera-live"],True,gate); check(data["cameraUnavailable"]["camera-unavailable-replay"],False,gate)
    assert prompt({"rear-left":"partial"}) == ("clearer_view","rear-left")
    assert prompt({"trunk":"blocked"}) == ("alternate_access","trunk")
    assert prompt({"trunk":"unseen"}) == ("request_view","trunk")
    bad=json.loads(json.dumps(data)); bad["cameraAvailable"]["camera-live"]["findings"][0]["evidenceRefs"]=["camera://invented"]
    try: check(bad["cameraAvailable"]["camera-live"],True,gate); raise AssertionError("fabricated evidence accepted")
    except AssertionError as e: assert str(e) != "fabricated evidence accepted"
    print("Capture-loop acceptance passed: prompts, provenance/fallback, quality gates, explicit 3D states, evidence joins")
if __name__ == "__main__": main()
