---
name: compact-output
description: Use when the user wants concise coding-agent responses, reduced token usage, compact summaries, or no long explanations.
---

# Compact Output

## Response rules

- Be concise.
- Do not paste full files.
- Do not quote long logs.
- Summarize command output.
- Include only important errors.
- Do not repeat unchanged code.
- Do not explain obvious steps.

## Final response format

Changed:
- file/path: short reason

Tested:
- command: result

Notes:
- important caveats only
