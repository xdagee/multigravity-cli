---
name: repo-platform-migration
description: Migrate an existing repository from one platform or runtime to another while preserving core behavior and finishing the job with native packaging, documentation, and verification. Use when adapting a codebase across environments such as macOS to Windows, Bash to PowerShell, Linux service scripts to containers, or any similar platform rewrite where existing structure must be inspected first and runtime issues must be debugged to completion.
---

# Repo Platform Migration

## Overview

Inspect the current repository before proposing changes. Infer the real entrypoints, packaging paths, validation commands, and platform assumptions from the codebase, then replace the platform-specific pieces with target-native implementations.

Finish with runnable verification, not just code edits. If the first implementation fails at runtime, debug the failure, patch it, and rerun the narrowest command that proves the fix.

## Workflow

1. Inspect the repo.
Read the existing launcher, installer, docs, packaging files, and recent commit subjects. Do not assume the project layout.

2. Define the migration boundary.
Identify what must remain behaviorally compatible, what must become target-native, and what legacy files should be removed or replaced.

3. Implement the target-native entrypoints.
Replace launchers, installers, shortcuts, environment handling, config storage, and packaging with conventions that fit the destination platform.

4. Update operational documentation.
Rewrite README, contributor guidance, install steps, and testing notes so they match the new runtime rather than the old one.

5. Verify with the smallest useful commands.
Prefer parser checks, `help`, diagnostics, installer dry runs, and one end-to-end flow such as create/list/delete or start/switch/stop.

6. Debug real failures.
If verification fails, inspect the exact failing code path, patch the narrow cause, and rerun the specific command that should now pass.

## Guardrails

- Preserve user-visible behavior unless the target platform requires a clear change.
- Prefer native platform capabilities over compatibility shims when the rewrite is substantive.
- Keep destructive actions narrow and explicit, especially during cleanup and profile deletion flows.
- Treat runtime validation as required output, not optional polish.

## Typical Triggers

- "Port this macOS CLI to Windows."
- "Rewrite this shell-based launcher for PowerShell."
- "Adapt this repo for Linux containers."
- "Make this existing tool install and run natively on Windows 11."
- "Migrate the packaging, docs, and validation flow to a new platform."

## Deliverables

- Updated runtime entrypoints
- Target-platform installation or packaging artifacts
- Updated documentation
- A concrete verification summary with any remaining gaps
