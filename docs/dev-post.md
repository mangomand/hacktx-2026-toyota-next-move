# Toyota Next Move: turning a vehicle walkaround into a clear next step

**A HackTX 2026 prototype from Toyota Financial Services**

When a customer asks, “What is the smartest next move for me and my Toyota?”, the hard part is rarely producing more information. The hard part is helping someone gather the right evidence, understand what that evidence does and does not show, and act with confidence.

Toyota Next Move is our prototype for that experience. It guides a non-expert through an exterior and interior vehicle inspection, turns the captured evidence into an uncertainty-aware vehicle view, and is designed to combine visible findings with synthetic customer, vehicle, loan, and lease data to produce one plain-language recommendation.

The goal is a premium inspection tool that feels at home on an iPhone: open the camera, walk around the vehicle, see the scan build, review what was found, and leave with a useful next action.

## The experience

The journey is deliberately short:

1. **Start Scan.** The user taps once and moves around the vehicle.
2. **Guided coverage.** The app continuously evaluates camera frames and updates the next-area prompt as coverage is accepted.
3. **Evidence-backed map.** A vehicle view makes covered, partial, blocked, and unseen regions visible.
4. **Findings.** Visible observations are designed to attach to vehicle surfaces with evidence, confidence, and uncertainty; attaching one to a real surface anchor is a next integration step.
5. **Next Move.** The intended product path combines the findings with a synthetic customer and agreement profile and returns one clear action: self-service, follow-up, or an eligible offer.

The app keeps the user oriented throughout. Unseen areas stay visibly unknown. A normal material state means that no visible issue was found in the captured evidence; it never means that the vehicle is mechanically healthy.

## Why coverage matters

A camera can only tell us about what it sees. That sounds obvious, but it is easy for an inspection experience to turn missing evidence into a reassuring green check.

Next Move models coverage explicitly across 12 regions. A region can be covered, partial, blocked, or unseen. Low-quality frames do not advance coverage, and the absence of evidence cannot create a clean finding. When the view is ambiguous, the app asks for more evidence or escalates to human review.

That uncertainty is part of the product, not an error state to hide. It gives the customer a more honest answer and gives a future service workflow a clear place to pick up.

## A local-first technical foundation

The prototype is a SwiftUI iOS vertical slice. AVFoundation supplies camera frames, while ARKit may provide tracking and pose signals; the capture layer emits `ScanSession` and `CoverageRegion` records; the perception boundary consumes evidence references and emits findings; product logic produces a single `Recommendation`.

The system has two interchangeable inputs:

- **Live capture** for the phone experience, with continuous quality, motion, and evidence checks.
- **Deterministic replay** for development, judging, and QA. The replay uses decoded Toyota video frames and fixed JSON fixtures, so the same scan can be inspected repeatedly without a physical vehicle.

The shared JSON contracts keep those paths aligned. Capture, perception, product logic, and QA can evolve independently while exchanging the same session, region, finding, vehicle, agreement, and recommendation records.

## Where model perception fits

The optional perception bridge samples a JPEG no more than once every two seconds and sends it to a private backend. The backend calls a vision model with structured output and returns only bounded observations: whether a vehicle is present, how usable the view is, which canonical regions are recognizable, and short guidance.

The app requires two distinct consecutive observations at confidence 0.7 or higher before recording a region. The requested region is never sent as a hint, and an uncertain or contradictory response cannot manufacture coverage. The bridge does not diagnose mechanical or safety conditions, and no image produces a hidden-health conclusion.

This boundary is intentionally small. It lets us evaluate model behavior on a labeled fixture set, measure wrong-region accepts and unknown rates, and replace the model later without changing the capture or recommendation contracts.

## The reveal is an evidence state

The vehicle begins as a neutral gray model. As evidence accumulates, observed surfaces reveal their normal vehicle material. Partial coverage produces a partial reveal; unseen areas remain neutral; blocked or uncertain regions stay muted. Findings sit above that material as restrained surface accents.

This is more useful than coloring whole sections of a car. The material communicates where evidence exists, while the finding communicates what the evidence shows. A polished Toyota-like asset, named surface anchors, and a geometry-conforming reveal are the next visual step toward the final experience.

## What we learned building the MVP

The most important design decision was to make the replay path first-class. It gives the team a reliable end-to-end demo while live camera capture and a production-quality vehicle asset continue to mature.

The second was to treat limitations as data. A partial scan is not a failed scan; it is a result with a next action. That makes the recommendation more trustworthy and gives the user a reason to keep moving around the vehicle.

The third was to keep the recommendation downstream of evidence. A hard-coded answer can make a demo look complete, but it cannot prove that findings, customer context, and agreement terms actually connect. Keeping those joins explicit and testable is the next product integration step.

## What comes next

The next increments are:

- verify continuous live progression on the current iPhone build;
- replace temporary geometry with a cleaned, high-quality Toyota-like asset;
- attach an evidence-backed finding to a real surface anchor;
- connect scan findings to synthetic customer, vehicle, and loan/lease scenarios; and
- rehearse the complete flow: **Start Scan → guided coverage → vehicle reveal → finding → personalized next move**.

Toyota Next Move is a prototype, not a remote diagnostic system. It is a practical way to show how careful capture, explicit uncertainty, and responsible AI can turn a vehicle walkaround into a decision a customer can understand.

## Demo notes

For a repeatable demo, use the deterministic replay path. It intentionally includes covered, partial, and unseen regions so the vehicle map and recommendation show the complete uncertainty model. The current model-backed perception bridge is a private development integration; configure its backend secrets server-side and never ship an OpenAI API key in the iOS app.

### Short social copy

We built Toyota Next Move for HackTX 2026: an iPhone experience that guides a vehicle walkaround, makes coverage and uncertainty visible, turns evidence into surface-level findings, and connects those findings to one clear personalized next action. The demo is deterministic, the boundaries are explicit, and the recommendation stays grounded in what the camera actually saw.
