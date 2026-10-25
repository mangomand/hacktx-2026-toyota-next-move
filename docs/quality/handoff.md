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
