---
name: herdr-fleet
description: Orchestrate peer coding agents in herdr git-worktree workspaces using the `fleet` CLI — create a worktree per task, dispatch a separate omp process into each, collect reports, and answer questions the workers send back. Use when acting as an orchestrator dispatching parallel branch work, or when the user says fleet, orchestrator, dispatch, or asks for agents working on separate branches. Not for `task` subagents, which stay inside this process.
---

# Fleet

Dispatch work to omp processes that are not yours.

`task` subagents share this process: one context window, one cwd, one lifetime,
and they die when this session does. A fleet worker is a separate `omp` running
in its own herdr pane, in its own git worktree, on its own branch. It has a full
context window, it can be talked to an hour from now, and its output is a branch
rather than a message.

That independence is also the cost. `hub`, `history://` and `agent://` are all
scoped to a single omp process, so **none of them reach a worker**. Every
message in both directions goes through herdr's agent surface, which `fleet`
wraps.

## Before anything else

```bash
fleet boss
```

Claims the handle `boss` for this pane. Workers address their questions to it,
so nothing can be dispatched until it exists. Idempotent.

## Dispatching

One worker per branch. `spawn` creates the worktree, waits for herdr's
workspace-manager plugin to start an omp in it, renames that agent to a handle
derived from the branch, and submits the task.

```bash
fleet spawn feat/412-webhook-retry \
  --task "Add exponential backoff to the webhook dispatcher. Tests in
tests/webhooks/. Do not change the public dispatch() signature."
```

Write the task the way you would write a `task` assignment: target files,
concrete change, acceptance criteria. The worker has no memory of this
conversation — every requirement must be in the text. `fleet` appends the
protocol block (report, reply, commit, stay-in-worktree) itself, so do not
repeat those instructions.

Long tasks read better from a file:

```bash
fleet spawn fix/301-null-guard --task-file /tmp/task-301.md
```

`--base` overrides the branch point (default: `origin/HEAD`). `--no-dispatch`
creates the worktree and stops, for when you want to inspect it first.

## Collecting

Two modes, and picking the wrong one is the main way this goes badly.

**Fan out, then join.** The real reason to use fleet. Spawn every worker first —
each returns as soon as its task is submitted — then block once:

```bash
fleet spawn feat/a --task "..."
fleet spawn feat/b --task "..."
fleet spawn feat/c --task "..."
fleet join
```

`join` waits for every live worker to settle and prints each report.

**One at a time.** `fleet ask <handle> "<task>"` dispatches and blocks for that
one worker. Use it for a follow-up on an existing worker, or when the second
task genuinely depends on the first one's result. Never use it to start a batch
— it serializes the thing you came here to parallelize.

Reports come from files, not the terminal. omp runs on the alternate screen, so
its output never enters herdr's scrollback and cannot be scraped back;
`fleet read <handle>` shows only the visible viewport and is a debugging aid,
not a way to collect results.

## When a worker interrupts you

A worker that is blocked runs `fleet reply "<question>"`, which arrives here as
a user message tagged `[fleet:<handle>]` — and **preempts whatever tool call you
are in**, including a `fleet join`. That is deliberate: a worker waiting on a
decision should not sit behind another worker's build.

Answer it and resume:

```bash
fleet send <handle> "Use the existing RetryPolicy in core/retry.ts; don't add a new one."
fleet join
```

`join` is safe to re-run — it re-waits on whoever is still working.

If `join` reports a worker as `blocked`, that is herdr seeing an approval or
question UI in the pane, not a `fleet reply`. Read the pane and answer it
directly with `fleet send`.

## Finishing

Workers commit to their own branch and stop. They do not push and do not open
PRs unless the task said to. Review the branches yourself, then:

```bash
fleet ls                  # handles, states, branches, paths
fleet reap <handle>       # remove one worktree
fleet reap --all          # remove every registered worktree
```

`reap` refuses a worktree with uncommitted changes. That refusal is the point —
read the diff before reaching for `--force`.

## What this is not for

- Anything that fits in one repo checkout. Use `task` subagents; they are
  faster, cheaper, and you can talk to them with `hub`.
- Read-only investigation. Use a `scout` subagent.
- Work with a strict serial dependency chain. A fleet's value is concurrency; a
  chain of one-at-a-time `fleet ask` calls is a slow, expensive `task` loop.
