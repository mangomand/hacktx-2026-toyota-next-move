# Vision module design handoff

Status: VisionCore implemented; asset/shader prototype authored against canonical contracts v0.1.0 (2026-10-25).

## Scope

The capture adapter accepts real RGBA pixel inputs and computes deterministic blur,
exposure clipping, and frame-to-frame motion metrics. Native `CGImage` and
`CVPixelBuffer` initializers are compiled when their Apple frameworks are available;
the portable pixel value keeps Linux tests reproducible. Region membership is an
explicit caller input. The adapter never infers a region or a vehicle condition from
an image merely being present. Its result exposes evidence availability, missing
regions, and a prompt suitable for iOS follow-up capture.

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

`vision/assets/nextmove-crown.glb` is the current detailed vehicle asset, based on Toyota Crown athlete s210 by Black Snow (CC BY 4.0). The editable Blender source, actual renders and animated material study accompany it. Separate panels, glass, tires, wheels, lamps, trim and authored anchors preserve the car's recognizability. The source geometry is attributed; this project authors its inspection materials and reveal fields. The current centered notification/debug panel is outside this module. See `asset-strategy.md` for exact artifacts and native integration limits.

## AR scan interaction contract

During capture, camera-aligned contours and prompts remain the primary experience. After evidence is accepted, the client may transition to the GLB hero view. Canonical region IDs remain metadata behind the asset; they are not rendered as a flat twelve-pill map. A finding pin or highlight may attach only to a matching `VehicleSurfaceAnchor` with evidence. An anchor never creates coverage.

## Observation-driven material reveal prototype

The renderer should reveal the approved vehicle asset from its actual mesh inward/outward along authored UVs, normals, and surface masks. `MaterialReveal` is the prototype handoff: `neutral` for unseen/blocked, `uncertain` for partial quality, and `revealed` for quality-gated coverage. Progress and spread radius are bounded animation inputs, not screen-space colors. The renderer should use a mesh-local mask or signed-distance/UV field with eased temporal growth, preserving panel seams, curvature, windows, tires, and lights. It must never use flat region fills, stickers, flood fills, or painted blobs.

Finding accents are separate from material emergence: pins, thin outlines, or restrained callouts use `FindingCalloutState` and never recolor an entire surface. Asset requirements are a clean named mesh hierarchy, stable UVs, body/window/tire/light material groups, authored anchor IDs, and a revisioned USDZ/glTF export. A RealityKit material modifier or Metal shader is the preferred implementation; Blender is useful for topology/material validation and turntable review, not as a runtime dependency. The first hero review should show one rear-left walkaround with neutral unseen surfaces, amber partial surfaces, a soft reveal spreading over one observed panel, and one restrained finding accent.

The renderer's shader seam is mesh-local: sample an authored UV/vertex mask, apply an eased growth radius around the evidence anchor, and blend neutral gray into the asset's authored material. Partial evidence uses an amber tint at low opacity; covered evidence reveals the authored material. The animation is bounded and reversible, and finding accents are a second pass. No screen-space flood fill, sticker, or full-region recolor is permitted.

## Camera-only baseline

The primary hardware path is the user's iPhone 15 Plus: ordinary RGB camera frames plus camera motion/pose and optional IMU/world-tracking signals where available. Vision consumes decoded pixels for quality and semantic evidence. The adapter selects `cameraGuided` when camera and world tracking are available, or labeled `replayDemo` when baseline capture is unavailable. Missing sensing capability never creates coverage; unknown states remain explicit.

## Asset geometry and progressive evidence

The old cuboid/flat region map is a debug representation and is superseded for vehicle presentation. The detailed Crown asset is an authored template, not a measured reconstruction or evidence that hidden surfaces were seen. Canonical region coverage controls visibility/uncertainty only through explicitly authored surface domains. Each reveal field follows mesh-edge shortest paths and has a permission channel; unknown vertices remain neutral at every animation radius. The illustrative front/left reveal study does not consume customer evidence. Runtime integration must provide accepted evidence permissions and revision-specific anchors before applying the shader to live scan output.

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
