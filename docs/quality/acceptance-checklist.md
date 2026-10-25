# Toyota Next Move vertical-slice acceptance checklist

Owner: quality/safety/demo validation. Coordinator owns contract integration and final acceptance. Evidence must be attached to the build/replay run; a screenshot alone does not prove state transitions.

## Traceable gates

| ID | Gate and observable evidence | Severity if missing |
|---|---|---|
| VS-01 | A new session starts with synthetic replay available from the first screen; scenario ID/version and any test seed are recorded in debug/demo evidence. | Blocker |
| VS-02 | The guide presents a 360° exterior route with named canonical regions. Each sector has the canonical `CoverageRegion.state` (`unseen`, `partial`, `covered`, or `blocked`), plus a timestamp/source. | Blocker |
| VS-03 | Coverage is computed from captured sectors only. A region whose contract state is `unseen`, `partial`, or `blocked` is never rendered as inspected, safe, or clear. A partial vehicle map visibly marks unknown areas. | Blocker |
| VS-04 | Every visible finding links to an image/frame and sector, shows uncertainty with confidence limits, and separates observation from interpretation. | High |
| VS-05 | Copy never claims hidden mechanical diagnosis from exterior imagery. Unknown, occluded, glare, and out-of-frame states remain explicit. | Blocker |
| VS-06 | Vehicle/loan/lease data (and customer context only when contracted) are labeled synthetic and are joined by a same DemoScenario with resolvable references. Missing data produces an explicit unknown state. | High |
| VS-07 | The recommendation is exactly one canonical `Recommendation.nextMove`, with `rationale` and `basedOn` references linked to observations/data and an escalation path when confidence or safety thresholds fail. | Blocker |
| VS-08 | A reviewer can move from recommendation to supporting evidence and back without losing scan state. | High |
| VS-09 | Permission denial, camera interruption, offline mode, app backgrounding, and rotation/size changes preserve or safely reset state with user-visible copy. | High |
| VS-10 | VoiceOver labels, Dynamic Type, contrast, touch targets, reduced motion, and error recovery pass the accessibility checks in `test-strategy.md`. | High |
| VS-11 | A deterministic replay completes on a clean simulator twice with the same pinned scenario and test controls and produces the same coverage, findings, and recommendation. | Blocker |
| VS-12 | Judge timing is recorded from session start to first actionable next move; target <= 120 seconds for replay and <= 180 seconds for guided scan rehearsal. | High |

All gates are **not run** until build-specific evidence is attached. Time/clarity thresholds are proposed QA targets for coordinator acceptance. Contract-dependent execution remains frozen pending Wave 1 authorization.

## Evidence packet

For each gate record build SHA, simulator/device model and OS, replay seed, contract version, test command, result, and a redacted screen recording or screenshots. Do not store customer-like identifiers outside synthetic fixtures.

## Release stop rules

Stop and escalate if a finding could be read as a mechanical diagnosis, if an unseen sector is counted as covered, if recommendation evidence is missing, if synthetic data is presented as real, or if the deterministic replay diverges. A low-confidence visible observation may recommend inspection/service; it may not assert a hidden cause.

## Accessibility and copy gates

- VoiceOver completes scan, evidence review, next-move selection, and error recovery without sighted help; every control exposes name, role, value/state, and findings expose location plus uncertainty.
- At supported Dynamic Type sizes through accessibility XXXL, essential text has no truncation or overlap, scrolling is allowed, and primary controls remain reachable; interactive targets are at least 44 x 44 points.
- Normal text contrast is at least 4.5:1, large text 3:1, and meaningful controls/graphics 3:1 in light and dark appearance. Color-only meaning is prohibited.
- With Reduce Motion enabled, nonessential animation is removed and processing is explained with static status; no flashing content.
- Camera denied/unavailable, blurry or interrupted capture, offline, and analysis failure each explain the problem, preserve confirmed work, and offer a reachable recovery. Incomplete analysis is explicit.
- Use observation copy such as “Visible mark-like area in the rear-left frame; glare may affect assessment.” Never use “safe to drive,” “roadworthy,” “engine healthy,” or a hidden causal diagnosis from exterior imagery.
- Smoke, leaking fluid, visibly damaged tires, or other immediate hazards branch to a safety escalation: stop using the vehicle when safe, move away from traffic, and contact roadside/emergency help as appropriate. Do not bury escalation behind a routine recommendation.
