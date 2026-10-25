# iOS simulator/device verification and judge rehearsal

## Verification matrix

Run on the coordinator's supported iOS version plus one compact-width simulator. Prefer a real device for camera, rotation, interruption, and permission checks. Record model, OS, build SHA, and replay seed.

| Scenario | Expected behavior | Fallback evidence |
|---|---|---|
| Camera permission denied/revoked | Explain why, offer replay or retry; no fabricated coverage. | Screenshot + unit test |
| Camera interruption/background/phone call | Persist last confirmed sector; resume as unseen/uncertain if frame was incomplete. | XCTest state test |
| Offline or slow network | Replay and local synthetic data remain usable; remote enrichment is labeled unavailable. | Network-conditioned run |
| Rotation/compact width/Dynamic Type | Controls remain reachable and labels do not truncate safety copy. | Accessibility inspector screenshots |
| Low battery/thermal or camera unavailable | Safe replay fallback with visible “demo/replay” label; never claim live inspection. | Screen recording |
| Stale/mismatched session or join key | Reject or show unknown; do not merge another customer/vehicle. | Fixture decoder test |

If no installable iOS target exists, report `not executable: no Xcode project/scheme in repository`; do not infer a pass from simulator availability.

## Judge script

1. Reset app data and launch a clean build. Start a stopwatch at the first user-visible session screen.
2. Choose **Synthetic replay** and verify the replay label, scenario ID/version, and contract/build version are recorded (debug metadata may be external).
3. Let the guided route run or follow the scripted taps. At each sector, note whether the map distinguishes covered, partial, blocked, and unseen with quality/uncertainty text.
4. At the first finding, open its evidence frame and read the uncertainty/copy aloud. Check that no hidden mechanical diagnosis appears.
5. Complete the route. Stop the stopwatch when the single next move and its reason are both readable. Record elapsed time, tap count, and any recovery.
6. Repeat from reset with the same pinned scenario and test controls. Compare canonical result summary and recommendation; differences are a blocker.
7. Run a partial route with two sectors unseen. Confirm the result says what remains unknown and offers escalation/inspection rather than “all clear.”
8. Run permission denial or camera-unavailable fallback. Confirm replay remains available and is clearly labeled.

Targets: replay <=120s to clear next move; guided rehearsal <=180s; zero ambiguity about the action; zero safety-copy violations; zero unseen-as-inspected violations. Capture a short recording and the evidence packet described in `acceptance-checklist.md`.

## Failure budget and clarity score

Allow one live attempt. If no result after 15 seconds following submission, switch to local synthetic replay; if replay fails within five seconds, play a previously recorded run from the same build. Clearly label replay/recorded mode. A recording supports presentation continuity and never counts as an executed app acceptance gate. Do not troubleshoot in front of judges.

After the result is shown, ask a fresh observer to state within ten seconds: (1) the one recommended action, (2) one supporting reason, and (3) what remains unknown. Score 0–3 correct answers. Proposed target: 3/3 from at least two observers, no prompting. Record exact answers, elapsed time to result, mode switches, and any misleading safety interpretation. Thresholds are proposed QA targets pending coordinator acceptance.

Additional bounded checks: delayed response A arriving after session B must not replace B; retries must not duplicate sessions; terminate during processing then relaunch without a permanent spinner. Use local replay offline from cold launch. Apply audio/import/auth tests only if those capabilities exist.

## MVP execution order

Prioritize the deterministic replay path and installable build evidence before broader hardening work. The replay must still preserve canonical contract validation, explicit unknown/unseen regions, and non-diagnostic exterior-observation copy. Security-hardening scenarios outside those core gates are deferred follow-up work and must not displace replay/build validation.

## AR reference rehearsal

On a supported camera-capable device, begin with the live camera as the full-screen primary surface. Verify minimal translucent Cancel/Finish/scan controls and a thin progress indicator. Move around the vehicle and record that white contours/planes build directly over the camera image, remain aligned as the camera moves, and leave unobserved regions neutral. Trigger a low-quality/glare view and verify the retake prompt; move to the next missing region and verify the prompt changes with coverage.

Attempt Finish before required coverage: it must remain unavailable or explain the exact missing/blocked regions. Finish after sufficient coverage and verify a camera-aligned reconstruction transitions into a polished rotatable vehicle view. Tap a surface-anchored finding and verify evidence, confidence, uncertainty, and next action. Reject primitive rounded-box geometry, detached top-down diagrams, floating labels, or findings not anchored to a captured surface.

If the device or simulator cannot support ARKit/RealityKit, switch to the deterministic replay and label the screen `Replay`/`Demo`; capture a separate recording and do not count it as live AR evidence. The flat region map remains an accessibility/debug fallback.

## iPhone 15 Plus camera-baseline rehearsal

Use an iPhone 15 Plus as the primary test device. Record the capability decision: RGB camera frames and camera/IMU world tracking are active. Start the scan and verify guided capture, motion/pose tracking, frame quality, semantic evidence, dynamic next-region prompts, camera-aligned overlays, and vehicle-asset updates.

If a capability signal is unavailable, continue through the baseline camera path. If camera or pose tracking cannot run, switch to the deterministic replay and show a truthful `Replay`/`Demo` label. Never claim evidence, tracking, or coverage that the active path did not produce.

The visual bar remains camera-aligned scan overlays followed by a polished rotatable vehicle; sensing limitations change uncertainty and coverage quality, not the product direction.
