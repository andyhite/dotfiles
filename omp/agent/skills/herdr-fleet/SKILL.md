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

Claims a handle for this pane, defaulting to the repo root's name — `dotfiles`
in `~/Code/andyhite/dotfiles`. Workers address their questions to it, so nothing
can be dispatched until it exists. On a pane that already has a handle, a bare
`fleet boss` is a query rather than a claim: it prints the existing one and
changes nothing.

Nothing limits how many orchestrators exist; each just needs a handle no live
agent is using. The repo-root default is only a default — it stops one checkout
from monopolizing a shared name, and `fleet boss <name>` in the same checkout is
a second, equally valid orchestrator. Two unrelated checkouts with the same
directory name derive the same default, and the second one has to name itself.
Claiming a taken handle fails and names the pane holding it:

```bash
fleet boss fleetlead        # any [a-z][a-z0-9_-]{0,31} name
fleet boss dotfiles --steal # take it over; the holder is renamed aside, not unnamed
```

Claim the handle **before** spawning. Whichever handle this pane holds at spawn
time is stamped into each worker, and that is where its `fleet reply` goes.
Renaming an orchestrator afterwards is safe — `fleet boss <newname>` repoints
every worker that reported to the old handle, and `--steal` does the same for
the fleet of whoever it displaces.

## Dispatching

One worker per branch. `spawn` creates the worktree, starts an omp in the
workspace's own pane under a handle derived from the branch, builds the selected
layout, and submits the task. It needs no layout plugin: `herdr worktree create`
returns the root pane, and `herdr agent start` names the agent and blocks until
herdr has it ready. A repo covered by an enabled workspace-manager is rejected
before the branch or worktree exists; fleet never adopts or races it.

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
creates the worktree and starts its agent without assigning work.

`--layout agent` (the default) is the worker shape: one `agent` tab, one `omp`
pane. `--layout full` is for a worktree a human will also occupy:

```text
agent tab:  omp | nvim
shell tab:  zsh
review tab: lazygit (or a shell when lazygit is unavailable)
```

Fleet creates that shape from `herdr tab`/`pane` commands directly. It does not
need workspace-manager, and it refuses to race or silently depend on one: if
the enabled plugin config covers the repo, spawn stops before creating a branch
or worktree and names the config entry to remove (or disable the plugin). Once
the repo is no longer covered, the same command takes direct ownership.
`$FLEET_EDITOR` and `$FLEET_GIT_UI` override `nvim` and `lazygit`.

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

A report is overwritten only by its own worker, so a follow-up `fleet send`
leaves the previous one intact. `join` dates it instead of trusting it: a report
older than the most recent dispatch prints under `(nothing reported since the
last dispatch)` rather than being mistaken for an answer to it.

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
fleet reap --all          # remove this repo's worktrees
```

`reap` refuses a worktree with uncommitted changes. That refusal is the point —
read the diff before reaching for `--force`. It removes the worktree, never the
branch; the commits are the deliverable.

Worker state is machine-global, so `ls`, a bare `join`, and `reap --all` are
scoped to the current repo — otherwise they would block on, and delete, another
checkout's fleet. `--all-repos` widens `ls` and `reap` deliberately. Outside a
git repo there is nothing to scope to, and they refuse rather than guess.

## What this is not for

- Anything that fits in one repo checkout. Use `task` subagents; they are
  faster, cheaper, and you can talk to them with `hub`.
- Read-only investigation. Use a `scout` subagent.
- Work with a strict serial dependency chain. A fleet's value is concurrency; a
  chain of one-at-a-time `fleet ask` calls is a slow, expensive `task` loop.
