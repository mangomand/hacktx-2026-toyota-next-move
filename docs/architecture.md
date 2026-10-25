# Toyota Next Move architecture

The prototype is a local-first iOS vertical slice. SwiftUI owns the flow and state; a deterministic synthetic replay is a first-class input alongside live capture. Capture emits `ScanSession` and `CoverageRegion` records. Vision/reconstruction consumes evidence references and emits an uncertainty-aware vehicle map plus `Finding` records. Product logic combines findings with synthetic `VehicleProfile` and `Agreement` records to emit exactly one `Recommendation`. The UI always exposes unseen or blocked regions and labels visible findings as non-diagnostic.

Boundaries: iOS owns capture and replay adapters; Vision owns reconstruction and finding extraction; Product/UX owns journey, copy, accessibility and later assigned UI files; QA owns acceptance and responsible-AI checks; the coordinator owns contracts and integration. Shared data crosses boundaries only through `docs/contracts` v0.1.0.
