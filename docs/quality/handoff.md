# Quality lead handoff

## Files

- `docs/quality/acceptance-checklist.md` — traceable vertical-slice gates, evidence packet, and stop rules.
- `docs/quality/test-strategy.md` — contract/schema invariants, deterministic fixtures, uncertainty proof, and safety checks.
- `docs/quality/demo-runbook.md` — simulator/device matrix, fallback behavior, and timed judge script.

## Historical discovery checks (2026-10-24)

- Sentinel baseline captured at `da75640b06ace05ab2f144f11511d34ff398109ed28e89bcbbd5d921c29f1f09` against HEAD `c1fd425d50d1a7f199c6623c32399782f9bf6d4c`; coverage complete, zero omissions.
- Initial discovery (`rg --files --hidden -g '!\.git'`) recorded only `README.md` and `assets/icon.svg`; canonical contracts and peer iOS files were added later by their owners.
- `xcrun simctl list devices booted` — booted iOS 26.5 simulators were available, but runtime communication/install evidence was unavailable at discovery time.
- No product tests were executed in this initial discovery snapshot; this historical result is superseded by the current Wave 2 checks below.

## Assumptions and blockers

- Canonical contracts v0.1.0 now exist under `docs/contracts/`; QA assertions align to those schemas and preserve coordinator ownership.
- **Resolved:** the coordinator-approved local `$ref` registry and format-validation policy are the source of truth for schema checks.
- **Resolved:** artifact joins (`evidenceRefs`, `basedOn`, `findingIds`, and scenario-local references) must resolve within the active scenario; broken or cross-scenario references fail validation.
- **Resolved:** `observedAt` is required by `CoverageRegion` but does not make an `unseen` region inspected; only a passed capture-quality gate may produce `covered`.
- Coordinator must provide an installable Xcode scheme/build and identify the supported iOS version/device matrix before mobile or judge gates can be marked executed.
- No wire-schema fixture is checked in; test vectors must be derived from canonical v0.1.0 after Wave 1 authorization.
- Final acceptance and integration are owned by the coordinator.

## Contract v0.1.0 alignment (2026-10-24)

Read `docs/contracts/README.md`, `docs/coordination.md`, and all seven canonical schemas. QA aligns to the 12 region IDs, `CoverageRegion` states/quality, `ScanSession` replay mode, `Finding` evidence/status, `Recommendation.nextMove`, and synthetic `VehicleProfile`/`Agreement` provenance. No canonical schema was edited. Contract-dependent implementation remains frozen pending explicit coordinator Wave 1 authorization.

Remaining schema/policy blockers: define the capture-quality gate, coverage denominator, and escalation thresholds; confirm customer context is intentionally absent from v0.1.0. These remain policy/semantic inputs, not QA wire-shape changes.

Final Sentinel snapshot after the latest QA-only edits: `71aaa743fb21f62895613a823e8e5fff5d2beae51cb4f17bc89252673767d218`, coverage complete. An earlier verifier was correctly invalidated when peer `ios/` files appeared; QA did not inspect or edit those files. A fresh verifier is running against the final QA snapshot.


## Wave 1 executable checks (authorized)

Added QA-owned `docs/quality/wave1_checks.py` and contract-derived fixtures under `docs/quality/fixtures/`. The runner is stdlib-only, read-only, and accepts an optional iOS replay JSON path whose `sequence` must equal `start_scan → coverage → replay → map_findings → recommendation`. It checks the local registry and `$ref` targets, valid and duplicate-region cases, all 12 canonical regions and denominator, unseen timestamp semantics, unknown-region preservation, non-diagnostic finding copy/evidence, and one recommendation with caveat/basis.

Checks run:

- `python3 docs/quality/wave1_checks.py` — passed.
- `swift test --package-path ios` — historical result: 9 tests, 0 failures. Current result is recorded below; QA did not edit the iOS-owned package.
- `git diff --check` — passed.

Assumptions: the coordinator-approved local registry and conventions govern reference resolution; QA fixtures are contract-derived test vectors, not alternate wire schemas. The iOS replay JSON will be supplied as an argument after its producer publishes it.

Historical risks/blockers at that point: no iOS replay artifact or installable Xcode scheme/device evidence was available; current replay/build results are recorded below. Capture-quality thresholds, coverage denominator semantics, and escalation policy are consumed as coordinator decisions.

