-- Per-Space show/hide toggle for Ghostty, replacing Ghostty's own
-- `keybind = global:ctrl+enter=toggle_visibility` (removed from
-- config/ghostty/config). Ghostty's built-in toggle is app-wide
-- (NSApp unhide/activate): with one Ghostty window per macOS Space, it
-- always jumps to whichever window was most recently focused instead of
-- showing/hiding the window on the *current* Space — see
-- https://github.com/ghostty-org/ghostty/discussions/11084. Hammerspoon can
-- see which Space it's running on, so it can toggle correctly; Ghostty
-- itself has no such API.

-- `hs.window.filter.new({"Ghostty"})` (the shorthand app-list constructor)
-- only matches *visible* windows of that app, silently dropping a minimized
-- one — the toggle would then think there's no window on this Space and
-- spawn a duplicate instead of restoring it. Building the filter from an
-- empty base and adding Ghostty explicitly is the only way to set
-- `currentSpace = true` while leaving `visible` unset, which is what pulls
-- in minimized/hidden windows too (minimize/hide are Space-agnostic in
-- macOS, so they don't belong to "current" or "other" Spaces at all).
local ghosttyFilter = hs.window.filter.new(false):setAppFilter("Ghostty", {
  currentSpace = true,
})

local function toggleGhostty()
  -- Sorted focused-last-first by default, so [1] is the window on this
  -- Space most recently in front — the natural one to act on when more
  -- than one Ghostty window lives on the same Space.
  local win = ghosttyFilter:getWindows()[1]

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
  elseif win == hs.window.focusedWindow() then
    -- app:hide() is Cmd+H's own mechanism: instant, no genie animation, no
    -- Dock/Mission Control thumbnail — unlike win:minimize(), which is a
    -- per-window action Hammerspoon has to fake and looks/feels different
    -- from every other app's hide. This is the one piece of Ghostty's
    -- original built-in toggle that was never broken (hide is inherently
    -- app-wide on macOS, so per-Space filtering has nothing to fix here) —
    -- only *which* window it showed on the way back was wrong.
    win:application():hide()
  else
    win:focus()
  end
end

hs.hotkey.bind({ "ctrl" }, "return", toggleGhostty)
