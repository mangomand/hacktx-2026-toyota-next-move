# Toyota Next Move — Project Handoff

## Product

HackTX 2026 Toyota Financial Services challenge: help a Toyota customer answer, “Given my situation today, what is the smartest next move for me and my Toyota?”

The app guides a non-expert through a vehicle inspection, turns camera evidence into an uncertainty-aware vehicle view, identifies visible findings, combines those findings with synthetic customer/vehicle/loan/lease data, and recommends one clear next action.

The experience should feel like a premium AR inspection tool, not a form or a diagnostic chatbot.

## User vision

- The app opens directly into a live camera scan.
- The user taps Start Scan once, then moves around the Toyota.
- The app continuously evaluates frames, quality, motion, and coverage.
- Prompts update automatically based on missing coverage.
- White contours, points, and simplified geometry build over the camera view.
- Unseen or uncertain areas remain visibly neutral.
- The scan transitions into a polished, rotatable Tesla-style vehicle view.
- Findings attach to real vehicle surfaces and show evidence, confidence, uncertainty, and next action.
- The final recommendation is plain language: self-service, follow-up, or an eligible offer.

The visual reference is Apple RoomPlan-like: full-screen camera, minimal translucent controls, white scan contours, restrained motion, concise movement prompts, and clear finish/coverage state.

## Hardware and scope

- Primary device: iPhone 15 Plus.
- LiDAR is entirely out of scope.
- Do not implement or plan ARMeshAnchor, scene depth, or Pro-device branches.
- Baseline sensing is RGB camera frames, camera/IMU pose signals, AVFoundation, Vision/Core ML, and guided user movement.
- ARKit may provide tracking and pose signals; it does not create the polished vehicle model by itself.

## Current technical state

- SwiftUI iOS app shell exists.
- AVFoundation camera capture and sample-buffer processing exist.
- Toyota video replay is retained as a deterministic simulator/demo fallback.
- Frame-quality checks cover blur, exposure, motion, and evidence quality.
- Capture progress and dynamic next-region selection are implemented in the current iOS work.
- Canonical JSON contracts exist under `docs/contracts/` for scan sessions, regions, findings, vehicle profiles, agreements, recommendations, and demo scenarios.
- Vision code includes pixel analysis, uncertainty handling, asset anchors, device capability handling, and a material-reveal seam.
- Current visual vehicle geometry is still a temporary SceneKit/primitive model; a high-quality Toyota-like asset is still needed.
- Synthetic financial/domain recommendation behavior must remain connected to the actual scan findings; hard-coded recommendations are insufficient.

## Capture behavior acceptance bar

The required flow is continuous:

1. User taps Start Scan once.
2. Frames are sampled continuously.
3. Quality and evidence are evaluated continuously.
4. Accepted evidence updates coverage and progress.
5. The next-area prompt changes automatically.
6. Pause, retake, finish, and optional evidence snapshots remain available.
7. Low-quality frames do not advance coverage.
8. Unseen areas remain unknown; absence of evidence must never mean no damage.

The Toyota replay path may be deterministic, but it must still use decoded pixels and the same evidence/quality path where possible.

## 3D material direction

The desired effect is a **surface-conforming material reveal**, not sloppy section coloring.

The vehicle begins as clean neutral gray. As evidence accumulates, the actual vehicle paint/material should emerge from inside the mesh like pigment absorbed into paper or watercolor spreading through fabric. The reveal must follow the vehicle’s geometry and panel boundaries, have a soft animated edge, and avoid looking like a flat mask, sticker, flood fill, or painted blob.

Suggested state model:

- `0`: unseen/unknown — neutral gray
- intermediate value: partially observed — partial material reveal
- `1`: sufficiently observed with no visible issue — full vehicle material
- finding: restrained amber/red surface accent layered above the material
- blocked/uncertain: muted or hatched state

“Normal material” means no visible issue was found in the captured evidence; it does not claim mechanical health.

## AI and asset pipeline

Use a strong prebuilt or AI-generated vehicle asset for recognizable geometry. Clean it offline with Blender or equivalent: remove junk geometry, fix normals, weld small defects, separate body/wheels/glass/lights, assign materials, add named surface anchors, and export USDZ/glTF.

Use the phone video for evidence, coverage, quality, pose, findings, and surface state. Video alone should not be expected to produce a polished, accurate vehicle mesh in the MVP.

## Important limitations

- Without a real trained classifier, region classification may still rely on guided user direction, camera pose, replay metadata, or an injected classifier seam.
- Exterior imagery cannot establish hidden mechanical condition.
- The final app must not imply that unseen areas are healthy.
- Simulator replay is evidence for the demo path, not proof of physical iPhone camera behavior.

## Relevant project locations

- Product brief: `docs/product-brief.md`
- Architecture: `docs/architecture.md`
- Contracts: `docs/contracts/`
- iOS capture: `ios/`
- iOS handoff: `docs/modules/ios-capture/HANDOFF.md`
- Vision/3D: `vision/`
- Vision handoff: `docs/modules/vision/handoff.md`
- Asset strategy: `docs/modules/vision/asset-strategy.md`
- Product/design references: `docs/product-design/`
- QA and demo checks: `docs/quality/`

## Active project threads

- Orchestrator: `mcp:f875bceb-ec15-4e49-b1f5-1c627315b5ab`
- iOS Capture lead: `mcp:c5fe3846-3b11-4297-934a-8a926bbf4898`
- Vision/3D lead: `mcp:04a9d317-5072-4102-a985-a4d469b12243`
- Product/UX lead: `mcp:fa31e0e8-4612-4172-91a7-8acc58f164f1`
- QA/Responsible AI lead: `mcp:09ab1e4f-ca37-4a56-8550-af8a85e95d8d`

## Latest recording evidence

Drive recording: https://drive.google.com/file/d/1tvvyIB-v4v5yjxgwy7J0ofyxVHXvxL4G/view?usp=drivesdk

The recording is an A2 review. It visibly proves live camera ingestion, camera display, feature-point overlay, and quality/evidence status. At the time of review, it still showed a button-driven flow, stayed at 1/12, and kept the Front left prompt while the viewpoint changed. A2 acceptance therefore requires verifying that accepted live frames advance coverage and change the prompt automatically without requiring a per-region Capture button.

## Immediate next work

1. Verify the A2 continuous live progression on the actual current build.
2. Prototype the 3D surface-conforming material reveal on a real vehicle asset.
3. Attach one evidence-backed finding to one real surface anchor.
4. Connect scan findings to synthetic customer, vehicle, and loan/lease scenarios.
5. Produce an end-to-end demo: Start Scan → guided coverage → vehicle reveal → finding → personalized next move.

