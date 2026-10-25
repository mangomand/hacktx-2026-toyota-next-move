# Toyota Next Move — inspection journey

**Design owner:** Product/UX
**Contract alignment:** `docs/contracts` v0.1.0
**Scope:** journey, information architecture, copy, uncertainty language, scenario narrative, and accessibility. This document does not define wire schemas or implementation APIs.

## Experience promise

Help a person with little car knowledge collect useful exterior evidence safely, understand what remains unknown, and choose one practical next move. A captured image is evidence that a view exists; it is never proof that the vehicle is safe, mechanically sound, or free of hidden damage.

## MVP judge path

Keep the first slice short enough to understand in one pass:

1. Choose **Try sample inspection** or **Start capture** and see the synthetic/live provenance.
2. Follow three clearly labeled exterior positions with one instruction each; show one saved view, one glare-limited view, and one `unseen` area.
3. Open the visible finding: observation first, limitation second, evidence link third.
4. Show one prominent `Recommendation.nextMove`, its bounded rationale/caveats, and the unknown areas that keep the action appropriately cautious.
5. End with **Request human review** or the scenario-specific next move. Keep pause, skip, retake, and VoiceOver equivalents available throughout.

Defer decorative map polish, animated scanning effects, advanced rotation gestures, financial comparisons, and secondary scenario branching until the core path is judgeable and accessible. The map still needs a lightweight 3D orientation shell and a linear accessible region list; `unknown` and `unseen` remain visible in every result.

## Primary journey

1. **Choose a path**
   - Heading: **Guided exterior capture**
   - Primary: **Start capture**
   - Secondary: **Try sample inspection**
   - Disclosure beside replay: **Demo · synthetic images and results**
   - Safety copy: “Park somewhere safe, turn off the vehicle, and stay clear of traffic. You can pause or skip any area.”
   - Explain before capture what images are used for, where they are kept, and how to delete them.

2. **Orient and capture**
   - Start at **front-left — driver’s side**. Define left/right from the seated driver’s perspective.
   - One instruction at a time: “Fit this corner inside the outline.” Then “Step back slightly” or “Hold steady.”
   - After capture: “Front-left photo saved.” The user must confirm before advancing.
   - Before walking: “Lower your phone before moving to the next spot.” Never require walking in traffic, crouching, or entering the vehicle.
   - Persistent controls: **Pause**, **Skip this area**, **Get help**.

3. **Track coverage separately from assessment**
   - Coverage uses the canonical region IDs: `front`, `front-left`, `left`, `rear-left`, `rear`, `rear-right`, `right`, `front-right`, `roof`, `interior-front`, `interior-rear`, `trunk`.
   - Show a rotatable vehicle map for spatial orientation, plus a linear list for keyboard, Switch Control, and VoiceOver users.
   - A sector may say “Photo captured” while still saying “Glare limits assessment.” Never use a checkmark or “complete” to imply condition.
   - Recommended display mapping:

     | Contract state / quality | Plain-language label | User action |
     | --- | --- | --- |
     | `unseen` | Not captured — condition unknown | Capture this area |
     | `blocked` | Could not capture — condition unknown | Try again or skip |
     | `partial` + `low` | Needs another view — glare, darkness, or obstruction | Retake photo |
     | `covered` + `acceptable`/`high` | Photo captured — visible area reviewed with limits | View evidence |

   - State is conveyed with text, icon shape, and optional pattern; color is supplemental only.

4. **Explain findings**
   - Finding order: **What we can see → What limits this view → What to do next**.
   - Example: “A scrape-like mark is visible on the rear-left bumper. Glare makes its extent unclear. An in-person inspection can assess it.”
   - Persistent scope note for this first guided flow: “This review covers visible exterior images only. Interior and trunk areas remain unassessed unless a capture step is explicitly enabled. It cannot assess hidden damage, mechanical condition, or whether the vehicle is safe to drive.”
   - Never expose an uncalibrated confidence number as “percent certain.” Use the specific limitation from `quality`, `status`, and `caveats`.

