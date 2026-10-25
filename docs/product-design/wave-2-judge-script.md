# Wave 2 judge rehearsal script

**Purpose:** demonstrate the shortest accepted post-coverage journey without implying a mechanical diagnosis.
**Scope:** UX copy and timing only; no new contract fields, fixtures, or UI implementation.

## 75-second path

| Time | Screen/state | Spoken or visible copy | Acceptance cue |
| --- | --- | --- | --- |
| 0–10s | 3D coverage shell | **Your coverage** — “Here is what the photos show and what still needs another view.” | 3D shell and linear list both identify regions; state is not color-only. |
| 10–25s | Region list | **Rear-left · Needs another view** — “Glare limits this area.” **Retake photo** | Low-quality state explains the reason and preserves other coverage. |
| 25–35s | Region list | **Roof · Not captured** — “Condition unknown.” **Capture this area** | `unseen` remains visible; no clean result is implied. |
| 35–50s | Finding card | “A scrape-like mark is visible on the rear-left bumper. Glare obscures its full extent.” **View supporting photo** | Observation precedes limitation; evidence is labeled **Demo · synthetic image**. |
| 50–65s | Recommendation | **Recommended next move** — **Arrange an in-person inspection** | One `Recommendation.nextMove` is prominent; rationale, caveats, and **Based on** are visible. |
| 65–75s | Human action | “Your lessor decides what counts as chargeable wear.” **Request human review** | External action requires deliberate user input; no fee or safety promise. |

## Accessibility readout

VoiceOver should encounter: “Your coverage” → summary → “Rear-left. Needs another view. Glare limits this area.” → “Roof. Not captured. Condition unknown.” → finding observation → limitation → “Recommended next move” → primary action. After **View supporting photo**, return focus to its invoking row.

## Recovery beats

- If the retake is declined: keep **Needs another view** and offer **Request human review**.
- If the camera is unavailable: retain the saved coverage, mark the next area `unseen`, and offer **Try sample inspection**.
- If the user reports danger, injury, or fire: stop the inspection path and show emergency guidance before any recommendation.

## Handoff check

This script uses only existing `CoverageRegion`, `Finding`, `Recommendation`, `artifactRefs`, and `unknownRegions` concepts. It is ready for iOS to rehearse after coordinator authorization; it does not authorize implementation or schema changes.