## M1 integration repair (2026-10-24)

The iOS replay is canonical `ScanSession` JSON and correctly has no `sequence` field. QA repaired `wave1_checks.py` so the positional argument is validated only as a canonical ScanSession; stage order is validated separately from QA-owned `docs/quality/fixtures/replay-sequence.json`, or an explicit `--sequence <path>` fixture. No contract, iOS, Vision, or UX file was changed.

Exact checks run:

- `python3 docs/quality/wave1_checks.py` — passed against the QA valid and duplicate fixtures plus the default QA sequence fixture.
- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json` — passed canonical ScanSession checks without reading a nonexistent `sequence` field.
- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` — passed canonical ScanSession checks plus `start_scan → coverage → replay → map_findings → recommendation`.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — passed registry and canonical ScanSession validation; 7 schemas loaded.
- `git diff --check` — passed.

The integrated replay currently contains all 12 canonical regions and remains usable for coverage assertions. Full map/findings/recommendation execution and installable scheme/device evidence remain separate blockers until those artifacts are supplied.

## MVP priority (coordinator direction)

MVP validation order is now: (1) canonical synthetic replay from Start scan through coverage, replay, map/findings, and one recommendation; (2) installable iOS build and supported simulator/device evidence; (3) contract, uncertainty/unknown-region, and no-diagnosis gates as mandatory acceptance criteria throughout. Broader security hardening is deferred and is not a prerequisite for this MVP pass, but remains a follow-up risk. Existing replay/schema and installable-build blockers remain active until evidence is supplied.

## M1 final artifact verification (2026-10-24)

Reran QA against `ios/replay/replay-scan-session.json` with sequence validation kept outside the wire JSON:

- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` — passed registry/ref checks, valid/duplicate fixtures, 12-region denominator, unseen timestamps, partial/unseen unknownRegions, no-diagnosis copy, and the separate replay sequence fixture.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — passed; all 7 schemas loaded.
- Artifact join check — passed; 11 referenced frame/README artifacts resolve locally.
- `swift test --package-path ios` — historical M1 result: 5 tests, 0 failures.
- `swift build --package-path ios` — historical M1 result: passed.

M1 quality gates met for the canonical replay artifact, contract validation, 12-region coverage semantics, explicit partial/unseen unknown regions, artifact joins, deterministic replay tests, no-diagnosis guard, and build/test evidence. `rear-left`, `front-right`, `interior-rear`, and `trunk` remain explicitly unknown/unseen in the artifact.

Runtime limitation: simulator support communication failed, so no live simulator/device launch, camera/permission/interruption run, or installable app UI verification was completed. M1 runtime/device gate remains open pending a successful simulator/device communication session. Sequence validation remains QA metadata only and is not added to `ScanSession`.

## Wave 2 QA checks (2026-10-24)

Added QA-owned `docs/quality/wave2_checks.py` and `docs/quality/fixtures/wave2-analysis.json`. The analysis fixture carries map/finding/recommendation metadata and the stage sequence outside canonical `ScanSession` wire JSON. It consumes the final iOS replay artifact without modifying it.

Exact checks and results:

- `python3 docs/quality/wave2_checks.py` — passed replay → map → finding → recommendation, partial/low-quality evidence, explicit unknownRegions, evidence reference resolution, escalation, and no-diagnosis copy.
- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` — passed existing contract/replay checks with sequence metadata outside ScanSession.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — passed; all 7 schemas loaded.
- `swift test --package-path ios` — passed: 6 tests, 0 failures.
- `git diff --check` — passed.

Wave 2 assertions include: exact 12-region map source, partial low-quality `rear-left`/`front-right`, unseen `interior-rear`/`trunk`, unknownRegions equality, all evidence refs resolving to the final replay artifact set, finding status limited to review/non-diagnostic/unseen, recommendation `more_evidence` escalation with resolved `basedOn`, and explicit hidden-mechanical-condition limitation. No contracts, iOS, Vision, or UX files were changed.

Blockers: no live simulator/device communication, camera/permission/interruption evidence, or installable UI runtime proof; the QA analysis fixture is deterministic acceptance metadata and not a claim that a Vision implementation produced the finding/recommendation. Broader security hardening remains deferred per MVP priority.

