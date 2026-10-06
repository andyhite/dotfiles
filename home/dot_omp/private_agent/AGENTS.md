# Agent notes

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
