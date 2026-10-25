# iOS capture lead handoff

Status: **Capture + Perception frame loop wired; awaiting coordinator integration review**
Contract alignment: **canonical v0.1.0 adapter and replay fixture implemented**

## Scope and alignment

The coordinator owns `docs/contracts/` and `docs/coordination.md`. I acknowledge canonical contract version **0.1.0** and the iOS ownership boundary (`ios/` and this module directory). The canonical `CoverageRegion` contract has 12 stable IDs:

`front`, `front-left`, `left`, `rear-left`, `rear`, `rear-right`, `right`, `front-right`, `roof`, `interior-front`, `interior-rear`, `trunk`.

The capture core now uses all 12 canonical IDs and maps quality outcomes to canonical `covered`/`partial` states while retaining explicit `unseen` and `blocked`. `CaptureReplay.sessionJSON()` emits the v0.1.0 `ScanSession` shape with exactly one record per region, `schemaVersion`, replay mode, and repository-relative artifact references.

Wave 2 adds `CaptureReplay.visionHandoff()`. It passes the canonical `ScanSession` JSON plus local routing metadata for Vision: replay artifact refs, `unknownRegions`, and `qualityLimitedRegions`. This is an app-internal handoff envelope, not a competing wire schema. Vision must consume the embedded canonical payload and preserve partial/unseen uncertainty; the handoff emits no findings or recommendation fields, while iOS presentation derives only the approved next move from coverage state.

The judgeable app loop is now Start scan → guided coverage checklist → synthetic replay → Vision map/findings summary → one next move. The start and replay buttons have accessibility identifiers, coverage rows expose region/state labels, and results present `request_more_views` whenever any region is partial or unknown. Vision owns any visible finding output; iOS presents it without inventing mechanical claims.

The capture loop now consumes `AVCaptureVideoDataOutput` pixel buffers, runs luma/gradient/lighting/motion quality checks, ingests quality-gated samples into `CaptureProgress`, and recomputes the next missing region from current coverage and attempt counts. `ToyotaVideoCapture` samples decoded Toyota video pixels with the same analyzer for simulator/demo fallback; the Xcode target bundles `toyota-demo.mov`.

## Current files and checks

### Deterministic media capture increment (2026-10-24)

- The supplied Toyota demo MOV is packaged at `ios/Sources/CaptureCore/Resources/toyota-demo.mov` (25.5 MiB; source attachment basename `mcp-f875bceb-...-mov.mov`; MD5 `ea0c75def6a8851e1c8c5f33e0bb5116`). SwiftPM processes it as a module resource, so the app resolves it with `Bundle.module`.
- `ios/Sources/CaptureCore/MediaCapture.swift` adds `ToyotaVideoCapture`, an AVFoundation/AVAssetImageGenerator adapter. It samples exact, deterministic timestamps at a caller-supplied positive interval, emits PNG pixel bytes plus timestamp/frame ID/quality metadata, and never emits synthetic observations. Decode failures and missing resources are explicit errors.
- On Linux or another SwiftPM environment without AVFoundation/ImageIO/CoreGraphics, the adapter returns `.unsupportedPlatform`; this is the documented fallback and keeps package builds compile-safe. Asset absence returns `.assetUnavailable` before platform dispatch.
- Focused tests cover invalid intervals and explicit unsupported/asset-addressability behavior. The current Vision path has no image evidence wiring, so this increment makes no image-based findings.

