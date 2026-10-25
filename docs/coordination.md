# Coordination and integration log

## Scope correction — 2026-10-24

Contract-dependent implementation is frozen until this file and `docs/contracts/README.md` are canonical. Contract version is **0.1.0**. Coordinator owns `docs/contracts/`, `docs/architecture.md`, and this file. Strict ownership: iOS → `ios/`, `docs/modules/ios-capture/`; Vision → `vision/`, `docs/modules/vision/`; Product/UX → `docs/product-design/` and later assigned UI files; QA → `docs/quality/`. Do not overwrite another lead's uncommitted files.

## Integration order

1. Contracts and design assumptions reviewed by all leads.
2. iOS shell + deterministic replay produces a valid `ScanSession`.
3. Vision fixture adapter consumes replay artifacts and emits map/findings.
4. UX wires journey/copy and recommendation presentation.
5. QA runs contract checks, mobile verification, accessibility and judge rehearsal.
6. Coordinator performs integration review after each milestone and records blockers here.

## Milestones

- M0 contracts/docs (now): schemas, region IDs, architecture, product brief, ownership.
- M1 capture vertical slice: Start scan, coverage checklist, replay export.
- M2 vision slice: map, findings, explicit unknown/unseen states.
- M3 recommendation slice: synthetic profile/agreement and one next move.
- M4 demo hardening: QA gates, accessibility, deterministic replay, final independent review.

## Current blockers

- No blockers to contract review; app implementation is intentionally paused until lead alignment.
- Shared root contains pre-existing untracked `docs/quality/` files from QA; preserve them and do not stage as coordinator-owned.

## Decision log

- D-001: Use stable region IDs above; exterior and interior are distinct. (Coordinator, 2026-10-24)
- D-002: `unseen`, `blocked`, and `unknown` are explicit states; absence of evidence is not a clean result. (Coordinator, 2026-10-24)
- D-003: Synthetic replay is a supported demo mode, not a test-only shortcut. (Coordinator, 2026-10-24)
- D-004: Recommendation is a single `nextMove` with caveats and confidence. (Coordinator, 2026-10-24)

## Integration checklist

- [ ] Every lead acknowledges contracts v0.1.0 and ownership boundaries.
- [ ] iOS emits valid ScanSession/CoverageRegion JSON and artifact refs.
- [ ] Vision consumes only canonical fields and preserves uncertainty.
- [ ] UX copy labels findings as visible/non-diagnostic and exposes unseen regions.
- [ ] QA contract, accessibility, mobile and demo checks pass.
- [x] Fresh independent review covers final shared tree before implementation authorization (superseded by the final Wave 2 review below).

## Contract review updates — 2026-10-24

- QA blockers resolved by `docs/contracts/CONVENTIONS.md`: local relative `$ref` registry, repo-relative evidence joins, unseen timestamp policy, and 12-region denominator.
- Vision blocker resolved: map/rule metadata remains module-local until a later version; evidence refs are opaque repo-relative paths; unseen uses session start time.
- UX blocker deferred by design: v0.1.0 intentionally has no cost/trade-off/customer fields; recommendation rationale/caveats/basedOn must explain limits and use `review_with_customer` when context is insufficient.
- iOS blocker remains for Wave 1: adapter must map local 8-region prototype to all 12 canonical IDs and canonical states; deterministic replay must use the timestamp convention; device scheme is required before M1 acceptance.

## Review status

Independent Sentinel contract/docs review task was launched against the shared tree (fresh task ID retained in thread evidence). JSON parsing passed for all seven schemas. Review is incomplete until the independent report returns; Wave 1 remains unauthorized.

## Repair pass — 2026-10-24

Accepted Sentinel findings: unresolved nested refs, weak 12-region shape, unconstrained finding region/evidence, and prose-only escalation. Repairs: exact versioned `$ref` URIs plus `registry.json`; 12-item distinct array constraints and canonical unknown IDs; canonical finding region IDs with non-empty evidence; required machine-readable `Recommendation.escalation`. Property-level region uniqueness remains a documented semantic boundary assertion. Wave 1 remains frozen pending fresh verification of this repaired snapshot.

## Repair pass 2 — 2026-10-24