5. **Recommend one next move**
   - Make the canonical `Recommendation.nextMove` the single prominent action. Keep **View supporting evidence**, **Retake photo**, **Flag an error**, and **Request human review** as secondary actions when applicable.
   - Render `rationale`, `caveats`, and `basedOn` immediately below the action. The person can edit supplied vehicle/agreement inputs or dismiss without losing progress.
   - Do not book, contact, share, or submit anything without an explicit user action.

## Next-move copy by scenario

These are synthetic demo scripts, not hidden fields in the contracts.

| Scenario | Recommended action label | Reason and limitation |
| --- | --- | --- |
| Lease-end wear | **Arrange an in-person inspection** | “Visible wear may warrant review. Your lessor decides what counts as chargeable wear under your agreement.” |
| Recent accident | **Arrange a professional inspection** | “A bumper appears displaced, but images cannot determine hidden damage or whether this vehicle is safe to drive.” If danger, injury, or fire is reported, interrupt with emergency guidance before scanning. |
| Financial stress / trade decision | **Review options with a person** | “Your finance details need a person’s review. Options depend on your agreement and lender.” Do not infer hardship or show cost/trade-off estimates in the first slice. |

If the contract recommendation is `request_more_views`, use **Retake the unclear photo**. If it is `review_with_customer`, use **Review options with a person**. For financial scenarios, use `review_with_customer` unless an explicit synthetic business rule authorizes another action. Defer cost ranges, trade-off scoring, APR, fees, and total-repayment comparisons from the first slice.

## Accessibility and agency

- Focus order: heading → safety instruction → current region/progress → capture guidance → Capture → Retake → Skip → coverage list → Continue.
- Result order: heading → one next move → rationale → limitations/unknown regions → primary action → evidence → edit inputs.
- VoiceOver examples: “Rear-left exterior. Image captured. Review limited by glare.”; “Skip rear-left exterior. This area will remain unassessed.”; “Three of six exterior areas in this demo subset have images. Two are unclear. Three remain unassessed.”
- Return focus to the control that opened evidence and preserve capture state. Announce sector completion once, not every camera frame.
- Support Dynamic Type through the largest sizes, 44-point targets, 4.5:1 text contrast and 3:1 control/graphic contrast. With Reduce Motion, use static progress. Capture and navigation must work without drag, sound, haptics, or precise alignment.
- Provide a linear region list as the accessible equivalent of the map. Do not expose decorative outlines or duplicate icons as focus stops.

## Replay narrative

The replay is always marked **Demo · synthetic images and results** and offers **Pause**, **Continue**, **Restart demo**, and **Start your own capture**.

Suggested 110-second judge flow: establish the driver question (0–15s); capture several regions including glare and one unseen area (15–40s); open one evidence frame and read its limitation (40–60s); reveal one next move with its evidence-linked rationale (60–85s); demonstrate VoiceOver, unknown regions, and the human escalation path (85–110s). Timing is rehearsal guidance, never a user-facing deadline.

## Camera-around-car guided slice

This slice makes the camera journey spatially legible while keeping the person out of traffic and out of the vehicle. Left and right are always from the seated driver’s perspective. The map is a progress and location aid; its color, height, and texture never represent damage severity, safety, or confidence.

### Directional prompt sequence

Give one spoken and visible prompt at a time. The next prompt is not shown until the current region is captured, skipped, or blocked.

