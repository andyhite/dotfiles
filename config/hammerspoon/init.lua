-- Per-Space show/hide toggle for Ghostty, replacing Ghostty's own
-- `keybind = global:ctrl+enter=toggle_visibility` (removed from
-- config/ghostty/config). Ghostty's built-in toggle is app-wide
-- (NSApp unhide/activate): with one Ghostty window per macOS Space, it
-- always jumps to whichever window was most recently focused instead of
-- showing/hiding the window on the *current* Space — see
-- https://github.com/ghostty-org/ghostty/discussions/11084. Hammerspoon can
-- see which Space it's running on, so it can toggle correctly; Ghostty
-- itself has no such API.

-- Deliberately NOT `hs.window.filter`: it tracks windows via a persistent
-- cache kept up to date by accessibility (AX) event subscriptions, and
-- that cache is documented to fall out of sync with reality — see
-- Hammerspoon issues #2524 ("getWindows() sometimes missing some
-- windows"), #2481, and #3170. Querying live via `hs.window.orderedWindows()`
-- and `hs.application:allWindows()` on every keypress is a few AX calls
-- slower but has no cache to desync — each press starts from a fresh,
-- accurate scan.
local function ghosttyWindowOnCurrentSpace()
  local app = hs.application.get("Ghostty")
  if not app then
    return nil
  end

  -- orderedWindows() is macOS's real front-to-back order, restricted to
  -- whichever Space(s) are currently visible. On a multi-display setup
  -- that's the union across every display's own active Space, so this
  -- still correctly skips a Ghostty window sitting on a Space nobody is
  -- looking at right now, on either display.
  for _, win in ipairs(hs.window.orderedWindows()) do
    if win:application():pid() == app:pid() then
      return win
    end
  end

  -- No visible Ghostty window on this Space: fall back to a hidden or
  -- minimized one. orderedWindows() never reports these — minimize/hide
  -- are Space-agnostic on macOS, so they don't belong to "this Space" or
  -- any other.
  for _, win in ipairs(app:allWindows()) do
    if not win:isVisible() then
      return win
    end
  end

  return nil
end

local function toggleGhostty()
  local win = ghosttyWindowOnCurrentSpace()

  if win == nil then
    -- Nothing on this Space: open a new window without switching Spaces.
    -- Runs through a login shell so it picks up the same PATH `zshrc` sets
    -- up for the interactive shell, rather than hardcoding the app bundle's
    -- Contents/MacOS path here too.
    hs.execute("ghostty +new-window", true)
  elseif not win:isVisible() then
    -- Hidden (via app:hide() below) or minimized (leftover state from
    -- before this used hide) — bring it back and focus it. isVisible()
    -- covers both in one check.
    local app = win:application()
    if app:isHidden() then
      app:unhide()
    end
    if win:isMinimized() then
      win:unminimize()
    end
    win:focus()
  else
    -- Whether Ghostty is really "in front" isn't a question of global
    -- z-order: with multiple displays, each has its own active Space, so
    -- `hs.window.orderedWindows()` ranks another app fullscreened on a
    -- *different* display ahead of Ghostty even though it's nowhere near
    -- it (confirmed live: Linear/Claude fullscreened on the other display
    -- always outranked a focused, on-top Ghostty here). Keyboard focus is
    -- the display/Space-agnostic signal for "is this the window the user
    -- is looking at right now".
    local focused = hs.window.focusedWindow()
    if focused and focused:id() == win:id() then
      -- app:hide() is Cmd+H's own mechanism: instant, no genie animation, no
      -- Dock/Mission Control thumbnail — unlike win:minimize(), which is a
      -- per-window action Hammerspoon has to fake and looks/feels different
      -- from every other app's hide. This is the one piece of Ghostty's
      -- original built-in toggle that was never broken (hide is inherently
      -- app-wide on macOS, so per-Space filtering has nothing to fix here) —
      -- only *which* window it showed on the way back was wrong.
      win:application():hide()
    else
      -- Visible but not focused — bring it forward instead of hiding, so
      -- the toggle never buries the window the user is looking at.
      win:focus()
    end
  end
end

hs.hotkey.bind({ "ctrl" }, "return", toggleGhostty)
