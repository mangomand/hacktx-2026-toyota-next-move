# iOS capture lead handoff

Status: **Wave 2 MVP flow wired; awaiting coordinator integration review**
Contract alignment: **canonical v0.1.0 adapter and replay fixture implemented**

## Scope and alignment

The coordinator owns `docs/contracts/` and `docs/coordination.md`. I acknowledge canonical contract version **0.1.0** and the iOS ownership boundary (`ios/` and this module directory). The canonical `CoverageRegion` contract has 12 stable IDs:

`front`, `front-left`, `left`, `rear-left`, `rear`, `rear-right`, `right`, `front-right`, `roof`, `interior-front`, `interior-rear`, `trunk`.

The capture core now uses all 12 canonical IDs and maps quality outcomes to canonical `covered`/`partial` states while retaining explicit `unseen` and `blocked`. `CaptureReplay.sessionJSON()` emits the v0.1.0 `ScanSession` shape with exactly one record per region, `schemaVersion`, replay mode, and repository-relative artifact references.

Wave 2 adds `CaptureReplay.visionHandoff()`. It passes the canonical `ScanSession` JSON plus local routing metadata for Vision: replay artifact refs, `unknownRegions`, and `qualityLimitedRegions`. This is an app-internal handoff envelope, not a competing wire schema. Vision must consume the embedded canonical payload and preserve partial/unseen uncertainty; the handoff emits no findings or recommendation fields, while iOS presentation derives only the approved next move from coverage state.

The judgeable app loop is now Start scan → guided coverage checklist → synthetic replay → Vision map/findings summary → one next move. The start and replay buttons have accessibility identifiers, coverage rows expose region/state labels, and results present `request_more_views` whenever any region is partial or unknown. The replay currently produces no findings; the UI states that explicitly rather than inventing one.

## Current files and checks

- `ios/Package.swift`
- `ios/Sources/CaptureCore/CaptureCore.swift`
- `ios/Tests/CaptureCoreTests/CaptureCoreTests.swift`
- `ios/Sources/CaptureDemo/CaptureDemoApp.swift`
- `ios/Sources/CaptureCore/CaptureCore.swift` (`VisionHandoff`)
- `ios/Sources/CaptureDemo/CapturePresentation.swift` (MVP state flow and Vision presentation)
- `vision/` is consumed as a local SwiftPM dependency; its source remains coordinator/Vision-owned and unchanged.
- `ios/CaptureDemo.xcodeproj/` and `ios/CaptureDemo/Info.plist`
- `ios/replay/replay-scan-session.json` and `ios/replay/README.md`
- `swift test --package-path ios --disable-sandbox` — 7 tests passed, including the Vision dependency partial/unseen integration test.
- `swift build --package-path ios --product CaptureDemo --disable-sandbox` — passed.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — validated 7-schema registry and 12-region ScanSession.
- `xcodebuild -project ios/CaptureDemo.xcodeproj -scheme CaptureDemo -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/toyota-next-move-derived build` — **BUILD SUCCEEDED**, producing `/tmp/toyota-next-move-derived/Build/Products/Debug-iphonesimulator/CaptureDemo.app`.
- Coordinator-applied packaging fix verified in `ios/CaptureDemo/Info.plist`: `CFBundleExecutable=$(EXECUTABLE_NAME)`, short version `0.1`, and build `1`. Rebuilt, installed, and launched on booted iPhone 17 simulator (`com.toyota.nextmove.capture-demo`, PID 5447); `simctl get_app_container` and built plist confirm executable `CaptureDemo`.
- Fresh independent verification: **passed**, no actionable findings; generated JSON matches the checked-in fixture and all 11 artifact references resolve.
- Wave 2 handoff test: `CaptureReplay.visionHandoff()` preserves canonical JSON, reports `rear-left`/`front-right` as quality-limited, and reports `interior-rear`/`trunk` as unknown.
- Xcode scheme now builds a separate local `VisionCore` static target from `../../vision/Sources/VisionCore/VisionCore.swift`, links it into `CaptureDemo`, and installs/launches on iPhone 17 simulator (PID 40803).
- Repair validation: Xcode path now invokes `VisionCore.SyntheticReplay` in the simulator target, guided replay visibly enters the replay screen before results, and the guided replay control has accessibility identifier `guided-replay`; simulator install/launch succeeded (PID 46322).

## Bounded design handoff