| Stop | Directional prompt | Capture instruction and transition |
| --- | --- | --- |
| Front-left | **Start at the front-left corner, driver’s side.** | “Fit the headlight and bumper corner inside the outline.” Then: “Lower your phone before moving.” |
| Left | **Walk along the driver’s side to the middle.** | “Keep the full side panel in frame.” Do not ask the person to step into traffic. |
| Rear-left | **Move to the rear-left corner.** | “Look at the rear-left bumper and tail light.” If the view is glare-limited, say so before offering a retake. |
| Rear | **Stand behind the vehicle, where it is safe.** | “Center the rear of the vehicle.” If the location is unsafe, offer **Skip rear** and leave it `unseen`/`blocked`. |
| Trunk | **At the rear, open the trunk only if it is safe and unlocked.** | “Stand to the side, open the trunk, and capture the opening and latch area.” Never require entry into the trunk or vehicle. **Skip trunk** leaves the region unknown. |
| Rear-right | **Walk around to the rear-right corner.** | “Capture the opposite bumper and tail light.” Keep the phone down while walking. |
| Right | **Continue along the passenger side.** | “Keep the full side panel in frame.” Use the same seated-driver left/right labels in the accessible list. |
| Front-right | **Finish at the front-right corner.** | “Fit the opposite headlight and bumper corner inside the outline.” |

Prompt state copy is explicit and stable:

- Before capture: **“Next: rear-left exterior. Look for the bumper and tail light.”**
- Capture accepted: **“Rear-left photo saved. This records a view; it does not assess hidden damage.”**
- Quality limited: **“Rear-left photo saved, but glare limits this view. Retake or continue.”**
- User skip: **“Rear-left skipped. Condition remains unknown.”**
- Blocked: **“Rear-left could not be captured here. Condition remains unknown. Try again or skip.”**
- Permission/unavailable camera: **“Camera unavailable. Try again or use the synthetic sample inspection.”**

### Lightweight 3D vehicle shell and scan progress

Use a dark-navy scene with a lightweight 3D vehicle shell as the spatial orientation aid. The initial model is an untextured mid-gray shell: gray means the region is unseen or unknown, never safe or clear. Keep the camera and model deliberately simple so the shell remains a progress surface rather than a realism or damage simulation. A minimal top step bar (for example, **1 Capture · 2 Review · 3 Next move**) shows journey progress without competing with the model.

As each accepted view arrives, the corresponding surface on the shell fills with the state color for its canonical region. Color is a quick scan cue only; each surface also has a text label, marker shape, and optional pattern so state remains understandable without color. The shell can rotate for orientation, but rotation is optional and never required to discover a region or action. The accessible linear list is the source of truth for region order and state.

| Coverage state | 3D shell treatment | Label and action |
| --- | --- | --- |
| `covered` + `acceptable`/`high` | Scanned surface filled with the covered-state color and check-shaped marker | **Photo captured · view available** → View evidence |
| `partial` + `low` | Scanned surface filled with the partial-state color, hatch, and glare/darkness/occlusion glyph | **Needs another view · [reason]** → Retake |
| `unseen` | Unfilled gray shell surface with dotted marker | **Not captured · condition unknown** → Capture |
| `blocked` | Gray shell surface with cross-hatch and blocked glyph | **Could not capture · condition unknown** → Try again or skip |

The shell updates with a short, static transition; Reduce Motion uses an immediate state change. A nearby legend says **“Surface color shows coverage state, not a condition score.”** Do not use material gloss, lighting, surface wear, fill intensity, depth, or animation to imply severity, safety, confidence, or diagnosis. State text, shape, and pattern stay visible in the linear list even if the 3D shell is hidden or unavailable.

### Final labeled issue map and bounded analysis

After the last prompt, show **Issues on vehicle** with numbered markers anchored to the final 3D vehicle shell, for example **1 · Rear-left bumper** and **2 · Right side panel**. Keep the same numbered labels in a linear **Issues by location** list. Markers are added only for a contract-backed finding with evidence; `unseen` and `blocked` regions cannot receive an issue marker.

Selecting a numbered marker or its list row opens the bounded analysis card in this order:

