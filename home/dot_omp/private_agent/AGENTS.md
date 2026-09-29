# Agent notes

Global context for every omp session, and — via `~/.claude/CLAUDE.md`, which
is a symlink to this file — Claude Code's global user memory too. One source
of truth, since the two files needed identical content.

`~/.omp/agent/rules/output-style.md` carries the same guidance below as its
own always-apply *rule* — a different loading mechanism, native to omp's rule
engine, that can't just symlink here (it needs its own YAML frontmatter). Keep
the two in sync by hand if this changes.

## Output style

The reader has ADHD. Shape every response so it can be acted on:

1. Lead with the answer or next action: command, path, or snippet first.
2. Number multi-step work; one bounded action per step.
3. End with one next action doable in under two minutes.
4. Finish the current issue before raising a new one.
5. Restate progress each turn ("step 3 of 5 done").
6. Give time estimates in concrete units, never "a bit".
7. After a change, show what now works.
8. Errors: state location, cause, and fix. No drama.
9. Cap lists at 5 items.
10. No preamble, no recaps, no closers.

Exceptions: explain fully when asked to explain. Confirm before destructive
actions. After three failed fixes, stop and name the doubtful assumption. If
the request is ambiguous, ask one short question.

## Chrome for Testing

For browser automation, MUST attach to the user-started Chrome for Testing at
`http://127.0.0.1:9222` via `browser.open` with `app.cdp_url` set to that address.
NEVER substitute the default managed browser or the relay to the user's regular Chrome.

Check `http://127.0.0.1:9222/json/version` before attaching. If it is not
reachable, MUST prompt the user to start `cft` (headed) or `cft headless` and
wait for them; NEVER start it yourself. These commands share the user's
`~/.cache/cft-profile`, including authenticated sessions. Treat it as a real
user session: only perform actions the user authorized, and close only tabs
you opened; NEVER terminate the Chrome process.

If a site shows a login form or redirects to login, MUST pause and ask the
user to log in using headed `cft`; NEVER enter credentials, bypass login, or
create an auth session yourself. If `cft headless` is running, tell the user
to stop it first, then run `cft`, log in, stop the headed browser, and restart
`cft headless` before you retry. The two modes cannot run simultaneously with
the same `~/.cache/cft-profile`: Chrome locks that profile, and a second launch
may hand its URL to the first process rather than opening a visible window.
Wait for the user to say the browser is ready before reconnecting.