Sentinel final snapshot for Wave 2 QA-only changes: `1eb13ea7f39f24a061234316d9ae1ed3d6bfdb80d4fbf589976e6b49e069adbe1`; coverage complete. Independent final reviewer task was attempted with medium/default settings but failed after provider retries with HTTP 429, so external review coverage is incomplete; no claim of reviewer approval is made.

## Wave 2 continuation: UX/Vision acceptance (2026-10-24)

Extended `wave2_checks.py` and added `fixtures/blocked-region-case.json`, keeping all analysis/stage metadata outside canonical `ScanSession`. Checks now cover covered, partial/glare-limited low-quality, unseen, and blocked states; exact unknownRegions; evidence refs; map→finding region/evidence traceability; `more_evidence` escalation; and UX copy that explicitly says unable to assess without hidden-mechanical diagnosis.

Exact checks/results:

- `python3 docs/quality/wave2_checks.py ios/replay/replay-scan-session.json` — passed replay→map→finding→recommendation, covered/partial/unseen/blocked, low-quality evidence, unknownRegions, evidence refs, escalation, and no-diagnosis copy.
- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` — passed; sequence remains separate metadata.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — passed; 7 schemas loaded.
- `swift test --package-path ios` — passed: 6 tests, 0 failures.
- `swift build --package-path ios` — passed.
- `git diff --check` — passed.

Blockers unchanged: no live simulator/device communication, camera/permission/interruption evidence, or installable UI runtime proof. The QA analysis and blocked-case fixtures are deterministic acceptance metadata, not claims that Vision or UX runtime produced those outputs. No contracts, iOS, Vision, or UX files were edited.

## Wave 2 review repairs (2026-10-24)

Independent review identified four QA assertion gaps and they are repaired in `wave2_checks.py`: empty `evidenceRefs` now fail; embedded `sequence` in ScanSession now fails; glare-limited wording is required in the analysis/rationale and tied to low-quality evidence; and no-diagnosis copy requires the explicit exterior-imagery limitation while rejecting unsafe standalone `safe`/`clear` and mechanical-diagnosis language. Sequence remains only in QA metadata.

Exact checks/results after repair:

- `python3 docs/quality/wave2_checks.py ios/replay/replay-scan-session.json` — passed.
- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` — passed.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — passed; 7 schemas loaded.
- Mutation probes for empty evidence, embedded ScanSession sequence, removed glare wording, and unsafe copy — all rejected with nonzero exit status.
- `git diff --check` — passed.

A prior review snapshot became stale because generated iOS `.build` content changed; the source paths under QA and iOS replay remained unchanged. A fresh final snapshot is required for the next independent review.


## Current Wave 2 status (2026-10-24)

- `python3 docs/quality/wave2_checks.py ios/replay/replay-scan-session.json` — passed, including covered/partial/unseen/blocked, low-quality/glare-limited evidence, unknownRegions, evidence refs, escalation, and no-diagnosis copy.
- `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` — passed; sequence remains outside ScanSession JSON.
- `python3 docs/contracts/validate_contracts.py ios/replay/replay-scan-session.json` — passed; 7 schemas loaded.
- `swift test --package-path ios` — current result: 6 tests, 0 failures.
- `swift build --package-path ios` — current result: passed.
- `git diff --check` — passed.

Current blockers remain: simulator support communication failure, no live camera/permission/interruption evidence, and no installable UI runtime proof. QA did not edit contracts or peer scopes.


## Current Wave 2 provenance/joins status (2026-10-24)

The Wave 2 analysis is now a clearly generated QA envelope: it records format, scenario ID, VisionCore producer/source/command, and the exact input ScanSession path. Checks require map sourceSession and scenario ID alignment, finding IDs to match the envelope, evidence refs to resolve to the input session, findings only on covered/partial regions, and recommendation `basedOn` IDs to resolve. Hazard findings derive `safety_review`; partial/unseen/blocked or review-needed inputs derive `more_evidence`. Blocked regions produce no visible findings.

Current validation: Wave 2 and Wave 1 QA checks pass; contract validation passes; Vision tests pass (8), iOS tests pass (6), and iOS build passes. Mutation probes reject unseen-region findings, provenance mismatch, and broken `basedOn` joins. Simulator/device communication and live UI runtime evidence remain blocked.