- `ios/Package.swift`
- `ios/Sources/CaptureCore/MediaCapture.swift`
- `ios/Sources/CaptureCore/Resources/toyota-demo.mov`
- `ios/Sources/CaptureCore/CaptureCore.swift`
- `ios/Tests/CaptureCoreTests/CaptureCoreTests.swift`
- `ios/Sources/CaptureDemo/CaptureDemoApp.swift`
- `ios/Sources/CaptureCore/CaptureCore.swift` (`VisionHandoff`)
- `ios/Sources/CaptureCore/MediaCapture.swift` (Toyota video pixel sampler and quality analyzer)
- `ios/Sources/CaptureCore/LiveCaptureLoop.swift` (pixel-buffer bridge and progress ingestion)
- `ios/Sources/CaptureDemo/CapturePresentation.swift` (MVP state flow and Vision presentation)
- `vision/` is consumed as a local SwiftPM dependency; its source remains coordinator/Vision-owned and unchanged.
- `ios/CaptureDemo.xcodeproj/` and `ios/CaptureDemo/Info.plist`
- `ios/replay/replay-scan-session.json` and `ios/replay/README.md`
- `ios/Tests/CaptureCoreTests/CaptureCoreTests.swift` (16 tests, including dynamic prompt and pixel-quality checks)
- `swift test --package-path ios --disable-sandbox` — 16 tests passed.
- `swift build --package-path ios --product CaptureDemo --disable-sandbox` — passed.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — validated 7-schema registry and 12-region ScanSession.
- `xcodebuild -project ios/CaptureDemo.xcodeproj -scheme CaptureDemo -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/toyota-next-move-derived build` — **BUILD SUCCEEDED**, producing `/tmp/toyota-next-move-derived/Build/Products/Debug-iphonesimulator/CaptureDemo.app`.
- Coordinator-applied packaging fix verified in `ios/CaptureDemo/Info.plist`: `CFBundleExecutable=$(EXECUTABLE_NAME)`, short version `0.1`, and build `1`. Rebuilt, installed, and launched on booted iPhone 17 simulator (`com.toyota.nextmove.capture-demo`, PID 5447); `simctl get_app_container` and built plist confirm executable `CaptureDemo`.
- Fresh independent verification: **passed**, no actionable findings; generated JSON matches the checked-in fixture and all 11 artifact references resolve.
- Wave 2 handoff test: `CaptureReplay.visionHandoff()` preserves canonical JSON, reports `rear-left`/`front-right` as quality-limited, and reports `interior-rear`/`trunk` as unknown.
- Xcode scheme now builds a separate local `VisionCore` static target from `../../vision/Sources/VisionCore/VisionCore.swift`, links it into `CaptureDemo`, and installs/launches on iPhone 17 simulator (PID 40803).
- Repair validation: Xcode path now invokes `VisionCore.SyntheticReplay` in the simulator target, guided replay visibly enters the replay screen before results, and the guided replay control has accessibility identifier `guided-replay`; simulator install/launch succeeded (PID 46322).
- Capture-loop validation: Xcode build succeeded, simulator install/launch succeeded (PID 76671), and the built app contains `toyota-demo.mov` (25 MB) in its bundle.
- Final capture-loop repair: camera startup now requests `AVCaptureDevice` video authorization when status is `.notDetermined`; denial and unavailable cameras route to the explicit Toyota replay fallback. Toyota MOV sampling keeps one quality analyzer and the prior RGBA frame so motion quality is measured across decoded frames instead of defaulting to zero motion.
- Updated checks: 17 SwiftPM tests pass after adding the previous-frame motion regression test and camera-baseline sensing check. iOS AVFoundation authorization and MOV decode remain device/runtime checks; package tests cover the analyzer's cross-frame behavior.
- Hardware baseline: the core path uses the iPhone 15 Plus RGB camera and available IMU/world tracking. Camera quality, semantic evidence, dynamic region prompts, and replay remain functional on this baseline.

## Bounded design handoff

Next increment: add ARKit pose/motion tracking and live camera-quality prompts behind capability and authorization checks. Keep the replay path as the reliable demo path.

## Blockers and risks

