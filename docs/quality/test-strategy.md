# Quality test strategy — contracts v0.1.0

Status: design/research only. Contract-dependent implementation is frozen until explicit coordinator Wave 1 authorization. Canonical sources: `docs/contracts/README.md`, all seven schemas, and `docs/coordination.md`. QA owns only `docs/quality/`; proposed assertions below do not extend wire shapes.

## Schema checks after authorization

Use JSON Schema draft 2020-12 with format checking enabled and a local, coordinator-approved reference registry. Confirm resolution for DemoScenario references to ScanSession, VehicleProfile, Agreement, Recommendation and ScanSession references to CoverageRegion. Do not rely on network fetches or invent alternate schemas. These are planned checks, not an implemented validator.

Validate each of the seven object types, required fields, enums, numeric limits, and `additionalProperties: false`. Negative mutations should remove a required field, add an unsupported property, use an invalid state, use confidence outside [0,1], and supply malformed date/date-time values. Distinguish schema rejection from semantic failures that require application assertions.

## Semantic assertions beyond JSON Schema

- Use all 12 CoverageRegion IDs: `front`, `front-left`, `left`, `rear-left`, `rear`, `rear-right`, `right`, `front-right`, `roof`, `interior-front`, `interior-rear`, `trunk`. Reject duplicate entries. Missing entries remain unseen/unknown; never infer clean results. Display exterior and interior separately.
- CoverageRegion states are `unseen`, `partial`, `covered`, `blocked`; quality is `unknown`, `low`, `acceptable`, `high`. Only a passed capture-quality gate permits covered. Covered requires resolvable capture evidence; `observedAt` on an unseen record cannot prove inspection. Exact quality threshold and coverage denominator need coordinator approval.
- Finding.regionId must resolve to a canonical region. For observed visible findings, evidenceRefs must resolve to actual session artifacts; empty/broken refs are not evidence. `unseen`/`missing_context` findings may describe missing context, never an observed defect. Confidence is an uncertainty signal, not a guarantee of calibration or safety.
- ScanSession.findingIds and Recommendation.basedOn references must resolve to the same scenario’s data. Cross-scenario and stale asynchronous responses cannot overwrite the current session. No session/vehicle join fields are invented; v0.1.0 groups scan/profile/agreement in DemoScenario.
- Display VehicleProfile.dataSource and Agreement.dataSource accurately (`synthetic`, `customer_provided`, `unknown`). There is no customer contract in v0.1.0; report customer context unavailable until coordinator direction.
- Render exactly one Recommendation.nextMove, rationale, confidence limits, and caveats. Do not interpret `continue_current_plan` or `no_action_yet` as safety clearance. Safety cues override commercial suggestions in presentation and require human escalation; threshold policy is a coordinator decision.

## Contract-derived deterministic scenarios (planned)

| Case | Fixture/input and expected assertion | Trace |
|---|---|---|
| Q-01 | Valid synthetic DemoScenario validates every nested type, expectedNextMove, dataSource labels, and artifact references. | VS-01/06/07/11 |
| Q-02 | Two observed exterior regions; remaining regions unseen. No new observed defects in unseen regions, no inspected/clear label, exterior denominator approved separately from interior. | VS-02/03/05 |
| Q-03 | Blurred/glare/occluded region is partial/blocked or otherwise fails quality; no transition to covered without approved gate. | VS-03/04 |
| Q-04 | Repeated frames cannot increase unique region coverage; interrupted/stale capture cannot advance coverage. Reordering does not change the semantic result. | VS-03/09 |
| Q-05 | Unknown/missing agreement context, non-resolving refs, mismatched scenario outputs, invalid region IDs: explicit unknown/error and no unsupported recommendation. | VS-06/07 |
| Q-06 | High-severity visible concern, conflicting evidence, and low confidence: safety copy and appropriate escalation; no causal mechanical claim or sales override. | VS-05/07 |
| Q-07 | Unknown enum, confidence bounds, required-field deletion, extra property, invalid date-time: schema-specific rejection with useful error path. | VS-04/06 |
| Q-08 | Restart same versioned replay in two fresh processes: equivalent coverage, findings, uncertainty, and nextMove. | VS-11 |

Pin scenario ID/version, artifact bytes/hashes, build/model versions, random seed if used, injected clock, locale/timezone, and network responses. Canonical comparison must specify object key ordering, list ordering where order is immaterial, timestamp handling, and float precision. Do not strip meaningful uncertainty/evidence differences to make tests pass. v0.1.0 has no seed field; record test controls in external evidence, not extra wire fields. Different seeds need not change outputs; use a separately specified changed-input scenario with a documented expected difference. Fixture replay must not invoke a changing remote model.

## Accessibility assertions

VS-10 uses the detailed gates in `acceptance-checklist.md`: complete core flow with VoiceOver; names/roles/states and location/uncertainty text; Dynamic Type through accessibility XXXL; reachable 44 x 44 point targets; 4.5:1 normal text and 3:1 large text/meaningful graphics in light/dark modes; no color-only meaning; Reduce Motion; reachable error recovery. Run assistive-technology checks on device/simulator; static inspection alone does not count as passing.

## Responsible-AI and copy review

Use region-specific visual observations and plain-language uncertainty; do not imply hidden mechanical diagnosis, roadworthiness, Toyota certification, guaranteed repair cost, or finance eligibility. Require an exterior-imagery limitation and explicit unknown/unseen regions. Capture only while parked safely; skip inaccessible views rather than entering traffic. For reported or visible immediate hazards, advise stopping use when safe and contacting appropriate roadside/emergency help. Never request users reproduce a hazardous condition. Synthetic context must not pressure a customer into a purchase. Retain only necessary non-personal test evidence; avoid raw customer identifiers in logs.

## Current schema-dependent questions for coordinator

1. Approve local reference-resolution registry/convention and format-validation mode.
2. Define passed quality gate, exterior denominator (including roof/trunk handling), and uncertainty/escalation thresholds. QA will not guess these policies.
3. Confirm reference namespaces for evidenceRefs/basedOn and missing-context behavior; schemas alone do not enforce referential integrity.
4. Confirm customer context is intentionally unavailable in v0.1.0 or schedule a coordinator-owned contract revision.
