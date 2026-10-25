# Camera-first AR scan behavior contract

**Workstream:** B — 3D Experience (product/design partner)  
**Input:** user AR scanning reference/specification plus current iOS and Vision handoffs.  
**Owned files:** `docs/product-design/` only.  
**Dependency:** Workstream A must provide real frame quality, camera pose/tracking/depth where supported, and current missing-region reasons; Workstream B maps those signals to camera-aligned geometry and surface anchors; Workstream C verifies the live and replay paths.  
**Handoff artifact:** this document is the UX acceptance contract for the orchestrator and iOS/Vision leads.

## Primary interaction

The scan is a full-screen live camera surface. The phone view is the product, not a form with a camera thumbnail or a static 3D dashboard.

- Top-left: **Cancel**.
- Top-right: **Finish**. Enabled only when required coverage is sufficient; otherwise it remains available with the explanation **“Keep scanning — rear-left and roof still need a view.”**
- Bottom-left: small translucent **Scan settings** control.
- Bottom center: thin progress/scan indicator, never a percentage-only inspection score.
- Center/near-object: concise contextual prompt, for example **“Move toward the rear-left corner”**, **“Tilt slightly up to include the roof”**, or **“Hold steady — capturing this surface.”**
- Chrome is dark/translucent with high-contrast white type. Controls do not obscure the surface being scanned.

## Progressive camera-aligned reconstruction

1. Begin with the live camera and a neutral, low-contrast scene; do not show the flat region map as the primary surface.
2. As ARKit/RealityKit supplies pose, depth, and feature points, draw thin bright-white or soft-emissive contours directly over observed boundaries. Contours follow the camera perspective and remain registered while the phone moves.
3. Build only geometry supported by current evidence. Newly observed planes/volumes resolve cleanly in place; unobserved areas remain absent/neutral rather than being filled by a complete car model.
4. The prompt responds to missing coverage. When the current region is sufficiently observed, say **“Rear-left captured. Move to the rear.”** When quality drops, say **“Glare is limiting this view. Try a different angle.”**
5. Finish transitions only after the required scan coverage gate. If the user finishes early, preserve the partial reconstruction and explain the missing regions; never imply a complete inspection.

## State copy

| State | Camera-layer copy | Reconstruction treatment | Finish behavior |
| --- | --- | --- | --- |
| Missing / unseen | **“Move toward the rear-left corner.”** | No geometry for that surface; neutral/absent | Explain missing region |
| Partial / glare or motion | **“Glare is limiting this view. Try a different angle.”** | Amber quality cue; no finding pin from quality alone | Keep scanning or finish with limitation |
| Blocked | **“We could not capture this area. Try again when it is safe.”** | Neutral/absent; never red damage styling | Retry or skip with unknown state |
| Observed / covered | **“Rear-left captured. Move to the rear.”** | White contours resolve into the observed surface | Counts toward required coverage |
| Visible finding | **“A scrape-like mark is visible on the rear-left bumper.”** | Local surface highlight/pin anchored to the bumper | Finish can show finding after transition |

No user-facing copy may expose `blur`, `lighting`, `motion`, `partial`, `blocked`, `unseen`, or a confidence decimal without this plain-language translation. Hidden damage, mechanical condition, and whether the vehicle is safe to drive remain unknown.

## Transition to final vehicle view

After **Finish**, crossfade from the camera-aligned reconstruction into one polished, rotatable Tesla-style vehicle view. Preserve the selected camera-facing orientation and carry each observed surface into the corresponding asset anchor. The final model must have coherent body, glass, wheels, lamps, seams, materials, lighting, and depth; it must not be a primitive rounded box or floating label collection.

- Observed surfaces resolve to the available vehicle material/geometry.
- Low-confidence surfaces remain amber with their reason.
- Unseen/blocked surfaces remain grey/neutral and show **Condition unknown** in the accessible list.
- A finding is a pin/highlight on the actual panel, tire, windshield, or light, with tap-through evidence, uncertainty, and one next action.
- Rotation is bounded to stable presets with **Reset view**. The accessible 12-region list remains authoritative when the canvas is unavailable.
- Replay/simulator fallback is explicitly labeled **Demo · synthetic replay** and must not masquerade as live AR.

## Acceptance tests

- **Camera-first:** On a supported device, the first scan frame is the live camera with minimal chrome; no flat region map is the primary interaction.
- **Registration:** White contours and newly built geometry remain aligned to the camera perspective while the phone moves; they do not pop in as a detached top-down diagram.
- **Prompt response:** Moving to a missing region changes the contextual prompt; quality degradation changes the prompt to a reason plus retake/move action.
- **Coverage gate:** Finish is disabled or clearly explains missing regions until required coverage is sufficient.
- **Uncertainty:** Partial/glare is amber; unseen/blocked is absent or neutral; neither produces a finding without evidence.
- **Finding anchor:** A visible finding lands on a named physical surface and remains attached through camera movement and final-view rotation.
- **Final transition:** Finish produces a polished rotatable vehicle view with preserved observed/amber/neutral states and no primitive rounded-box fallback on the judge path.
- **Accessibility:** VoiceOver can complete the scan and final review without operating the AR canvas, using the 12-region list, current prompt, evidence, limitation, and next action. State is not color-only; Reduce Motion replaces continuous reconstruction animation with restrained fades.
- **Fallback honesty:** Unsupported device/simulator path is deterministic replay/demo, visibly labeled, and retains the same uncertainty/no-diagnosis copy.

## Current implementation mismatches for coordinator

Read against the current iOS/Vision handoffs and source:

- iOS currently presents a native SceneKit primitive car after capture, not a camera-aligned AR session with registered contours or progressive in-place geometry.
- The current capture surface has guided prompts and a 3D result, but no live ARKit/RealityKit pose/depth/feature-point loop or Finish coverage gate matching this contract.
- Vision supplies quality and region evidence, but does not yet provide camera pose, surface anchors, or geometry updates; its map remains a data/presentation model.
- Current model markers are fixed approximate spheres/positions; they are not attached to evidence-specific panel/tire/windshield/light surfaces.
- Existing replay support is the correct unsupported-device fallback, but it must be explicitly labeled demo/replay on every fallback surface.