1. **Visible observation:** what the image shows, using “appears” where appropriate.
2. **View limitation:** glare, darkness, occlusion, motion, or an unseen adjacent area.
3. **Supporting evidence:** a source-labeled image or **Demo · synthetic image** in replay.
4. **What remains unknown:** hidden damage, mechanical condition, roadworthiness, or unassessed regions.
5. **Recommended next move:** one `Recommendation.nextMove`, with its rationale, caveats, and `basedOn` identifiers.

Example: **“1 · Rear-left bumper — A scrape-like mark appears on the bumper. Glare obscures its full extent. Demo · synthetic image. Hidden damage and driving safety remain unknown. Recommended next move: Arrange an in-person inspection.”** This card is analysis of visible evidence, not a diagnosis. Keep **Retake**, **Request human review**, and **Return to vehicle** available without losing coverage.

### Synthetic fallback and recovery

If camera permission is denied, capture hardware is unavailable, a prompt cannot be completed safely, or replay is selected, offer **Try sample inspection** at the same point in the journey. The fallback is deterministic and visibly marked **Demo · synthetic images and results**. It may populate covered, partial, unseen, and blocked states, but never changes a skipped live region into a captured live view. Synthetic evidence paths and issue labels remain source-labeled in the final map and analysis.

If a sample asset is missing or fails to load, show **Sample inspection unavailable. Retry or start your own capture.** Preserve the current map/list state and do not create a finding from a missing artifact. A camera permission retry returns focus to **Try again**; a sample retry returns focus to **Restart demo**.

### Slice acceptance

- Every directional prompt names a canonical region, uses the seated-driver perspective, and supplies a safe pause/skip path.
- Trunk guidance requires safe positioning and never requires entering the vehicle; an unsafe or unavailable trunk remains `unseen` or `blocked`.
- Prompt copy distinguishes saved evidence from assessment and announces glare, darkness, occlusion, motion, and unknown state in text.
- The 3D shell fills scanned surfaces with state colors while text, marker shape, and optional pattern carry the same state; no color, material, lighting, height, animation, or density communicates severity or safety.
- The dark-navy scene, minimal top progress steps, lightweight 3D vehicle shell, gray unseen surfaces, and state-colored scanned surfaces are presentation cues only; gray means unseen/unknown, not safe or clear, and the same state is available in the list without relying on the visual treatment.
- The final vehicle view anchors each issue marker to its canonical region and number, mirrors labels in a linear list, and omits markers for `unseen`/`blocked` regions or findings without evidence.
- An issue card contains observation → limitation → evidence provenance → unknowns → one bounded next move; it does not claim diagnosis, hidden damage, or roadworthiness.
- Camera failure and synthetic replay preserve state semantics, show the synthetic badge, keep evidence paths source-labeled, and offer retry/start-capture recovery without fabricating a live capture.
- VoiceOver reads prompt, region, state, limitation, action, and map label once; focus returns to the invoking prompt or issue row. Map decoration is excluded from the accessibility tree.

## Contract alignment and open questions

- Aligned to `ScanSession.status`/`mode`, `CoverageRegion.regionId/state/quality`, `Finding.status/regionId/evidenceRefs`, `Recommendation.nextMove/rationale/confidence/caveats/basedOn`, and synthetic `VehicleProfile`/`Agreement` provenance.
- Preserve `unknown`, `unseen`, and `blocked`; absence of an artifact is not a clean result. Keep exterior and interior regions distinct.
- First-slice usability constraint: do not show financial cost ranges or trade-off scores. Use bounded `rationale`, `caveats`, and `basedOn` text and route financial recommendations to `review_with_customer` unless an explicit synthetic rule says otherwise.
- `CoverageRegion.notes` may carry plain-language reasons such as glare, darkness, or occlusion; no new enum is needed for v0.1.0.
- Evidence is limited to local synthetic paths with explicit source labeling. Keep the replay badge and image-handling copy visible wherever evidence is shown.
- No contract-dependent implementation is authorized until the coordinator releases the freeze and assigns UI files.