Added `docs/contracts/validate_contracts.py` and required its registry plus exact-12-region semantic check at M1. Unified artifact refs to repo-relative POSIX paths; app sandbox/URL refs are out of v0.1.0. Fresh verifier's remaining stale-handoff issue is delegated to Vision and QA owners for their own files. Wave 1 remains frozen until a fresh review of this final contract change passes.

## Wave 1 authorization — 2026-10-24

Fresh independent contract verification passed on repaired scope. Wave 1 is authorized only for two bounded tasks:

- **iOS:** adapt the local eight-region capture model to the canonical twelve-region `CoverageRegion` adapter, emit `ScanSession` JSON, preserve deterministic synthetic replay, and create/verify an installable iOS scheme. Acceptance: `python3 docs/contracts/validate_contracts.py` passes against a replay fixture; all 12 IDs occur exactly once; replay uses canonical `unseen/partial/covered/blocked`, repo-relative artifact refs, and `observedAt`; `swift test` passes; scheme/device evidence is recorded in the iOS handoff. Do not edit contracts or other scopes.
- **QA:** convert acceptance gates into executable contract/replay checks and validate the integrated vertical slice. Acceptance: registry/ref checks, valid and duplicate-region fixtures, replay sequence coverage, escalation/unknown-state assertions, and a documented installable-scheme/device matrix. Do not edit contracts or iOS/Vision/UX scopes.

Dependencies: iOS provides the replay JSON and scheme evidence first; QA consumes those artifacts and validates the full sequence. Preserve the replay path. Any blocker goes here before scope expansion.

## M1 integration review — 2026-10-24

QA Wave 1 checks pass: registry/refs, valid and duplicate-region fixtures, exact-12 denominator, unseen semantics, safety copy, and replay checks. `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` passes.

**Blocker:** iOS `CaptureDemo` does not compile. `swift build --package-path ios --product CaptureDemo --disable-sandbox` reports `CaptureReplay` and `CaptureRegion` not found in `Sources/CaptureDemo/CaptureDemoApp.swift`; therefore no installable scheme/device evidence exists yet. iOS must repair within `ios/` and update its handoff. Coordinator has not edited peer files.

QA follow-up: `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json` currently fails because the canonical ScanSession correctly rejects a non-contract `sequence` field and the runner expects one. QA must keep the wire fixture canonical and move stage-sequence validation to QA-owned scenario metadata or an explicit CLI sequence fixture.

## MVP priority update — 2026-10-24

User confirmed MVP core functionality takes priority while Toyota videos are collected. Defer nonessential security hardening and advanced AR/model work. Preserve only core contract, evidence, uncertainty, and no-hidden-diagnosis behavior. Current focus: runnable Start scan → guided coverage → replay → map → visible findings → recommendation.

## Wave 1 repair update — 2026-10-24

 iOS repaired the SwiftPM CaptureDemo dependency and refreshed its handoff. Contract/replay validation, 5 Swift tests, SwiftPM product build, and Xcode simulator build all pass; the app bundle is at `/tmp/toyota-next-move-derived/Build/Products/Debug-iphonesimulator/CaptureDemo.app`. Runtime install/launch remains unconfirmed because simulator/device support communication hung/failed. Fresh iOS Wave 1 review is still pending; do not mark M1 review-ready until it returns.

## MVP journey refinement — 2026-10-24

Product/UX narrowed the judge path to start/replay → three guided positions (saved, glare-limited, unseen) → one visible finding → one `Recommendation.nextMove` with bounded rationale/caveats → human/scenario action. Decorative map polish, animation, advanced rotation, financial comparisons, and secondary branching are deferred; accessibility and unknown/unseen states remain required.

## Vision MVP priority — 2026-10-24

Vision prioritizes replay → progressive 2.5D map → visible findings. Advanced models and security work are deferred. `recommendedCheck` ownership and `unknownRegions` propagation remain explicit seams; hidden mechanical diagnosis remains prohibited. Vision contract validator and independent review passed.

## M1 final integration review — 2026-10-24