- **Resolved:** Wave 1 authorization received; local model now uses all canonical IDs and states.
- **Resolved:** deterministic replay uses fixed `observedAt` `2026-10-24T00:00:00Z` for every region, including unseen regions, with an explicit note that this is fixture timing rather than evidence.
- **Resolved:** artifact references now point to existing repo-relative `ios/replay/frame-*.json` files; `unknownRegions` includes all partial and unseen regions.
- **Risk:** ARKit pose and camera quality are evidence signals only. They cannot claim hidden mechanical diagnosis; unsupported devices and simulator runs must retain explicit unknown/unseen coverage.
- **Risk:** simulator install and launch are now verified; screenshot tooling remains unavailable, so no visual runtime capture is attached.
- **Risk:** Vision integration currently receives an in-memory handoff envelope; live camera frames are quality-gated in iOS and are not yet sent to Vision's canonical replay adapter.
- **Risk:** Xcode emits a non-fatal traditional headermap warning for the local VisionCore target; the simulator build and launch remain successful.
- **Limitation:** region classification is currently operator-guided (`nextGuideStep`) because exterior pixels alone cannot reliably identify which canonical surface is in frame. The loop never infers hidden coverage; an ARKit/pose classifier can be injected later without changing the progress or contract seam. The supplied Toyota clip remains glare/motion-limited quality evidence only and makes no canonical region or mechanical claim.

No contract files or peer-scope files were edited. The Xcode project compiles CaptureCore sources directly; the SwiftPM target uses `#if SWIFT_PACKAGE import CaptureCore` so both package and app builds remain valid.

## Guided capture increment (2026-10-24)

## Guided repair increment (2026-10-24)

- Capture startup now checks for an AVFoundation camera and opens a configured `AVCaptureSession` with a real `CMSampleBuffer` delegate when available. If unavailable, the UI explicitly offers the bundled video replay fallback; replay frames remain the only synthetic video substitute.
- Live quality metrics now become plain-language retake prompts (hold still, move to even light, steady/reframe), and visible provenance labels distinguish live camera from synthetic replay. User-facing copy avoids raw confidence decimals and enum identifiers.
- A capability-gated ARKit check reports camera + IMU/world tracking support beside AVFoundation capture. Unsupported devices and simulators fall back to camera quality signals or synthetic replay.
- On AR-capable iOS devices, guided capture now presents a full-screen-ready AR camera surface with dark chrome and camera-aligned tracking context; Finish remains explicit about missing coverage and transitions to the rotatable car results view. Simulator/replay retains the existing fallback.
- A2 status: the iPhone 15 Plus RGB camera surface is wired with live pixel analysis and contextual missing-region prompts. Camera-aligned contour geometry is intentionally bounded to a calibrated evidence seam; the current first increment displays the live camera and states that contours appear after calibration rather than fabricating geometry. Device calibration/overlay anchoring remains the blocker before claiming full contour coverage.
- Calibration increment: ARSCNView now enables ARKit's real feature-point debug overlay as white camera-aligned evidence marks and provides a reset-calibration action. These points are tracking evidence only; no vehicle contours, depth, mesh, or surface classification are fabricated. Device capture remains required to validate visual alignment.
- A2 continuous progression: once Start Scan opens AVCaptureSession, every accepted CMSampleBuffer quality result is ingested for the currently prompted region. A covered result automatically advances `nextGuideStep`, updates coverage/progress, and changes the prompt without requiring the per-region Capture button. Low-quality frames remain on the same region with plain-language retake guidance; pause, replay labeling, Finish gating, and unknown unseen regions remain explicit. Optional evidence snapshots and robust region classification remain next dependencies.
- Runtime camera ownership repair: on AR-capable devices, `ARSCNView`/`ARSession` is the single camera producer and its `ARFrame.capturedImage` feeds the same pixel analyzer and progress loop. The separate `AVCaptureVideoDataOutput` path remains only for devices without the AR camera path, avoiding a live preview with zero analyzed frames. Only observed ingest results claim advancement; partial/retake results keep the current prompt.
- Baseline sensing targets iPhone 15 Plus: ordinary RGB camera frames plus available IMU/world tracking. The UI exposes the active camera baseline and falls back to replay when camera/world tracking is unavailable.
- The capture model retains dynamic missing/partial/blocked prompt selection. Region classification remains operator-guided and frame quality is evidence only; no hidden mechanical diagnosis is inferred.

