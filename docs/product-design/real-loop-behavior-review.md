# Real-loop UX behavior contract and implementation review

**Scope:** Product/UX review of the current iOS and Vision handoffs.  
**Contract:** canonical v0.1.0; no new wire fields.  
**Intent:** define the plain-language loop and identify mismatches for coordinator repair.

## Dynamic prompts and state copy

The prompt must name the current region, the reason for the state, and one safe next action. Do not expose quality enum names or numeric scores.

| State | Plain-language prompt | Primary action | Secondary/accessible text |
| --- | --- | --- | --- |
| Missing / `unseen` | **“Rear-left is not captured. Its condition is unknown.”** | **Capture rear-left** | “You can skip this area; it will remain unknown.” |
| Partial / low quality | **“Glare makes the rear-left area hard to assess. Try a different angle.”** | **Retake rear-left** | “Your saved photo is kept. This area needs another view.” |
| Blocked | **“We could not capture rear-left. The area remains unknown.”** | **Try rear-left again** | **Skip for now** keeps the state visible and does not imply a clean result. |
| Observed / covered | **“Rear-left photo saved. A visible view is available.”** | **Continue** | “Photo captured does not mean the area is safe or free of hidden damage.” |
| Observed finding | **“A scrape-like mark is visible on the rear-left bumper.”** | **View supporting photo** | “Glare obscures its full extent. This is a visible observation, not a mechanical diagnosis.” |

Dynamic reason mapping for `CoverageRegion.notes`:

- `glare` → “Glare makes this area hard to assess. Try a different angle.”
- `darkness` → “This area is too dark to assess. Move to a brighter, safe position.”
- `occlusion` → “Something blocks this area. Clear the view only if it is safe, then try again.”
- absent note with `partial` → “This area needs another view.”

The result summary should say **“X areas have photos · Y need another view · Z were not captured”**. It must never say “X% inspected,” “clear,” or “safe.”

## Model behavior when evidence arrives

The vehicle model is a presentation surface for the canonical region list, not a second source of truth.

1. Start with a stable three-quarter perspective and neutral grey surfaces for `unseen`/`blocked` regions.
2. When a quality-gated photo arrives, resolve only that region’s surface to the observed material state; do not recolor the whole vehicle.
3. When a low-quality/partial frame arrives, keep that surface amber and show the reason; do not show a damage pin unless Vision has an evidence-backed finding.
4. When a finding arrives, attach one pin/highlight to the actual named surface (panel, tire, windshield, or light) and open a callout containing observation → limitation → evidence.
5. When the user selects a region row, move to a bounded camera preset and keep the pin/callout anchored. **Reset view** returns to the starting angle without losing selection.
6. When evidence is absent, do not place a speculative marker. The adjacent accessible row remains the authoritative state.
7. Evidence source remains visible: **Demo · synthetic image** for local replay artifacts; live capture keeps live provenance.

The accessible linear list must expose all 12 region IDs independently even when the model groups surfaces or the camera occludes them. The canvas cannot be required to discover a state.

## Current implementation mismatches

Reviewed `docs/modules/ios-capture/HANDOFF.md`, `ios/Sources/CaptureCore/CaptureCore.swift`, `ios/Sources/CaptureDemo/CapturePresentation.swift`, `ios/Sources/CaptureDemo/CaptureDemoApp.swift`, `docs/modules/vision/handoff.md`, `vision/Sources/VisionCore/VisionCore.swift`, and `vision/Sources/VisionCore/FrameAnalysis.swift`.

1. **High — quality prompts expose enum labels.** iOS builds “Retake this view: blur, lighting, motion.” This is not usable plain language and does not name the current region. Map each prompt to the dynamic copy above.
2. **High — blocked is presented as skipped but removed from progression.** `skipCurrent()` marks a region blocked, while `nextUncovered` excludes blocked regions. The UI says it can be revisited, but no next action revisits it. Keep **Skip for now** available from the list or make the blocked row’s **Try again** action explicit.
3. **Medium — Vision prompt is global, not contextual.** `FrameAnalyzer` emits “Capture another view of: …” with every missing region. The capture surface needs the current region’s reason and action; use the global list only for the summary.
4. **High — numeric confidence leaks into judge-facing copy.** iOS renders “confidence 0.90” in the finding description and a recommendation confidence number. The UX contract requires reason-specific uncertainty language; hide raw confidence from the primary path.
5. **High — model markers are not surface-attached.** The SceneKit primitive vehicle places corner spheres and a fixed rear marker; it does not attach findings to named panel/tire/windshield/light surfaces or follow evidence-specific camera presets. This is acceptable as an interim debug view only, not as the judge-facing Tesla-style model behavior.
6. **Medium — state copy is raw enum text in accessibility.** Vision’s `MapRegionPresentation.accessibilityText` says `rear-left: partial, low quality`; it must use the plain-language state and reason copy above while preserving the region ID in metadata.
7. **Medium — observed finding source is synthetic but not consistently scoped in the model callout.** The result label includes a demo prefix in iOS, but the model surface/callout acceptance must retain the same source label when a pin is selected.

## Acceptance for coordinator integration

- No user-facing `blur`, `lighting`, `motion`, `partial`, `blocked`, `unseen`, or confidence decimal appears without a plain-language translation.
- A blocked region is visible, unknown, and retryable from the list even after the guided route advances.
- A low-quality region is amber with a reason and retake action; it does not generate a finding by quality alone.
- An observed finding has a real evidence reference and a surface-specific pin/callout; unseen regions never receive one.
- The model changes only the evidence-backed region, keeps neutral unseen surfaces, and preserves selection through bounded rotation/reset.
- VoiceOver can complete the loop without operating the 3D canvas: summary → region state → finding/limitation → evidence → one recommendation.
- Hidden damage, mechanical condition, roadworthiness, and safety remain explicitly unknown.