Fresh independent iOS review passed with no actionable findings. Final replay uses repo-relative `ios/replay/frame-###.json` refs; all 11 referenced artifacts resolve. `interior-rear` and `trunk` remain unseen, and `unknownRegions` includes partial plus unseen IDs. Validator, 5 Swift tests, CaptureDemo product build, and Xcode iPhone 17 simulator scheme build pass. Runtime install/launch remains unconfirmed because device support communication fails; the simulator app bundle is available at `/tmp/toyota-next-move-derived/Build/Products/Debug-iphonesimulator/CaptureDemo.app`.

## Simulator packaging fix — 2026-10-25

After host restart, iPhone 17 booted normally. Simulator install initially failed because `ios/CaptureDemo/Info.plist` lacked `CFBundleExecutable`; coordinator added standard executable/version keys within the iOS-owned scope, rebuilt, installed, and launched `com.toyota.nextmove.capture-demo` successfully (PID 4610). Device screenshot tooling still reports unavailable. iOS lead was notified to review and record the fix in its handoff.

## Video fixture handling — 2026-10-25

`IMG_1404.mov` is not present in the shared repo/filesystem for lead workflows. No copy, derived frames, or fixture changes were made. Until the source is shared through the workspace, it is only a provisional low-light/glare/motion-blur partial-quality description; it is not full replay or damage/mechanical evidence.

## Video fixture classification — 2026-10-25

Vision documented `IMG_1404.mov` as quality/coverage-only: ~30s, 1920x1080, close side/rear, strong blue lighting and motion blur. It supports partial/glare-limited evidence only; no finding is claimed. Interior/front/roof/trunk remain unseen. No media was added or modified. Contract validator passed; Vision's final independent review remains pending.

## Wave 2 parallel start — 2026-10-25

User requested faster development and pragmatic use of low-quality video. Existing iOS, Vision, UX, and QA leads are working concurrently in owned scopes on replay → map → visible finding → recommendation. Low-quality video is treated as useful partial/glare-limited quality evidence; it must drive gating/unknown states, not an unsupported finding. Each lead must return files, checks, assumptions, risks, and blockers before integration review.

## Wave 2 continuation — 2026-10-25

User requested continuation for all leads, including runs that hit limits. Existing lead threads were resumed from their latest handoffs without duplicate restarts. Scope remains strict: iOS `ios/` + iOS handoff; Vision `vision/` + Vision handoff; UX `docs/product-design/`; QA `docs/quality/`. Coordinator will integrate only after each returns incremental checks and blockers.

## Wave 2 iOS wiring update — 2026-10-25

 iOS added an app-internal `VisionHandoff` around canonical `ScanSession` JSON, artifact refs, unknown regions, and quality-limited regions. No wire schema or finding/recommendation fields changed; replay remains unchanged. Swift tests (6), SwiftPM build, contract validator, and Xcode iPhone 17 simulator build/install/launch passed (PID 15529). Independent Wave 2 review remains pending; screenshot tooling is unavailable.

## Wave 2 Vision implementation update — 2026-10-25

Vision added `vision/` VisionCore package/tests and updated its design/handoff. Replay frames map only supported canonical regions; low/glare/motion quality becomes partial; IMG_1404 remains quality-only with no findings; non-covered regions populate `unknownRegions`; visible findings require evidence and `not_a_diagnosis`; Vision owns factual `recommendedCheck`, UX owns presentation. Vision tests (3) and contract validation pass. Fresh independent verification is pending.

## Orchestration continuity — 2026-10-25

T3 usage-limit notices are being treated as transient orchestration interruptions per user direction. All four leads were told to continue from their latest handoffs without duplicating completed work. Independent review tasks remain separately tracked.

## Wave 2 judge rehearsal — 2026-10-25

UX added `docs/product-design/wave-2-judge-script.md`: 75-second map → glare/unseen → finding → recommendation → human/scenario action, with VoiceOver, recovery beats, synthetic evidence labeling, and acceptance cues. Focused checks pass; no schema/UI/peer files changed. Remaining UX blockers are coordinator authorization for iOS implementation and explicit local synthetic fixtures.

## Wave 2 Vision repair — 2026-10-25