- Route order now starts at `front-left`, follows an explicit clockwise exterior sequence, then roof, interior front/rear, and trunk. Each step carries safety and lower-phone copy.
- Guided controls include Pause/Resume, Skip/blocked, Retake/quality-limited feedback, and a lower-phone action. Synthetic guided attempts intentionally produce partial quality on initial front-left/rear-left captures so retake behavior is demonstrable.
- Results now render Vision `MapPresentation` analysis, unknown regions, colored progressive coverage, and a numbered evidence-backed finding summary with region, confidence, and artifact references. Replay remains the deterministic fallback.
- The primary judge-facing experience is a native SceneKit Tesla-style primitive car (Xcode/iOS path): gray body volume, cabin/windows, four wheels, lights, mirrors/marker surfaces, perspective camera, ambient/omni lighting, and partial/blocked issue markers driven by coverage. The flat region list is retained only as an accessibility/debug fallback when SceneKit is unavailable (including non-Apple SwiftPM environments); no external or licensed asset was added.
- SceneKit/UIKit compilation is gated with `canImport(SceneKit) && canImport(UIKit)`, keeping the macOS SwiftPM target on the SwiftUI fallback.
- Focused tests cover front-left ordering, blocked skip progression, and partial/unknown replay handoff.

- Checks: `swift test --package-path ios --disable-sandbox` (11 passed); `swift build --package-path ios --product CaptureDemo --disable-sandbox` (passed); `xcodebuild -project ios/CaptureDemo.xcodeproj -scheme CaptureDemo -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/toyota-next-move-derived build` (BUILD SUCCEEDED; existing headermap warning only).

- Added `CaptureGuide` and `CaptureGuideStep` in `ios/Sources/CaptureCore/CaptureCore.swift`. The ordered plan covers all 12 canonical regions and uses explicit prompts for front/rear corners, roof, interior front/rear, and trunk. `nextUncovered(in:)` keeps the operator on a partial/failed region until a covered sample is captured.
- Added synthetic progression controls to `ios/Sources/CaptureDemo/CapturePresentation.swift` and a dark SwiftUI guided surface in `ios/Sources/CaptureDemo/CaptureDemoApp.swift`. The prompt card, progress bar, colored 2.5D-style vehicle map, and region labels expose covered/partial/blocked/unseen state; replay remains available at every step.
- Added focused order and progression tests in `ios/Tests/CaptureCoreTests/CaptureCoreTests.swift`.
- Checks: `swift test --package-path ios --disable-sandbox` (9 passed); `swift build --package-path ios --product CaptureDemo --disable-sandbox` (passed); Xcode simulator build for iPhone 17 (passed; existing headermap warning only).
- Assumptions: synthetic capture uses acceptable quality samples to demonstrate state progression; live camera authorization and quality gating are wired, while camera + IMU/world tracking is capability-gated. The map is an accessible SwiftUI approximation using shapes and labels, not metric 3D geometry.
- Remaining limitation: physical-device authorization, AVCapture delivery, and AVFoundation MOV decoding still need device/runtime coverage beyond the simulator. Replay remains the deterministic fallback for simulator/demo use.

### Model-backed perception increment (local, not shipped)

Replaced live prompt-assigned coverage with sampled JPEG -> private perception bridge -> OpenAI image observation -> two-consecutive-frame region confirmation. Both AR and AVCapture input paths use this seam. The model sees the image without a requested-region hint. Nighttime/colored-light frames are allowed when recognizable; pixel sharpness heuristics no longer reject every such observation. Captures record the observed canonical region, not the prompt. Pause/cancel/Finish invalidate pending responses, and live results retain the resulting coverage. Real sampled JPEGs are saved in app cache as evidence; no synthetic finding is inserted in live results.

New integration files: `ios/Sources/CaptureCore/VehiclePerception.swift`, `perception/server.py`, `perception/test_server.py`, `perception/README.md`. Xcode compiles the shared core file; app config uses `PERCEPTION_ENDPOINT` and separate proxy test token. OpenAI key stays server-side. The user has an API/backend account; endpoint/hosting details are still needed to connect it. See perception README for precise setup, retention and evaluation requirements.

Preserves AR direction: camera remains primary and confirmed observations update the existing vehicle indicator; absent/uncertain regions remain neutral. This increment does not create geometry, surface contours, or a polished car asset. Part/orientation recognition is model-estimated and requires real-footage evaluation; left/right may remain unknown. No TestFlight archive/upload requested or performed for this change.
