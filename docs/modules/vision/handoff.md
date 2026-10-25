# Vision lead handoff

Date: 2026-10-24
Contract baseline: canonical contracts v0.1.0
Status: Wave 2 MVP implemented; replay-to-map, deterministic map presentation, and visible finding output are ready for coordinator integration review.

## Visual quality bar

The existing flat top-down labeled outline is debug-only coverage data, not the judge-facing vehicle experience. Wave 2 integration should prioritize one polished hero scenario using a perspective/isometric Toyota-like asset (USDZ/glTF/RealityKit when available, otherwise a polished stylized or turntable fallback). Findings need surface-anchored pins/highlights/callouts on panels, tires, windshields, or lights; observed areas resolve, unseen areas stay grey/neutral, and low-confidence areas stay amber. Canonical 12-region IDs remain metadata behind the model.

## MVP priority

Prioritize replay-to-map and visible finding output: deterministic synthetic frames, progressive 2.5D reconstruction, evidence references, confidence, and explicit unknown/unseen states. Defer advanced model/security work. Vision resolves the two prior seams: it owns factual `recommendedCheck` text, and derives `unknownRegions` from every non-covered region. UX owns presentation/recommendation copy. Never infer hidden mechanical diagnosis from exterior imagery.

## Files

- `docs/modules/vision/design.md` — bounded design and contract alignment.
- `IMG_1404.mov` — external quality/coverage fixture only; not added or modified in this repository.
- `vision/Package.swift` — standalone VisionCore package.
- `vision/Sources/VisionCore/VisionCore.swift` — replay, progressive map, quality gating, deterministic map presentation, bounded analysis, and visible finding output.
- `vision/Tests/VisionCoreTests/VisionCoreTests.swift` — MVP behavior plus map color/state, finding attachment, and analysis-bound tests.
- No canonical contract files, coordinator files, iOS files, or QA files were modified.

## Checks

- Read `docs/contracts/README.md`, `docs/contracts/CONVENTIONS.md`, `docs/contracts/registry.json`, all seven `docs/contracts/*.schema.json` files, and `docs/coordination.md`.
- Confirmed all twelve canonical region IDs are represented in the vision design.
- Confirmed working tree contains peer-owned untracked `ios/` and `docs/quality/` content; it was preserved and not staged.
- Ran `swift test` in `vision/`; 8 tests passed, including invariant-preserving decoding, duplicate-ID rejection, quality gating, synthetic visible findings, map state/color semantics, region-attached findings, deterministic bounded analysis, and expanded diagnostic-claim sanitization.
- Updated visual-quality guidance only; no 3D/media asset was added. The flat map remains debug-only by explicit handoff policy.
- Ran `python3 docs/contracts/validate_contracts.py`; registry and schema checks passed after the presentation-only addition.

## Assumptions

- `artifactRefs`, finding `evidenceRefs`, and scenario-level `fixtureRefs` use opaque repo-relative POSIX paths per `CONVENTIONS.md`; missing references remain unavailable artifacts, never false findings.
- Vision may use private internal types after authorization, but adapters must emit only canonical v0.1.0 fields.
- For `state: unseen`, `observedAt` equals the containing session `startedAt` and `artifactRefs` is omitted; this records evaluation time, not observation. The 12-region denominator and `partial`/`covered` quality-gate semantics follow `CONVENTIONS.md`.
- `MapPresentation` is an internal presentation model: its state-shaped color token, `isUnknown`, accessibility text, region-attached findings, and bounded `analysis` are derived from canonical map/findings values and are not wire-contract fields. Analysis is capped at 240 characters and contains no safety or mechanical conclusion.
- `IMG_1404.mov` is a side/rear quality fixture (~30s, 1920x1080) with strong blue lighting and motion blur. It may support partial/glare-limited coverage only; it must not generate a finding. Interior, front, roof, and trunk remain unseen.

## Remaining risks / coordinator review

- The Swift package emits canonical-shaped values but does not yet serialize a full `ScanSession` envelope; coordinator integration should own that adapter.
- No production 3D asset is included in this Vision slice. The current flat coverage map must not be shipped as the judge-facing 2.5D experience; asset selection/RealityKit or glTF wiring remains an integration dependency.
- The hero scenario should be completed and visually reviewed before expanding to all region permutations.
- Pass/fail/unsure rule details remain module-private and must not become additional wire fields.
- `IMG_1404.mov` remains external fixture metadata only; no media is stored in the repository.
- Coverage quality is deliberately conservative: low/glare-limited or motion-blurred evidence is partial and never a finding.
- Presentation clients must map `MapRegionColor` tokens to an accessible palette and retain the linear region text; the model intentionally does not prescribe visual RGB values or a measured 3D geometry.

## Replay merge semantics

Synthetic replay reduces frames in sorted frame-ID order. For each region it retains the highest observed quality and all artifact references. A later clear `acceptable`/`high` frame upgrades an earlier unflagged `low`/`unknown` partial observation to `covered`. Any glare-limited or motion-blurred frame sets a sticky limitation for that region, so the merged result remains `partial` (with the quality-limited note) even when a later clear frame is present. This makes low-to-high recovery useful while ensuring flagged evidence cannot be silently cleared by ordering.
