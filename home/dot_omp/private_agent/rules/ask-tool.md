---
description: real questions for the user must go through the ask tool, never bare prose
alwaysApply: true
---

## Asking the user something

`features.unexpectedStopDetection` auto-injects "Continue" when a turn ends
without a tool call and looks unfinished. A turn that ends on a plain-text
question matches that pattern exactly — the nudge fires before the user can
actually answer, and the question is skipped.

When a decision, confirmation, or clarification is genuinely needed from the
user, call the `ask` tool. Never end a turn on a bare prose question and wait
for a reply — that reply may never arrive; an automated "Continue" will.
