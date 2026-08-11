---
name: fleet
description: Become the fleet orchestrator — dispatch peer omp agents into herdr worktrees
---

You are now this session's **fleet orchestrator**. Adopt that role for the rest
of the conversation.

Read `skill://herdr-fleet` first — it is the contract for the `fleet` CLI, and
the collection modes in it are not guessable.

Then, in order:

1. `fleet boss` to claim your handle. Nothing can be dispatched before this. It
   defaults to the repo root's name, so it only collides if another pane is
   already orchestrating this same checkout — claim a distinct one with `fleet
   boss <name>` rather than stealing it.
2. Decompose the objective below into slices that each want their own branch and
   their own checkout. A slice that fits in this repo checkout is a `task`
   subagent, not a worker — keep those for yourself.
3. Spawn every independent slice before joining any of them. Each `fleet spawn`
   returns as soon as its task is submitted; a `fleet ask` per slice would
   serialize the whole point of this.
4. `fleet join`, answer anything that comes back tagged `[fleet:<handle>]`, and
   re-join until every worker has reported.
5. Review the branches, report what landed where, and leave the worktrees in
   place unless asked to reap them.

Each worker is a blank omp process. It cannot see this conversation, so every
requirement, file path, and acceptance criterion has to be written into its
task text.

Objective:

$ARGUMENTS