Vision repaired verifier findings: quality gate now requires acceptable/high quality with no glare or motion blur; flagged frames remain partial and in `unknownRegions`. Finding descriptions sanitize safety/hidden-mechanical claims to an explicit unknown/review statement, with negative regression coverage. `IMG_1404` remains quality-only with no media copy. Vision tests (5) and contract validation pass. Fresh independent repair review remains pending.

## Extensive Wave 2 code review — 2026-10-25

Six-reviewer T3 wave launched against snapshot `aee424534cf035ba22b2be10d7cba6b26cb6bb44ed041175a5cae8ffd2256b7b`; source coverage complete. Review-only; no repairs applied.

Consolidated actionable findings:

- **High:** CaptureDemo is a static final coverage list; no Start/guided/replay stages, map, finding, evidence, recovery, or recommendation journey.
- **High:** Vision replay always returns `findings: []`; no executable annotated finding producer.
- **High:** No VehicleProfile/Agreement/DemoScenario/Recommendation producer or consumer; the required domain-to-recommendation path is absent.
- **High:** Diagnostic sanitizer still permits claims such as engine healthy, no damage, bent frame, and brakes functioning; status alone is insufficient.
- **High:** Vision finding decoding bypasses invariants; invalid confidence/status/evidence can decode, while factory preconditions crash on bad input.
- **Medium:** Empty artifact/evidence refs can mark coverage or support findings.
- **Medium:** Conflicting duplicate frame IDs can produce order-dependent quality/evidence output.
- **High:** Contract validator checks registry/semantic replay shape but does not validate JSON Schema required fields, types, formats, enums, extras, or nested data.
- **High:** QA Wave 2 fixture can accept a visible finding in an unseen/blocked region and is disconnected from executable iOS/Vision output.
- **Medium:** Safety escalation is fixture-required but not derived from finding severity/hazard content.
- **Medium:** Synthetic/live provenance is not enforced at the Vision boundary.
- **High:** Low-confidence, unseen, blocked, and financial `review_with_customer` recommendation rules are documentation/fixture-only.

Review coverage: Vision correctness, iOS/spec, contracts/QA, recommendation/evidence flow completed. Runtime packaging reviewer failed after 429; standards reviewer remains running. Review verdict: **changes_requested / incomplete until remaining reviewers return**. No code review readiness or Wave 2 acceptance claimed.

## Review repair authorization — 2026-10-25

User authorized repairs. iOS seam approved: local VisionCore dependency/direct Xcode source compilation with an app-internal presentation model; iOS owns recommendation presentation rules, Vision owns canonical findings/recommendedCheck. Coordinator repaired `docs/contracts/validate_contracts.py` with dependency-free validation of required fields, types, enums, constants, formats, additional properties, nested refs, bounds, and array constraints; valid replay passes and missing required `id` is rejected.

## Repair integration check — 2026-10-25

Vision SwiftPM tests (6), iOS SwiftPM tests (6), contract validation, and Wave 2 QA checks pass. Xcode integration currently fails because `CaptureDemo.xcodeproj` resolves VisionCore as `/ios/vision/...` instead of repo-root `/vision/...`; iOS lead was sent the exact path repair. Wave 2 acceptance remains blocked on that Xcode build plus fresh review.

## Wave 2 MVP repair and final integration — 2026-10-24

iOS repaired the integration seam in its owned files. The app now runs the canonical VisionCore synthetic replay from both SwiftPM and Xcode, enters an explicit guided-replay loading state, displays the evidence-backed visible finding with a `Demo · synthetic image` label and factual `recommendedCheck`, presents one app-internal recommendation with canonical `nextMove`/rationale/confidence/caveats/basedOn/escalation fields, and exposes a deliberate human-review action. The wire contracts remain unchanged; the recommendation model is presentation-only and uses `request_more_views` when partial/unseen regions remain.

The final repair pass also made the replay evidence join to the checked-in `ios/replay/frame-005.json`, replaced swallowed Vision failures with an explicit retry state, rendered Vision-derived per-region state/quality rows, and exposed finding location, confidence, status, evidence, and recommendation `basedOn` identifiers to assistive technology.

Integration evidence:

- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — passed; registry contains 7 schemas and the replay has 12 distinct canonical regions.
- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` — passed.
- `python3 docs/quality/wave2_checks.py ios/replay/replay-scan-session.json docs/quality/fixtures/wave2-analysis.json` — passed.
- `swift test --package-path ios --disable-sandbox` — 7 passed.
- `swift test --package-path vision --disable-sandbox` — 6 passed.
- `swift build --package-path ios --product CaptureDemo --disable-sandbox` — passed.
- Xcode `CaptureDemo` / iPhone 17 simulator build — passed; install and launch succeeded for `com.toyota.nextmove.capture-demo` (PID 48763 in the coordinator verification run).
- `git diff --check` — passed.

Fresh independent repair review passed with complete coverage and no actionable findings at the current untracked working tree (HEAD remains `c1fd425d50d1a7f199c6623c32399782f9bf6d4c`; source identity is HEAD plus the current untracked `docs/`, `ios/`, and `vision/` tree). The only reported build limitation is Xcode's non-fatal traditional headermap warning; simulator screenshot tooling remains unavailable. Live camera/ARKit behavior, TestFlight signing, and real-vehicle capture remain outside this local simulator acceptance evidence. The supplied `IMG_1404.mov` remains quality/coverage-only and is not used as damage or mechanical evidence.

## Synthetic replay integration checklist — 2026-10-24

- [x] Contracts v0.1.0 and ownership boundaries are canonical.
- [x] iOS emits a valid 12-region replay and preserves partial/unseen uncertainty.
- [x] Vision emits an evidence-backed visible observation while rejecting unsupported diagnosis claims.
- [x] UX-required start, guided, replay, map/findings, recommendation, and human-action sequence is runnable in the simulator build using deterministic synthetic data.
- [x] QA contract, replay, uncertainty, provenance, escalation, and no-diagnosis checks pass.
- [x] Fresh independent final review reports no actionable findings.

This checklist verifies the current synthetic replay MVP only. It does not claim live camera/ARKit capture, production 3D reconstruction, or the final customer/vehicle/loan/lease recommendation path.

## Guided synthetic capture prototype — 2026-10-24

The current product slice is implemented in bounded peer scopes. iOS adds an ordered guided route with explicit direction/open-trunk prompts, synthetic capture progression, a dark navy prompt/progress shell, a simple shape-based progressive coverage map, and replay fallback. Vision adds `MapPresentation` with canonical region state/quality, gray unknown semantics, attached findings, accessibility text, and bounded non-diagnostic analysis. UX documents the Tesla-like top-step treatment, fingerprint-style progressive coloring, final issue labels, and recovery/accessibility acceptance. Contracts remain v0.1.0 and unchanged. Live camera/ARKit ingestion, a polished surface-anchored 3D vehicle asset, and financial-domain personalization remain follow-on work.

Integration checks passed: Vision tests (8), iOS tests (9), SwiftPM CaptureDemo build, contract validator, Wave 1 checks, Wave 2 checks, `git diff --check`, and Xcode iPhone 17 simulator build/install/launch (PID 58248). The build still uses deterministic synthetic samples; live camera/ARKit frame ingestion and actual image-based issue detection remain the next implementation step. Review is not accepted until the fresh independent guided-slice verifier reports its result.

## 3D hero pivot and repair — 2026-10-24

The flat labeled outline is now explicitly debug/accessibility-only. iOS adds a conditional SceneKit hero for iOS builds: a synthetic Toyota-like vehicle assembled from native primitives with body, cabin/windows, wheels, lights, perspective camera, lighting, coverage-driven materials, and anchored issue markers. Unseen surfaces stay neutral gray; partial surfaces use amber; covered surfaces resolve with restrained color. SwiftUI remains the fallback where SceneKit/UIKit are unavailable. Vision's merge reducer now supports clear-frame recovery after an unflagged low-quality frame while keeping glare/motion uncertainty sticky.

Current checks: iOS tests (11), Vision tests (9), SwiftPM CaptureDemo build, Xcode iPhone 17 simulator build, contract validator, Wave 1/2 QA checks, and `git diff --check` pass. A fresh independent 3D review is required before this visual slice is accepted. External USDZ/glTF asset ownership is still open; the current hero is deliberately synthetic and native.
