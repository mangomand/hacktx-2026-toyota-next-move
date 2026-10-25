# Wave 2 UX — post-coverage decision path

**Scope:** `docs/product-design/` only
**Contract:** v0.1.0
**Goal:** map → one visible finding → one `Recommendation.nextMove` → human/scenario action.

## Shortest flow

### 1. 3D coverage shell

Heading: **Your coverage**

Lead copy: “Here is what the photos show and what still needs another view.”

Use a lightweight 3D vehicle shell in a dark-navy scene plus the accessible linear list. The shell is for location and coverage, not a safety score; unseen surfaces remain gray. Show a compact summary above it:

> **2 areas need attention · 1 area not captured**

Each region row has one label, one state phrase, and one action:

| Contract state | Visible copy | Action |
| --- | --- | --- |
| `covered` + `acceptable`/`high` | **Photo captured · visible view available** | View photo |
| `partial` + `low` | **Needs another view · glare limits this area** | Retake photo |
| `unseen` | **Not captured · condition unknown** | Capture this area |
| `blocked` | **Could not capture · condition unknown** | Try again |

Never use “clear,” “safe,” or a green vehicle silhouette for a covered region. Scanned surfaces may use state colors as a supplemental cue only; text, marker shape, and optional pattern remain required. “Photo captured” means an image passed the capture gate; it does not mean the area is free of damage.

### 2. One visible finding

Open the first finding from the map or list. Keep the card in this order:

1. **Observation:** “A scrape-like mark is visible on the rear-left bumper.”
2. **Limitation:** “Glare obscures its full extent.”
3. **Evidence:** “View supporting photo” with `artifactRefs` source label, for example **Demo · synthetic image**.
4. **Action:** “Retake rear-left photo” or “Request human review,” depending on `Finding.status` and recommendation.

For `needs_review`, say **Needs another view** and explain why in plain language. For `unseen`, do not create a visual finding; show **No observation — this area was not captured**. For `not_a_diagnosis`, include: “This is a visible observation, not a mechanical diagnosis.”

Persistent footer:

> “Photos cannot assess hidden damage, mechanical condition, or whether the vehicle is safe to drive.”

### 3. One recommendation

Heading: **Recommended next move**

Show exactly one prominent action derived from `Recommendation.nextMove`, with `rationale`, then `caveats`, then a short **Based on** list from `basedOn`.

Example:

> **Arrange an in-person inspection**
> A visible mark needs a closer look, and glare limits this photo.
> **Still unknown:** the full extent of the mark and any hidden condition.
> **Based on:** rear-left photo, coverage status, and visible finding.

Secondary controls remain available but visually quieter: **View supporting photo**, **Retake photo**, **Request human review**, **Edit details**, **Start over**. No contact, booking, sharing, or submission occurs without a deliberate user action.

For a financial scenario, render **Review options with a person** (`review_with_customer`) unless an explicit synthetic rule says otherwise. Do not show cost estimates or trade-off scores in this slice.

### 4. Human or scenario action

Use the scenario’s plain-language action after the recommendation:

- Lease-end: **Arrange an in-person inspection** — “Your lessor decides what counts as chargeable wear.”
- Accident: **Arrange a professional inspection** — “Images cannot determine hidden damage or driving safety.” If danger, injury, or fire is reported, show emergency guidance before this flow.
- Financial stress: **Review options with a person** — “Options depend on your agreement and lender.”

Confirmation copy must describe the next step without implying an external action happened: “You chose to review this with a person.”

## Acceptance criteria

- **Map clarity:** A user can identify the first finding’s region from map and list labels without relying on color or rotation.
- **State distinction:** `covered`, `partial`/low quality, `unseen`, and `blocked` each have distinct text and action; captured never implies assessed or safe.
- **Low-quality recovery:** A glare-limited row says what is wrong and offers **Retake photo** without losing other coverage.
- **Unseen honesty:** An unseen region remains visible in the map/list and result summary; no finding or clean result is generated for it.
- **Finding restraint:** Finding copy uses observation → limitation → action and never claims hidden damage, mechanical condition, roadworthiness, or certainty from imagery.
- **Recommendation focus:** Exactly one primary `nextMove` is prominent; rationale, caveats, and `basedOn` are readable without opening a secondary screen.
- **Evidence provenance:** Every evidence surface labels local synthetic artifacts as **Demo · synthetic image**; live capture surfaces do not inherit the demo label.
- **Agency:** Secondary recovery and human-review actions remain reachable; external contact/booking/sharing requires explicit confirmation.
- **Accessibility essentials:** VoiceOver reads heading → state summary → region label/state → finding → limitation → next move. Focus returns to the invoking map/list row after evidence review. Text, icon shape, and pattern carry state; controls remain at least 44 pt.
- **Safety:** Accident danger reports interrupt scanning with appropriate emergency guidance. No flow asks a person to walk into traffic or treats the result as a driving-safety decision.

## Handoff to iOS

Implement this as a presentation sequence over the existing `ScanSession`, `CoverageRegion`, `Finding`, and `Recommendation` contracts. Do not add fields or enums. Read `CoverageRegion.notes` for plain-language glare/darkness/occlusion reasons and preserve `unknownRegions`. Use local synthetic `artifactRefs` only for replay evidence, with an explicit source label. Coordinator authorization is still required before contract-dependent implementation; this document is copy/state acceptance for the iOS lead.
