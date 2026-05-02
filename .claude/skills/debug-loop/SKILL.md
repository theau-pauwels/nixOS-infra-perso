---
name: debug-loop
description: Use when fixing bugs, failing tests, runtime errors, stack traces, regressions, or broken builds while minimizing unnecessary exploration and token usage.
---

# Debug Loop

## Workflow

1. Reproduce the error with the smallest command.
2. Read only the stack trace and directly related files.
3. Form one hypothesis.
4. Make one small change.
5. Rerun the smallest relevant test.
6. Stop when the test passes.

## Rules

- Do not inspect unrelated modules.
- Do not run the full suite before the local failure is fixed.
- Do not refactor unrelated code.
- Do not change public behavior unless required by the bug.
- Prefer targeted tests before broad validation.

## Final summary

Report only:

- root cause
- changed files
- test command
- result