## Real capture-loop QA acceptance (2026-10-24)

Added QA-owned executable metadata and checks for the capture loop:

- `docs/quality/capture_loop_acceptance.py` validates dynamic next prompts for partial, blocked, and unseen regions; camera versus replay provenance; frame quality gates; explicit covered/partial/unseen/blocked map state; evidence-backed findings only; and replay fallback when camera capture is unavailable.
- `docs/quality/fixtures/capture-loop.json` contains one live-camera case and one camera-unavailable replay case. It references existing replay artifacts and keeps prompt, frame, and 3D-state expectations outside canonical wire schemas.

Checks run:

- `python3 docs/quality/capture_loop_acceptance.py` — passed prompt branches, camera/replay fallback, quality gates, explicit 3D states, and fabricated-evidence rejection.
- `python3 docs/quality/capture_loop_checks.py` — integration harness is owned by the concurrent capture implementation pass; rerun by coordinator after shared edits settle.
- Existing `python3 docs/quality/wave1_checks.py ios/replay/replay-scan-session.json --sequence docs/quality/fixtures/replay-sequence.json` and `python3 docs/quality/wave2_checks.py ios/replay/replay-scan-session.json` remain the complementary contract/replay and analysis checks.
- `git diff --check` — pending final coordinator run after shared-worktree edits settle.

Assumptions: `camera://` URIs represent runtime capture provenance; `ios/replay/...` URIs represent deterministic replay provenance; quality thresholds in the fixture are acceptance-policy inputs, not canonical schema fields; the next prompt selects partial before blocked before unseen when multiple gaps exist; and every map state is explicit rather than defaulting to covered. The fixture is deterministic QA metadata and does not claim production camera, Vision, or UX output.

Open risks: live camera permission/interruption behavior, actual frame metric calculation, and runtime 3D rendering still require device/simulator evidence. The fallback check verifies provenance and state-selection rules but cannot prove an unavailable-camera runtime transition.

## Real capture-loop QA (2026-10-24)

Added QA-owned `capture_loop_checks.py`. It consumes the canonical iOS replay and source-level handoff markers, then runs the producer-owned iOS and Vision XCTest packages. It does not create fake JSON observations or synthetic pixels. Pixel processing remains exercised by VisionCore's in-memory pixel tests.

Checks passed:

- `python3 docs/quality/capture_loop_checks.py` — passed frame ingestion, dynamic next-missing-region guidance, low-quality retake/partial handling, unseen preservation, pixel-evidence provenance/unavailable-evidence behavior, and no-fabricated-finding package tests.
- `python3 docs/quality/wave2_checks.py ios/replay/replay-scan-session.json` — passed replay-to-map/finding/recommendation and uncertainty/safety gates.
- iOS package tests — passed: 6 tests, 0 failures.
- Vision package tests — passed: 8 tests, 0 failures.
- `git diff --check` — passed.

Integration assumptions: iOS `VisionHandoff` remains canonical ScanSession plus typed routing metadata; Vision `FrameAnalyzer` emits evidence availability and missing-region prompts, while findings require evidence refs and are absent when pixel evidence is unavailable. The QA harness verifies those executable behaviors without adding wire fields.

Remaining blockers: simulator/device communication and live camera runtime evidence are unavailable; no UI install/run result is claimed. No contracts, iOS, Vision, or UX files were edited.

## AR scanning reference acceptance (2026-10-25)

Added AR-01 through AR-09 to the QA checklist and an AR reference rehearsal to the demo runbook. The supported-device primary experience must be live full-screen camera with camera-aligned white contours/progressive geometry, dynamic missing-region prompts, guarded Finish, and a polished rotatable surface-anchored vehicle result. The flat map is fallback/debug only. Replay/demo remains an explicit labeled fallback for unsupported devices/simulators.

Required evidence: supported device/OS/build, live camera recording, contour alignment, changing next-region prompt, Finish guard, post-scan rotatable vehicle, surface-anchored finding tap-through, and clearly labeled replay fallback. Current QA blocker remains lack of live simulator/device communication and AR runtime evidence; no AR pass is claimed from package tests or replay JSON.

