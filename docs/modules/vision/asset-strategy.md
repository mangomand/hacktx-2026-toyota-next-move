# Vehicle asset and shader strategy

Revision: `crown-reveal-2.0`, 2026-10-25. Contract baseline v0.1.0. This is presentation metadata, never an additional scan wire schema.

The current source is [Toyota Crown athlete s210 by Black Snow](https://sketchfab.com/3d-models/138a753d04dd4d8f8982d8f5583d212d), CC BY 4.0. Its license was verified through Sketchfab's public metadata. The source distributor, commit, input hash and modifications are recorded in `vision/assets/source/provenance.json`; attribution requirements are in `vision/assets/CREDITS.md`. Original geometry is Black Snow's work. This project authors the materials, geodesic fields, anchors, lighting and reveal/orbit study.

## Concrete artifacts

`vision/assets/nextmove-crown.blend` is the editable scene. `vision/assets/nextmove-crown.glb` contains the vehicle, materials, UVs and eight authored anchors. No studio floor, background, lights or camera is exported. The PNGs and MP4 in `vision/assets/review/` come from the actual Blender scene. `vision/preview/` loads the actual GLB and demonstrates the live shader, orbit/reset and reduced-motion behavior.

The earlier procedural car did not meet the visual requirement and was discarded during this slice. The pre-existing `hero-vehicle-stylized.gltf` remains a historical importer fixture and is not loaded by the viewer.

## Surface reveal

The build computes shortest paths along each permitted mesh's edges, joining coincident UV-seam vertices but never bridging separate meshes. Unreachable and unseen vertices remain forbidden. The extra `InspectionReveal` UV layer carries normalized distance and permission; each mesh's `revealUVChannel` extra identifies its channel. The Blender material feathers a growth front in this field and blends color, metallic response and roughness together. A small local perturbation softens the front without creating a decal or a screen-space blob.

The study's permission masks are authored demonstration inputs for front/left surfaces. Roof, rear, far side, trunk and interior are not assessed. A runtime adapter must replace those demonstration permissions with the intersection of authored exterior surface domains and accepted evidence. The browser has an explicit `partial / uncertain` mode that stays graphite-gray with an amber material tint and does not use the accepted blue paint. Partial evidence remains neutral/uncertain; it must never trigger full paint resolution. No finding is bundled into the geometry.

Blender custom shader graphs do not export as glTF animations. The GLB base body is graphite-neutral. `vision/preview/viewer.js` is a working shader prototype; a native renderer must implement the same field and evidence gate. Do not ship a static blue material as an inspection state. Asset beauty mode is only for model inspection and explicitly states that no assessment is made.

## Anchors

`reveal-surfaces.json` records exact asset-relative positions and region IDs for panel, tire, windshield and light anchors, plus `meshId`, primitive/triangle indices, triangle vertex indices, barycentric weights and a surface normal. Coordinates differ from the old normalized `VehicleSurfaceAnchor.heroDefaults()`: use this asset's revision-specific remap. Blender axes are +X vehicle left, -Y front, +Z up; glTF axes are +X vehicle left, +Y up, +Z front. A native integration must account for this orientation explicitly and reject the callout if the referenced triangle is missing or occluded.

`FindingCallout` joins an existing evidence-backed finding, matching region and a non-empty surface attachment. Geometry, an anchor, or a camera pose never creates coverage or a finding. The attachment carries the asset revision alongside the stable triangle/barycentric/normal seam; the callout initializer requires the caller's expected revision to match before presentation. The client must still resolve the triangle against the current mesh and hide it when occluded. A stale mesh/triangle, revision mismatch, or failed occlusion test cannot produce a floating callout.

## Tool choice

See `research-vehicle-workflows.md` for first-party Audi, Epic, Unity/Lexus, Tesla, Apple, Google and Blender sources. The chosen pipeline is Blender 4.5.3 + attributed glTF + a surface-field shader. Desktop configurators inform material/camera quality; they are not runtime dependencies of the iPhone app. Blender MCP 2.2.4 is running in an isolated localhost authoring session with telemetry disabled. `vision/tools/blender-mcp.json` is a client configuration fragment; no global T3/Codex configuration was changed.

## Remaining acceptance

The editable scene, exports, rendered animation and browser prototype are reviewable. Native import/conversion, live evidence-to-permission mapping, uncertainty tint, occlusion-aware findings, camera alignment and iPhone 15 Plus performance remain integration/device checks. This slice does not modify iOS or claim those checks passed. Replacing the source with the exact customer vehicle requires a new attributed asset revision and anchor remap. The geometry never asserts hidden mechanical condition.
