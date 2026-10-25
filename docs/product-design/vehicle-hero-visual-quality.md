# Vehicle hero visual quality bar

**Scope:** UX direction for the judge-facing hero scenario.
**Ownership:** `docs/product-design/` only.
**Contract:** 0.1.0 region IDs remain metadata behind the model; this document does not add wire fields.

## Product decision

The current flat top-down labeled outline is a debug coverage diagram. It must not be presented as the finished 2.5D vehicle experience. The MVP hero should show one recognizable Toyota-like crossover in a polished perspective/isometric view, with believable body volume, windows, wheels, lamps, seams, materials, lighting, and depth. It should feel like a vehicle a customer can inspect, not a list of twelve pills.

## Hero composition

- Use a three-quarter front-left or rear-left camera angle with enough body visible to orient the user.
- Keep the vehicle centered on a quiet neutral ground plane with a soft contact shadow; avoid a showroom background that competes with findings.
- Show a restrained Toyota-like silhouette without copying a trademarked production model or implying a specific trim. Distinctive cues can include a compact crossover stance, grille, lamps, glasshouse, wheel/tire volume, door seams, and bumpers.
- Use physically plausible materials: painted body highlights, dark glass, rubber tires, translucent lamp covers, and subtle seam lines. Avoid neon outlines, flat fills, floating labels, and debug bounding boxes in the hero view.
- Keep one finding visually dominant. A pin, surface highlight, or callout must land on the actual panel, tire, windshield, or light surface. The callout names the region in plain language, then the visible observation and limitation.

## Uncertainty language in the model

- **Observed / acceptable evidence:** natural body material remains visible; use a small neutral pin or soft white highlight. Copy: “Photo captured · visible view available.”
- **Visible finding:** use a warm red/coral pin or localized surface highlight only at the observed panel/part. Copy: “A scrape-like mark is visible on the rear-left bumper.”
- **Low-confidence / glare / partial:** use amber glassy highlight and a short callout. Copy: “Needs another view · glare limits this area.” Amber must not imply damage severity.
- **Unseen / blocked:** leave the relevant surface grey-neutral with no finding pin. Copy in the adjacent list/callout: “Not captured · condition unknown.” Do not ghost a fake observation onto an unseen surface.
- Persistent footer: “Photos cannot assess hidden damage, mechanical condition, or whether the vehicle is safe to drive.”

The 12 canonical region IDs remain the metadata layer behind the model: `front`, `front-left`, `left`, `rear-left`, `rear`, `rear-right`, `right`, `front-right`, `roof`, `interior-front`, `interior-rear`, `trunk`. The model may group or occlude regions visually, but the accessible linear list must expose each state independently.

## Controlled rotation

- Start at the hero angle used by the scenario and preserve it when opening/closing evidence.
- Allow a bounded horizontal turntable gesture with snap points (front-left, front, rear-right, rear) rather than free orbit. Add visible **Rotate vehicle** and **Reset view** controls for Switch Control and VoiceOver.
- Do not require pinch, drag, haptics, sound, or precise 3D manipulation to discover a finding. Selecting a pin/list row should move the camera to a stable preset and focus the associated callout.
- When Reduce Motion is enabled, use a short dissolve/cut between presets; no continuous spin or parallax.

## Asset implementation ladder

1. **Preferred:** USDZ or glTF asset rendered in RealityKit/SceneKit with named surface anchors for the supported hero scenario.
2. **Acceptable:** a polished stylized 3D asset with real depth and material separation, still using surface anchors and bounded turntable presets.
3. **Fallback:** a high-resolution rendered turntable sequence at the same camera presets, with pins composited at known surface coordinates. This is a deliberate demo fallback, not the flat debug diagram.

Any fallback must preserve the same finding copy, uncertainty colors/text, source labeling, and accessible region list. A flat top-down outline is allowed only in internal debug tooling.

## One hero scenario

Use the lease-end wear replay for the primary judge story: rear-left bumper has one visible scrape-like mark, glare makes its extent unclear, and roof/interior/trunk remain unseen. The user rotates from the hero angle to the rear-left preset, taps the surface pin, reads observation → limitation, then sees one prominent **Arrange an in-person inspection** action. Alternate accident and financial scenarios can reuse the component later; they should not dilute the first hero’s visual polish.

## Acceptance criteria

- A reviewer can identify the vehicle as a coherent 3D object from the first frame; the flat labeled outline is absent from the judge path.
- Body, glass, wheels, lamps, seams, materials, lighting, and contact shadow remain legible at the device’s presentation size.
- The primary finding pin/highlight lands on the stated physical surface and follows the camera preset; it never floats in empty space.
- Low-confidence areas are amber and explain glare/partial quality; unseen areas are neutral/grey and remain explicitly unknown.
- Rotation is bounded, resettable, accessible without gesture, and preserves the selected finding/callout.
- The 12 region IDs remain independently represented in metadata/accessibility even when the 3D view groups surfaces.
- Evidence and replay surfaces retain **Demo · synthetic image** or live provenance labels; no visual treatment implies mechanical diagnosis or roadworthiness.
- VoiceOver can reach heading, coverage summary, region list, finding, limitation, rotate/reset controls, evidence, and recommendation without depending on the 3D canvas.
