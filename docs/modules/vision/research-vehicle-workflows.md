# Vehicle presentation and scan workflow research

Research date: 2026-10-25. Primary-source review for the owned Vision/3D slice. These references guide interaction and asset production; they do not establish vehicle inspection accuracy. No external application workflow was copied wholesale.

## Visual direction

The vehicle should read as a real manufactured object before any scan effect is applied. Use accurate silhouettes, wheel openings, glazing, panel gaps, lamp internals, rubber versus metal separation, and long softbox reflections. The car occupies the frame, with a quiet transparent or neutral environment. The inspection effect changes the material response inside the mesh. It does not cover it with colored polygons. Findings remain a sparse second layer, anchored to a specific surface.

The first procedural build did not meet this bar. It is rejected. The current study uses a detailed, attributed Toyota Crown mesh rather than another primitive-car approximation. This is an authored presentation asset, not a reconstruction of the user's vehicle.

## What existing products and platforms establish

| Reference | Verified behavior or production technique | Decision for Next Move |
| --- | --- | --- |
| [Audi Business Innovation AVP online products](https://www.audibusinessinnovation.com/portfolio/avp/online-products/) | Audi describes high-quality real-time web configuration, multiple perspectives, interior panoramas and turntables. | Keep a coherent hero camera and model across angle changes. Treat asset fidelity, camera composition and material response as one pipeline. |
| [Epic Automotive Configurator sample](https://dev.epicgames.com/documentation/en-us/unreal-engine/automotive-configurator-sample?application_version=4.27) | The Audi A5 sample separates variants, movable part pivots, materials, lighting and cinematic sequences. | Preserve named surfaces and anchors; do not flatten the car into one mesh/material. Author review shots separately from runtime geometry. The desktop renderer is a reference, not an iPhone dependency. |
| [Epic configurator template article](https://www.unrealengine.com/blog/automotive-configurator-template-available-now) | The template supports paint, wheels, trim, seats and interior variants with dedicated automotive materials and sequenced presentation. | Use a physically based paint with clearcoat and a restrained orbit. Keep material variants independent of findings and evidence state. |
| [Unity Lexus virtual-production case study](https://unity.com/blog/lexus-opens-the-door-for-virtual-production-in-unity) | Lexus/Team One describe reusing real-time vehicle content across virtual production and configuration. | Keep one editable source asset and derive runtime geometry and review renders from it, rather than maintaining a screenshot-only design. |
| [Tesla Model 3 Car Status](https://www.tesla.com/ownersmanual/model3/en_us/GUID-80B80D48-E3A9-4857-864B-F4CC9B56FD7E.html) | The vehicle visualization provides spatially related status/controls; it adapts framing as relevant information changes. | Use the car as the spatial index. Focus a selected part with a controlled camera move. This is design inspiration only; Tesla telemetry does not establish exterior-inspection evidence. |
| [Apple RoomPlan overview](https://developer.apple.com/augmented-reality/roomplan/) | The reference presents live coaching, progressive clean geometry and a reviewable result. | Borrow the visual sequence of guided capture → progressive confirmation → review. The room-scanning API and room semantics are outside this MVP. |
| [Apple ARSession](https://developer.apple.com/documentation/arkit/arsession) and [world tracking](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration) | ARKit manages camera passthrough and pose tracking relative to the environment. | RGB camera + motion/world pose is the baseline. A tracked pose positions an overlay; it does not prove a panel was seen or produce damage findings. |
| [Apple ObjectCaptureView](https://developer.apple.com/documentation/realitykit/objectcaptureview) | The view guides image capture for object photogrammetry. | Borrow concise movement and angle guidance. Do not introduce this API as a dependency of the camera baseline or claim continuous car reconstruction. |
| [Google model-viewer annotations](https://modelviewer.dev/examples/annotations.html) | Position/normal hotspots attach to model points; surface hotspots can follow mesh animation. | Store an exact mesh-space anchor and normal/barycentric reference for each finding. Hide back-facing/occluded callouts rather than allowing floating labels through the car. |
| [Google model-viewer docs](https://modelviewer.dev/docs/) | Camera orbit/target, exposure, environment and material controls are independent viewer concerns. | Offer deliberate orbit/reset in the asset review; keep camera and lighting out of the runtime model. An accessible text list is a secondary representation. |
| [Blender glTF exporter manual](https://docs.blender.org/manual/en/4.5/addons/import_export/scene_gltf2.html) | glTF exports standard PBR materials, UVs, meshes and extras; arbitrary Blender shader graphs are not portable. | Export a neutral PBR GLB with reveal fields and anchors. Deliver the animated Blender source and a working shader prototype separately. Never claim a node animation is present in GLB. |
| [Blender MCP source](https://github.com/ahujasid/blender-mcp) | The bridge exposes scene inspection and Python execution in a live Blender session. | Use an isolated localhost authoring session and the pinned server package. The bridge is a tool, not a runtime product dependency. |

## Asset selection and provenance

The chosen source is [Toyota Crown athlete s210 by Black Snow](https://sketchfab.com/3d-models/138a753d04dd4d8f8982d8f5583d212d), whose [public metadata](https://api.sketchfab.com/v3/models/138a753d04dd4d8f8982d8f5583d212d) reports CC Attribution and permits download. The copy comes from [carros](https://github.com/pedrosoandre/carros), pinned to commit `2d18dfd9db96bbf0d9cffa949deaf7f571388cbf`. That distributor documents geometry simplification and meshopt compression in its [model license record](https://github.com/pedrosoandre/carros/blob/2d18dfd9db96bbf0d9cffa949deaf7f571388cbf/LICENSE-3D-MODELS.md). We decode the compression, retain attribution, and record our material/anchor/reveal changes. The original geometry is Black Snow's work; this project authors its presentation and inspection fields.

BlenderKit, Sketchfab, source-authored geometry, native RealityKit/SceneKit, and desktop real-time configurators were considered. BlenderKit's royalty-free candidates are unsuitable for committing as stand-alone redistributed source assets. A verified attribution license is a simpler fit for this repository. Unreal/Unity provide useful visual references but add unnecessary runtime complexity for this native iPhone slice. Blender + glTF + native/custom PBR shader is the smallest reviewable production path.

## Reveal choreography

Use the premium motion vocabulary: no overshoot, a short settling interval, a slow absorption front and a quiet hold. The prototype demonstrates an authored evidence scenario, not recorded sensor output.

1. Begin with neutral satin body panels. Preserve silhouette, shadows, glass boundaries and material categories so the car remains readable.
2. Accepted evidence enables only an authored surface permission mask. Advance a distance threshold along mesh-edge shortest paths from the evidence seed. Never compute a screen-space circle or a free 3D sphere through unrelated panels.
3. Feather the threshold with smootherstep and a small mesh-local noise perturbation. Blend base color, roughness and metallic response together so the material emerges within the substrate.
4. Keep disconnected components and masked unseen vertices neutral at every animation time. Roof, far side, rear, interior and trunk must not become assessed because the visible side resolved.
5. A partial/uncertain observation must not resolve into full paint. The current shader study shows only accepted/neutral domains; the amber uncertainty policy remains defined by `MaterialReveal` and must be applied separately by the live adapter.
6. Only after the material settles may a restrained finding accent appear. An accent needs an existing finding/evidence join; no findings are bundled into the vehicle asset.
7. Respect reduced motion with an immediate final masked material state; retain all coverage semantics.

## Validation and limits

The same Blender source produces the review renders, surface masks, named anchors and GLB. Inspect both the source scene and reimported export. The final render must show believable vehicle geometry without a baked rectangle/background, while every revealed vertex must belong to an explicit permitted surface.

The target remains iPhone 15 Plus using ordinary camera frames and motion/pose. A desktop studio render is not proof of on-device performance or native shader fidelity. Native material integration, device frame rate, camera alignment and live evidence-to-permission mapping remain separate acceptance checks. The Toyota configurator blocked this research client with HTTP 403, so no claims about its specific live interaction are made. No evidence supports mechanical/safety conclusions from these graphics.
