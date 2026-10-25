#!/usr/bin/env python3
"""QA-owned executable integration checks for the real capture loop.

No synthetic pixel observations are created here. Pixel behavior is exercised by
VisionCore's own in-memory pixel tests; this harness validates their executable
package and the producer's canonical replay output/provenance.
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPLAY = ROOT / "ios/replay/replay-scan-session.json"
CAPTURE = ROOT / "ios/Sources/CaptureCore/CaptureCore.swift"
VISION_SOURCES = list((ROOT / "vision/Sources/VisionCore").glob("*.swift"))


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        raise AssertionError(f"{' '.join(command)} failed:\n{result.stdout}\n{result.stderr}")
    return result.stdout + result.stderr


def main():
    session = json.loads(REPLAY.read_text())
    assert session["status"] == "replay" and session["mode"] == "synthetic_replay"
    regions = {item["regionId"]: item for item in session["regions"]}
    assert len(regions) == 12
    assert all(item["state"] in {"covered", "partial", "unseen", "blocked"} for item in regions.values())
    assert {region for region, item in regions.items() if item["state"] != "covered"} == set(session["unknownRegions"])
    assert {"interior-rear", "trunk"}.issubset(session["unknownRegions"])
    refs = set(session["artifactRefs"])
    refs.update(ref for item in session["regions"] for ref in item.get("artifactRefs", []))
    assert len(refs) == 11 and all((ROOT / ref).is_file() for ref in refs)

    capture_source = CAPTURE.read_text()
    vision_source = "\n".join(path.read_text() for path in VISION_SOURCES)
    for marker in ("CaptureProgress", "ingest", "nextUncovered", "needsRetake", "VisionHandoff", "sessionJSON"):
        assert marker in capture_source, marker
    for marker in ("VisionPixelFrame", "FrameAnalyzer", "evidenceRegions", "missingRegions", "visibleObservation"):
        assert marker in vision_source, marker
    assert "EvidenceAvailability" in vision_source and "unavailable" in vision_source

    run(["swift", "test", "--package-path", "ios"], ROOT)
    run(["swift", "test", "--package-path", "vision"], ROOT)
    print("Capture-loop QA passed: ingestion, dynamic missing-region guidance, retake/partial state, unseen preservation, pixel-evidence provenance, and no-fabricated-finding package tests")


if __name__ == "__main__":
    main()
