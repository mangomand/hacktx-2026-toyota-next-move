# Vision / 3D handoff

Updated: 2026-10-25. Canonical contracts: v0.1.0. Current slice: detailed vehicle asset and observation-driven material-reveal prototype. Files edited only under `vision/` and `docs/modules/vision/`; no iOS, QA, canonical schema, customer media, staging or commits.

## Current outcome

The actual model is `vision/assets/nextmove-crown.glb`, with editable `nextmove-crown.blend`. It uses detailed **Toyota Crown athlete s210 geometry by Black Snow, CC BY 4.0**. Original geometry is attributed; this project authors its materials, geodesic fields, anchors, studio lighting and reveal/orbit study. The rejected toy-like procedural model is discarded. The older pre-existing primitive GLTF is historical importer coverage and is not loaded by the new viewer.

The GLB has vehicle meshes/materials/UVs and eight authored anchors, with no floor, background, lights or camera. `review/vehicle-beauty.png` shows the authored material without an inspection assessment. Neutral, intermediate and observed-state renders plus `review/material-reveal.mp4` demonstrate actual Blender material emergence. `vision/preview/` is a working interactive GLB/shader viewer with orbit, reset and reduced-motion behavior.

The blue rectangle visible in the user's app screenshot is hard-coded in the iOS SceneKit background. It is not baked into the vehicle asset. That peer-owned UI was inspected read-only and left unchanged, as was the debug notification panel.

## Files in this slice

- `vision/tools/build_vehicle.py` — offline Blender authoring, render and GLB export.
- `vision/tools/surface_field.py` — bounded permitted-surface mesh-edge shortest paths.
- `vision/tools/start_blender_bridge.py`, `blender-mcp.json` — isolated localhost bridge startup and pinned client configuration fragment.
- `vision/Tests/test_surface_field.py` — curved-surface distance, unseen/disconnected behavior, UV-seam welding and invalid geometry checks.
- `vision/assets/source/crown-ccby.glb`, `source/provenance.json`, `CREDITS.md` — attributed source, pinned distributor revision/hash and modifications.
- `vision/assets/nextmove-crown.blend`, `nextmove-crown.glb`, `reveal-surfaces.json` — source, runtime import candidate and presentation-only field/anchor metadata.
- `vision/assets/review/` — actual model renders and animated reveal/orbit study.
- `vision/assets/README.md`, `.gitignore` — build, shader and attribution handoff; generated Blender backups excluded.
- `vision/preview/` — pinned Three.js dependency, viewer and actual geometry-aware shader.
- `docs/modules/vision/design.md`, `asset-strategy.md`, `research-vehicle-workflows.md`, `handoff.md` — design, primary-source research and acceptance limits.

## Evidence and contract seams

Canonical schema refs, artifact/evidence joins and unseen timestamps are resolved by `docs/contracts/CONVENTIONS.md` and `registry.json`. No schema change is needed by this slice. `unknownRegions` remains every unseen/partial/blocked region. Unseen `observedAt` uses session start by canonical convention, not a claim of observation.

Vision owns factual visible-follow-up text in `recommendedCheck`; presentation/financial recommendations stay outside this module. Findings require evidence and matching region/anchor joins. No geometry, pose, frame existence or animation may create a finding, coverage or mechanical/safety diagnosis. `IMG_1404.mov` remains external side/rear partial/glare/motion quality metadata only, with no finding and no copied media.

The reveal field stores `(mesh-edge distance / 2.8 metres, permission)` in an extra UV channel identified by node extras. The soft growth front blends deep-blue paint, roughness and metallic response within the mesh material. Forbidden/disconnected vertices stay graphite-neutral. The prototype permission mask is an explicitly authored front/left demonstration, not live evidence. Partial/uncertain observations remain graphite-neutral with an amber treatment; the browser study has a separate uncertain mode that never uses accepted blue. `MaterialReveal.swift` retains the canonical state policy and separate finding accent.

Anchor coordinates are specific to `crown-reveal-2.0`; do not reuse the old normalized `heroDefaults()`. `reveal-surfaces.json` now records mesh ID, primitive/triangle indices, triangle vertices, barycentric weights and surface normal for each anchor. `VehicleSurfaceAnchor.SurfaceAttachment` validates the same bounded data plus its asset revision, and `FindingCallout` requires the caller's expected revision to match before presentation. The native client must reproject and occlusion-test the triangle against the matching asset revision before showing a callout. Exact Blender/glTF axes are documented in `reveal-surfaces.json`. The model has no diagnosis or finding baked into it.

## Executed checks

- Blender 4.5.3 via MCP 2.2.4: actual authoring, export, four populated PNG renders and four-second MP4 animation completed. The authoring camera now commits its depsgraph rotation before parenting, preventing blank review renders.
- Browser prototype loaded the GLB and initialized 16 body-surface reveal materials; direct page evaluation reported ready with no load error. Browser screenshot capture timed out; Blender renders were visually inspected directly.
- Python surface-field tests: 5 passed.
- `node --check vision/preview/viewer.js`: passed; pinned dependency installation reported zero vulnerabilities.
- Browser shader state has separate beauty, partial/uncertain amber, and accepted reveal modes; partial mode never blends to accepted blue.
- `swift test` in `vision/`: 25 passed, preserving quality gates, uncertainty, evidence joins, sanitization, material states and revisioned anchor validation (including stale-revision rejection).
- `python3 -m unittest discover -s vision/Tests -p 'test_*.py'`: 7 passed, including bounded reveal-anchor and GLB metadata checks. The build's closest-point routine now emits exported-glTF triangle/barycentric attachments in the triangle domain.
- Asset structural check: GLB header/chunks valid; eight anchor nodes carry `crown-reveal-2.0`; no review-only floor/camera/light nodes are exported.
- Fresh independent verification after glTF remap: no actionable findings; all eight triangle/barycentric anchors reproject within approximately 1e-6 m, and viewer beauty/uncertain/accepted semantics were checked.
- `python3 docs/contracts/validate_contracts.py`: all 7 schemas passed.
- `git diff --check`: passed.
- Structural GLB and source round-trip validation plus independent review are recorded in the external task report; completion is not implied by this historical check list.

## Assumptions and remaining limits

The detailed Crown is a presentation template, not the exact vehicle in the user's camera and not a measured reconstruction. A beauty render exposes original paint only to inspect the asset; it must never be interpreted as observed coverage. Visible attribution must accompany public model use.

Custom Blender material graphs do not travel as glTF animation. The GLB exports neutral PBR body materials and reveal fields; `preview/viewer.js` demonstrates the runtime shader. Native conversion/import, live evidence permissions, amber uncertainty response, surface-normal/barycentric finding attachment and occlusion, camera alignment and iPhone 15 Plus performance remain unverified. This slice does not replace the model/background inside peer-owned iOS files. No cloud rendering or external generation service is required.

Blender MCP is active only in the isolated authoring session, bound to localhost with telemetry disabled. The checked-in JSON is a configuration fragment, not a claim that T3's global tool catalog was modified. Hardware baseline remains ordinary RGB frames and camera/motion/world pose. No unsupported hidden condition is inferred.
