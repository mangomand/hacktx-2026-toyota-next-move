# Product/UX handoff — contract review

**Status:** Scoped design/research complete; implementation frozen pending coordinator Wave 1 authorization.
**Contract version reviewed:** `docs/contracts` v0.1.0 (2026-10-24).

## Files

- `docs/product-design/inspection-journey.md` — journey, state/copy mapping, camera-around-car prompts, 3D shell progress, issue analysis, accessibility, replay narrative, and contract blockers.
- `docs/product-design/wave-2-post-coverage.md` — shortest map → finding → recommendation → human/scenario action, state copy, acceptance criteria, and iOS handoff.
- `docs/product-design/wave-2-judge-script.md` — 75-second rehearsal path with readout, recovery beats, and acceptance cues.
- `docs/product-design/vehicle-hero-visual-quality.md` — judge-facing 3D/isometric vehicle quality bar, surface-attached findings, uncertainty treatment, controlled rotation, and asset fallback ladder.
- `docs/product-design/real-loop-behavior-review.md` — dynamic region prompts, evidence-to-model behavior, and reviewed iOS/Vision usability/spec mismatches.
- `docs/product-design/ar-scan-behavior-contract.md` — camera-first AR scanning interaction, progressive camera-aligned reconstruction, final-view transition, dynamic copy, acceptance tests, and current implementation mismatches.
- `docs/product-design/handoff.md` — this bounded handoff.

## Checks

- Read `docs/contracts/README.md`, `docs/coordination.md`, and all seven canonical schemas.
- Confirmed all 12 canonical region IDs are represented in the journey.
- Confirmed copy preserves `unknown`, `unseen`, and `blocked` and separates coverage from assessment.
- Confirmed no files outside `docs/product-design/` were edited.
- No implementation, adapter, schema edit, staging, commit, or UI assignment was performed.
- Reviewed the camera slice against the existing canonical region/state vocabulary; no new contract field or enum is required.
- Checked that map decoration is presentation-only, the linear region list remains the accessible source of truth, and synthetic evidence is source-labeled.

## Assumptions

- The visible map may be a presentation of canonical region IDs, with a linear accessible equivalent.
- Synthetic replay provenance will be supplied by the coordinator or a contract-approved fixture source.
- The first slice excludes financial cost ranges and trade-off scoring. Financial recommendations use `review_with_customer` unless an explicit synthetic business rule authorizes another action.
- Coverage notes may carry glare/darkness/occlusion text; no new enum is needed for v0.1.0.
- Evidence is local synthetic paths only, with explicit source labeling.
- Wave 2 remains presentation-only: no new contract fields or enums; `CoverageRegion.notes` supplies low-quality reasons and `unknownRegions` remains visible.

## Risks and blockers

- Usability blocker: first-slice financial copy must not imply affordability, savings, fees, or trade-off scoring; use bounded explanation and a human-review next move.
- Usability blocker: every evidence surface must visibly label local synthetic source paths and preserve unknown/unseen regions.
- No iOS/UI files are assigned. Do not start contract-dependent implementation until the coordinator explicitly authorizes Wave 1 after fresh independent review.
- Wave 2 usability blockers are low-quality recovery, explicit unseen-state presentation, evidence provenance labeling, and restraint around diagnosis/safety claims.
- Visual quality blocker: the flat top-down labeled outline is debug-only; the judge path needs one polished perspective/isometric hero asset with surface-attached finding pins and bounded rotation.
- Real-loop blockers: translate quality enums to current-region prompts, make blocked regions retryable, hide raw confidence decimals, and replace fixed/approximate model markers with evidence-anchored surface callouts before judge-facing acceptance.
- Camera-slice risks are unsafe movement around a vehicle, trunk prompts that imply entering the vehicle, and 3D shell styling that is read as a condition/severity score; the acceptance copy now requires safe skip/block paths, side-positioned trunk capture, and text/pattern labels alongside any color.
- Synthetic fallback must not turn a missing/failed live capture into a captured region or create an issue without a source-labeled artifact.

## Coordinator request

UX is aligned to v0.1.0 and ready to review proposed copy or fixture examples. No schema expansion is requested for this slice.

## Camera-around-car slice handoff

The requested product slice is documented in `inspection-journey.md` under **Camera-around-car guided slice**. It defines the eight-stop exterior/trunk prompt sequence, safe movement language, `covered`/`partial`/`unseen`/`blocked` map states, a lightweight 3D vehicle shell with state-colored scanned surfaces, and the final numbered issue markers anchored to the model. The map is explicitly a coverage aid and has no severity or safety semantics.

The final analysis card is bounded to visible observation, view limitation, source-labeled evidence, unknowns, and one canonical next move with rationale/caveats/`basedOn`. Findings require evidence; unseen and blocked regions stay unpinned and unknown. Camera permission, hardware, safety, and missing-sample failures all converge on retry or **Try sample inspection**, with the **Demo · synthetic images and results** badge and preserved state semantics.

### Handoff checks

- Directional prompts use seated-driver left/right terminology and identify a canonical region at every stop.
- Trunk copy says to stand to the side, never enter the vehicle, and leave the region unknown when unsafe or unavailable.
- Progressive map bands are accompanied by text, marker shape, and optional pattern; Reduce Motion gets a static update and the linear list exposes the same states.
- Final labels and issue list agree on region names/IDs; no issue pin is emitted for missing evidence, `unseen`, or `blocked`.
- Synthetic fallback and missing-asset copy preserve live-vs-demo provenance and return focus to the retry/restart control.

### Assumptions and open questions

- A lightweight 3D vehicle shell can render scanned surfaces as a presentation layer over the canonical region list; unseen surfaces remain gray, state colors are supplemental, and no map geometry or visual severity field is added to v0.1.0.
- The synthetic fixture provider supplies deterministic region states and local artifact paths; the UX layer only labels and presents those artifacts.
- The exact camera permission and vehicle-safety affordances remain an iOS implementation decision within the approved copy/state acceptance.
- The final issue map may contain multiple numbered findings, but each remains independently evidence-backed and bounded to visible analysis.
