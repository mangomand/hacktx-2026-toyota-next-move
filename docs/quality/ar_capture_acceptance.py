#!/usr/bin/env python3
"""QA metadata checks for the iPhone 15 Plus camera-baseline experience."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "docs/quality/fixtures/ar-capture-acceptance.json"

def main():
    d = json.loads(FIXTURE.read_text())
    assert d["format"] == "qa-ar-capture-acceptance-v2"
    assert d["primarySurface"] == "live_camera_full_screen"
    assert set(d["controls"]) == {"cancel", "finish", "scan_settings", "progress"}
    assert d["contour"] == {"color":"white", "cameraAligned":True, "evidenceOnly":True, "detachedMapAccepted":False}
    assert d["coveragePrompt"]["dynamic"] and d["coveragePrompt"]["missingRegion"] and d["coveragePrompt"]["text"]
    assert d["finish"]["coveredRequired"] and d["finish"]["blockedExplained"] and d["finish"]["missingRegions"]
    assert d["replayFallback"]["label"] in {"Replay", "Demo"} and not d["replayFallback"]["liveClaim"]
    post=d["postScan"]; assert post["surface"] == "rotatable_vehicle" and post["transition"] == "camera_to_vehicle" and post["findingTapThrough"] and post["anchoredToSurface"] and post["evidenceAndUncertainty"] and not post["primitiveGeometry"]
    baseline=d["cameraBaseline"]; assert baseline["device"] == "iPhone 15 Plus" and baseline["tracking"] == "camera_imu_world_tracking"
    assert all(baseline[key] for key in ("rgbFrames", "pixelAnalysis", "qualityGating", "dynamicPrompts", "vehicleAssetUpdates"))
    print("Camera-baseline QA metadata passed: controls, contours, dynamic prompt, Finish gate, Replay fallback, post-scan vehicle, RGB/pose/pixel path")
if __name__ == "__main__": main()