## C acceptance: AR capture and post-scan (2026-10-25)

Added QA-only executable metadata at `docs/quality/fixtures/ar-capture-acceptance.json` and checker `docs/quality/ar_capture_acceptance.py`. The check covers full-screen live-camera controls (Cancel, Finish, scan/settings, progress), white camera-aligned evidence-only contours, dynamic missing-region prompt, Finish coverage/missing-region guard, explicitly labeled Replay fallback, and camera-to-polished rotatable vehicle transition with surface-anchored evidence and uncertainty. It rejects detached-map contour claims and primitive geometry claims by fixture assertion.

Executable check:

- `python3 docs/quality/ar_capture_acceptance.py` — passed.

Manual/device evidence still required for C acceptance:

1. On a supported device, record a full-screen camera run showing all four controls and a restrained translucent chrome treatment.
2. Move across at least two regions and capture the prompt changing to the currently missing/partial region; verify prompt disappears or changes after coverage.
3. Show white contours/planes tracking camera pixels while moving; verify no contour appears for an evidence-free region and no detached top-down diagram is used as the primary scan surface.
4. With required regions missing or blocked, verify Finish is disabled or explains exact regions and offers a safe next action; after sufficient coverage verify Finish proceeds.
5. On unsupported camera/simulator, verify the surface is visibly labeled `Replay` or `Demo` and never claims live capture.
6. Complete scan and record the transition into a polished rotatable vehicle view; tap a finding to reach surface-anchored evidence, confidence, uncertainty, and next action.

Assumptions: the fixture is acceptance metadata, not a claim that runtime ARKit/RealityKit output exists; white contours must be sourced from captured evidence; and the flat map remains fallback/debug only. Open risks are unchanged until device recording and installable runtime evidence are attached.

## Hardware baseline update (2026-10-25)

Primary QA device is the user's iPhone 15 Plus. The MVP baseline is ordinary RGB camera frames, camera motion/pose signals, IMU/world tracking where available, Vision pixel analysis and quality gating, guided dynamic coverage prompts, and polished 3D vehicle-asset updates. Missing capability signals use the same baseline camera path or the clearly labeled Replay/Demo fallback. The camera-aligned overlay and polished vehicle visual requirements remain unchanged.

The QA acceptance fixture and script validate this camera baseline. Current blocker: no live iPhone 15 Plus/device session is available, so capability/fallback runtime gates remain unexecuted.

## Camera-only scope correction (2026-10-25)

Removed hardware-enhancement language from QA checklist, runbook, fixture, checker, and handoff. QA now documents only the iPhone 15 Plus RGB-camera + camera/IMU/world-tracking baseline, Vision pixel quality/evidence, dynamic prompts, and polished vehicle-asset updates. No optional sensing branch is part of MVP QA.

Current checks:

- `python3 docs/quality/ar_capture_acceptance.py` — passed camera-baseline metadata.
- `swift test --package-path vision` — passed: 17 tests, 0 failures.
- `python3 docs/quality/capture_loop_checks.py` — blocked because the iOS package currently fails to compile in peer-owned tests referencing removed/absent sensing-mode symbols; QA did not edit peer files.
- `git diff --check` — passed.

Integration blocker: the iOS test target has compile errors in `CaptureCoreTests.swift` for stale sensing-mode symbols. These are outside QA ownership and must be repaired by the iOS lead before the real capture-loop integration check can pass. Remaining runtime blocker: no live iPhone 15 Plus session.

## B2 anchored visible finding acceptance (2026-10-25)

Added QA-only fixture `docs/quality/fixtures/b2-anchor-callout.json` and executable checker `docs/quality/b2_anchor_checks.py`. The fixture models one covered canonical-region anchor (`front`) with a resolvable replay frame, while `partial` remains amber and `unseen` remains neutral with no anchor. Assertions require anchor/finding provenance to persist, evidence refs to resolve, no-diagnosis/glare-aware copy, and an explicitly labeled Replay fallback that never claims live capture.

Check: `python3 docs/quality/b2_anchor_checks.py` — passed. This is deterministic metadata acceptance, not runtime proof of camera/world tracking, surface anchoring, or callout rendering. iPhone 15 Plus validation remains blocked pending a live device recording and installable build; the replay artifact is the available fallback evidence.
