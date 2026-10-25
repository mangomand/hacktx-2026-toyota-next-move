# Contract conventions (v0.1.0)

**Schema resolution.** The registry is the filenames in this directory. A `$ref` is resolved relative to the referring schema file (`coverage-region.schema.json`, etc.); `$id` values are documentation identifiers, not network URLs. Validators must load the complete directory as a local registry.

**Evidence joins.** `artifactRefs`, `evidenceRefs`, and `fixtureRefs` use opaque, repo-relative POSIX paths such as `fixtures/demo-scratch/front/frame-001.jpg`. A producer must not embed customer data or URLs. A missing reference is an unavailable artifact, never proof that a finding is false.

**Unseen timestamps.** Every `CoverageRegion` has `observedAt`. For `state: unseen`, set it to the containing session's `startedAt` and omit `artifactRefs`; this records evaluation time, not observation. `blocked` may use the last evaluation time and a human-readable `notes` reason.

**Coverage denominator.** The denominator is the 12 canonical region IDs in `coverage-region.schema.json`. A replay may emit all 12 records, including unseen records. `covered` means quality gate passed; `partial` means some evidence exists but the gate did not pass.

**Uncertainty and diagnosis.** Findings describe visible evidence only. `unknown`, `unseen`, and `not_a_diagnosis` must remain available to consumers. No field implies hidden mechanical state.

**Executable registry.** `registry.json` maps every versioned `$id` to its local schema filename. A validator loads all seven entries before resolving nested `$ref` values. `ScanSession.regions` must contain 12 distinct objects at the array level; each `regionId` must be unique across the canonical set (this final uniqueness-by-property check is a contract-boundary semantic assertion). `Recommendation.escalation` is machine-readable: use `human_review` or `safety_review` when caveats require a person, `more_evidence` when coverage is insufficient, and `none` only when no escalation is needed.

**Executable semantic checks.** Run `python3 docs/contracts/validate_contracts.py` to verify registry consistency. Pass a `ScanSession` JSON path to additionally enforce that all 12 canonical `regionId` values occur exactly once and replay sessions declare `synthetic_replay` mode. This check is required at the M1 contract gate.
