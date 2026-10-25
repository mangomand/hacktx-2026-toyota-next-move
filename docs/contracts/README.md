# Canonical contracts

Version: **0.1.0** (2026-10-24). These JSON contracts are the only wire shapes for the vertical slice. Producers may add fields only in a backward-compatible minor revision; consumers must preserve `unknown` and `unseen` states. The coordinator owns this directory.

Region IDs are stable: `front`, `front-left`, `left`, `rear-left`, `rear`, `rear-right`, `right`, `front-right`, `roof`, `interior-front`, `interior-rear`, `trunk`. Exterior coverage is separate from interior coverage. A region is covered only when the capture quality gate passes; absence is never evidence of no damage.

Artifacts referenced by `artifactRefs` are repo-relative local demo files. Images and depth are evidence, not mechanical diagnosis.

See [CONVENTIONS.md](CONVENTIONS.md) for local `$ref` resolution, artifact/evidence joins, unseen timestamps, and the 12-region denominator.
