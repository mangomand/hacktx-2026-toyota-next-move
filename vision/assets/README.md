# Current vehicle: Toyota Crown

The primary asset is **`nextmove-crown.glb`**. Editable source: **`nextmove-crown.blend`**. These supersede the old primitive fixture, which is not used by the material-study viewer.

The detailed geometry is **Toyota Crown athlete s210 by Black Snow, CC BY 4.0**. This project authors its materials, surface-distance reveal, anchors, lighting and camera study; it does not claim authorship of the source car. See [CREDITS.md](CREDITS.md) and [source/provenance.json](source/provenance.json). Retain visible attribution in every public viewer/application acknowledgment.

## Inspect it

- `review/vehicle-beauty.png`: actual Blender render of the asset with its authored deep-blue material, no inspection assessment.
- `review/vehicle-neutral.png`: neutral inspection starting state.
- `review/vehicle-reveal.png`: intermediate mesh-conforming reveal.
- `review/vehicle-observed.png`: authored accepted surfaces resolved; other body areas remain neutral.
- `review/material-reveal.mp4`: actual Blender material and restrained camera animation, not a CSS mockup.
- `../preview/index.html`: interactive WebGL review of the actual GLB, with orbit, reset and a live material-reveal shader. Run `npm ci --prefix vision/preview`, then `python3 -m http.server 8765 --bind 127.0.0.1` from the repository root and open `http://127.0.0.1:8765/vision/preview/`.

## Build

Run Blender 4.5.3 with `--background --python vision/tools/build_vehicle.py`, or run the same script through the isolated Blender MCP authoring session. The build is offline and reads the bundled attributed source. It replaces only its own generated `nextmove-crown.*`, `reveal-surfaces.json` and `review/` outputs. Review output varies slightly by renderer/hardware; geometry and field construction are deterministic.

`source/crown-ccby.glb` is a decoded copy of the source distributor's meshopt-compressed model. `source/provenance.json` pins the distributor commit, source hash, license and preparation steps. No customer camera media is included.

## Runtime seam

The GLB contains the vehicle, named anchor empties, existing UVs and an additional `InspectionReveal` UV layer for body meshes. **It contains no camera, light, floor, backdrop, baked image background, or automatic paint animation.** Body base materials are exported neutral. Node extras identify the reveal channel/domain; the Blender graph is not a portable glTF shader, so bind the custom runtime reveal using the field described in `reveal-surfaces.json` and demonstrated by `../preview/viewer.js`.

The extra UV channel stores `(surface distance / 2.8 metres, permission)`. Mesh extras specify `revealUVChannel`. Permission zero stays neutral at every radius; disconnected components stay unknown. Distance is shortest path along mesh edges, joining coincident vertices across UV seams. Tiny procedural variations soften the absorption front. Base color, metallic response and roughness emerge together, inside the surface material. No texture sticker or flat section overlay is used.

The permission set in the study is explicitly authored demonstration data; it is **not live evidence**, a measured reconstruction, a defect detector, or a finding. Runtime accepted evidence must supply/limit the permission domain before any reveal. Partial/uncertain states must not resolve into accepted paint. The browser includes an explicit asset-beauty mode which reveals the source paint for model inspection and is not an inspection assessment.

Anchors use the asset-specific coordinates in `reveal-surfaces.json`: Blender +X vehicle left, -Y front, +Z up; GLB +X vehicle left, +Y up, +Z front. Existing normalized `heroDefaults()` coordinates must not be reused on this revision. Canonical region IDs stay as metadata; no wire schema is introduced.

The original `hero-vehicle-stylized.gltf` is retained as a pre-existing historical importer fixture. It is not the model shown by this viewer.