Next increment: add ARKit pose/motion tracking and live camera-quality prompts behind capability and authorization checks. Keep the replay path as the reliable demo path.

## Blockers and risks

- **Resolved:** Wave 1 authorization received; local model now uses all canonical IDs and states.
- **Resolved:** deterministic replay uses fixed `observedAt` `2026-10-24T00:00:00Z` for every region, including unseen regions, with an explicit note that this is fixture timing rather than evidence.
- **Resolved:** artifact references now point to existing repo-relative `ios/replay/frame-*.json` files; `unknownRegions` includes all partial and unseen regions.
- **Risk:** ARKit pose and camera quality are evidence signals only. They cannot claim hidden mechanical diagnosis; unsupported devices and simulator runs must retain explicit unknown/unseen coverage.
- **Risk:** simulator install and launch are now verified; screenshot tooling remains unavailable, so no visual runtime capture is attached.
- **Risk:** Vision integration currently receives an in-memory handoff envelope; no cross-module transport or live camera producer is wired yet.
- **Risk:** Xcode emits a non-fatal traditional headermap warning for the local VisionCore target; the simulator build and launch remain successful.

No contract files or peer-scope files were edited. The Xcode project compiles CaptureCore sources directly; the SwiftPM target uses `#if SWIFT_PACKAGE import CaptureCore` so both package and app builds remain valid.

## Guided capture increment (2026-10-24)

## Guided repair increment (2026-10-24)

- Route order now starts at `front-left`, follows an explicit clockwise exterior sequence, then roof, interior front/rear, and trunk. Each step carries safety and lower-phone copy.
- Guided controls include Pause/Resume, Skip/blocked, Retake/quality-limited feedback, and a lower-phone action. Synthetic guided attempts intentionally produce partial quality on initial front-left/rear-left captures so retake behavior is demonstrable.
- Results now render Vision `MapPresentation` analysis, unknown regions, colored progressive coverage, and a numbered evidence-backed finding summary with region, confidence, and artifact references. Replay remains the deterministic fallback.
- The vehicle hero is now a native SceneKit primitive scene (Xcode/iOS path): gray body volume, cabin/windows, four wheels, lights, mirrors/marker surfaces, perspective camera, ambient/omni lighting, and partial/blocked issue markers driven by coverage. The SwiftUI flat map remains the fallback when SceneKit is unavailable (including non-Apple SwiftPM environments); no external or licensed asset was added.
- SceneKit/UIKit compilation is gated with `canImport(SceneKit) && canImport(UIKit)`, keeping the macOS SwiftPM target on the SwiftUI fallback.
- Focused tests cover front-left ordering, blocked skip progression, and partial/unknown replay handoff.

- Checks: `swift test --package-path ios --disable-sandbox` (11 passed); `swift build --package-path ios --product CaptureDemo --disable-sandbox` (passed); `xcodebuild -project ios/CaptureDemo.xcodeproj -scheme CaptureDemo -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/toyota-next-move-derived build` (BUILD SUCCEEDED; existing headermap warning only).

- Added `CaptureGuide` and `CaptureGuideStep` in `ios/Sources/CaptureCore/CaptureCore.swift`. The ordered plan covers all 12 canonical regions and uses explicit prompts for front/rear corners, roof, interior front/rear, and trunk. `nextUncovered(in:)` keeps the operator on a partial/failed region until a covered sample is captured.
- Added synthetic progression controls to `ios/Sources/CaptureDemo/CapturePresentation.swift` and a dark SwiftUI guided surface in `ios/Sources/CaptureDemo/CaptureDemoApp.swift`. The prompt card, progress bar, colored 2.5D-style vehicle map, and region labels expose covered/partial/blocked/unseen state; replay remains available at every step.
- Added focused order and progression tests in `ios/Tests/CaptureCoreTests/CaptureCoreTests.swift`.
- Checks: `swift test --package-path ios --disable-sandbox` (9 passed); `swift build --package-path ios --product CaptureDemo --disable-sandbox` (passed); Xcode simulator build for iPhone 17 (passed; existing headermap warning only).
- Assumptions: synthetic capture uses acceptable quality samples to demonstrate state progression; live camera and ARKit producers remain outside this slice. The map is an accessible SwiftUI approximation using shapes and labels, not metric 3D geometry.
- Remaining limitation: no live camera authorization, pose tracking, or automatic quality signal is wired. Replay is still the deterministic fallback for simulator/demo use.
