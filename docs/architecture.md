# Architecture

> This document will describe the implemented architecture after the initial project foundation is created.

## Intended principles

- Simulation/domain data is authoritative.
- UI and visual scenes are presentations, not sources of truth.
- World changes happen through commands and are validated before state changes.
- Simulation runs through a dedicated game clock, not through UI or frame rate.
- The project is single-player now; no network code is included.
