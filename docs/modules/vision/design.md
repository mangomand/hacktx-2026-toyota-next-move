# Vision module design handoff

Status: design-only, contract-aligned with canonical contracts v0.1.0 (2026-10-24).

## Scope

## MVP priority

The first implementation slice is deliberately narrow: deterministic replay frames must reconstruct the progressive 2.5D map and emit visible findings with evidence, confidence, and explicit unknown states. Advanced Vision/Core ML, server reconstruction, provenance hardening, and security work are deferred until replay-to-map and finding output are demonstrable and validated. Wave 2 resolves both seams: Vision owns factual visible follow-up text in `recommendedCheck`; UX owns presentation and recommendation copy. Vision derives `unknownRegions` from non-covered map regions. No output may imply hidden mechanical diagnosis.

The Vision lead owns deterministic synthetic replay fixtures, an uncertainty-aware visual vehicle map, visible finding generation, confidence handling, and pass/fail/unsure rule evaluation. This document intentionally defines module behavior and seams without creating a second wire schema. The coordinator owns the canonical JSON contracts and integration adapters.

## Contract alignment

- `ScanSession.regions` is the source of truth for coverage. Vision preserves all twelve canonical `regionId` values, including `roof`, `interior-front`, `interior-rear`, and `trunk`.
- `CoverageRegion.state` remains explicit: `unseen`, `partial`, `covered`, or `blocked`. A region is `covered` only after the capture quality gate; missing evidence never becomes a pass. Capture owns the gate; Vision does not upgrade coverage.
- `CoverageRegion.quality` remains `unknown`, `low`, `acceptable`, or `high`. Quality is separate from visible findings and does not imply mechanical condition.
- Wave 2 integration invariant: `ScanSession.unknownRegions` is derived from every mapped region whose state is `unseen`, `partial`, or `blocked`; only quality-gated `covered` regions are excluded. Vision preserves the distinction between unknown and clear.
- Findings emit only canonical fields: required `id`, `category`, `severity`, `confidence`, `status`, `regionId`, and `evidenceRefs`, plus optional `description` and `recommendedCheck`. Descriptions state visible observations and never hidden mechanical diagnoses.
- Every finding keeps at least one evidence reference that joins to a replay artifact or capture artifact. Multi-frame evidence is allowed through multiple `evidenceRefs`.
- Synthetic replay remains explicit through `ScanSession.status = replay`, `mode = synthetic_replay`, and synthetic artifact references. Replay output must be deterministic for a fixed fixture version and seed.

## Internal behavior seam

The future module may use internal Swift types for frames, projections, detector outputs, and rules, but the integration boundary should consume and emit canonical contract values only. A future Vision/Core ML or server reconstruction backend should implement the same internal detector/reconstruction seam as the synthetic backend. The seam must preserve:

1. frame/artifact identity;
2. region identity and coverage state;
3. observation confidence and uncertainty reasons;
4. evidence references; and
5. detector/rule version metadata where the integration contract permits it.

No backend may infer unseen or occluded areas from the absence of a detection. `blocked`, `unseen`, and low-quality observations remain reviewable unknown states.

## Proposed synthetic demo scenarios

These are fixture names and behavior targets, not wire-schema additions:

- `clean-replay`: all twelve canonical regions have acceptable/high quality where required by the scenario and no visible findings.
- `cracked-windshield`: high-confidence visible damage in `front`, with evidence and `not_a_diagnosis` status.
- `visible-tire-wear`: synthetic visible tire wear produces a wear finding; exterior imagery does not establish tread depth, pressure, or roadworthiness.
- `partial-side-view`: a side region remains `partial` or `blocked`; output requests more views rather than passing the vehicle.
- `dashboard-warning`: an observed warning indicator is emitted as `warning_indicator`; no mechanical cause is asserted.
- `unknown-area`: an unseen or occluded region is included in `unknownRegions` and does not produce a clean finding.
- `img-1404-quality-only`: external fixture `IMG_1404.mov` (~30 seconds, 1920x1080) is a close side/rear pass under strong blue lighting with motion blur. Treat supported side/rear evidence as partial or glare-limited quality only; emit no finding from this fixture. It provides no interior, front, roof, or trunk coverage, so those regions remain `unseen`/unknown.

## Judge-facing visual quality bar

The current `VisualMap` region coverage output is a debug/data representation only. It must not be presented as the finished 2.5D vehicle experience. The judge-facing MVP should use one recognizable Toyota-like vehicle asset in perspective/isometric view with believable body volumes, windows, wheels, lights, seams, materials, lighting, depth, and controlled rotation. Prefer a RealityKit/USDZ or glTF asset; a polished stylized asset or turntable fallback is acceptable when it preserves surface readability.

Findings must attach to actual model surfaces through stable surface anchors (panel, tire, windshield, or light), rendered as pins, highlights, or callouts. Observed surfaces can resolve with evidence-backed color/state; unseen surfaces remain neutral grey; low-confidence or quality-limited surfaces remain amber. The twelve canonical `regionId` values remain metadata behind the asset and are never rendered as twelve flat pills or a top-down labeled outline. The first hero scenario should show one coherent side/rear walkaround with one visible observation and its evidence/callout, while explicitly showing an unseen neutral side.

The internal seam should separate asset geometry/surface anchors from canonical coverage and finding payloads. A turntable is a presentation fallback, not a claim of full reconstruction: controlled rotation must never reveal unobserved surfaces as known.

## Simplified geometry and progressive reconstruction

Use an explicitly illustrative 2.5D template, not a measured reconstruction: a normalized cuboid body and cabin with wheel markers. Proposed vehicle-local axes are x right, y up, z forward; dimensions and patch placement are synthetic display choices, never measurements. Anchor the twelve canonical regions to template patches; interior and trunk patches are separate inset surfaces. Overlapping camera sectors do not imply observation of hidden surfaces. Render unobserved patches as unknown; a usable region view only maps its supported patch and never fills its entire hidden volume. Patch geometry and observation provenance remain internal; the Wave 2 public output is the canonical region coverage plus visible findings.

## Detector and rule plan

Synthetic annotations will independently cover panels (visible mark), tires (visible wear only), windshield (visible crack), lights (visible lens condition only), odometer (readable synthetic digits), and dashboard warnings (visible icon only). An exterior light image cannot establish electrical operation; a warning icon cannot establish its cause; unreadable odometer digits must remain unknown. Odometer observations must not overwrite customer/synthetic profile mileage without an explicit integration decision.

Internal rules return pass/fail/unsure per specific visible check, with evidence and confidence. These are not canonical Finding.status values and must not be exported as extra wire fields. A pass means only that the stated visible check has adequate evidence; a fail means the synthetic visible criterion is present, never that the vehicle is unsafe. Missing/low-quality evidence or contradictory observations yields unsure. No aggregate safety pass is permitted. Thresholds, duplicate handling, and conflicts must be explicit and unit tested after release. No financial or next-move recommendations belong to this module.

The preliminary child proposals were research only. Their eight-sector model, coverage-on-frame-existence rule, tire depth inference, and safety/replacement guidance are rejected because they conflict with canonical quality gating, twelve region IDs, or non-diagnostic scope. One initial child response was lost to HTTP 503; its subsequent delivered result was read and reviewed. Neither child edited files.

## Validation targets after Wave 1 release

- Contract fixtures validate against all seven canonical schemas.
- Region IDs are exact and case-sensitive.
- Replay is deterministic across repeated runs.
- Findings preserve evidence joins, confidence bounds, and explicit unknown states.
- Boundary tests cover quality gating, confidence thresholds, duplicate observations, and mixed covered/unseen sessions.
