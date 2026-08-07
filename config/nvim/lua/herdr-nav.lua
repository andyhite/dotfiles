-- herdr-nav.lua — Neovim half of the vim-herdr-navigation herdr plugin,
-- vendored here rather than `require`d straight from herdr's plugin install
-- dir: that path is content-hashed and changes on every plugin update,
-- which would silently break the require at the next herdr upgrade.
--
-- Ported from vim-herdr-navigation's editor/nvim.lua. Behaviour preserved
-- exactly except:
--   - the upstream $TMUX / vim-tmux-navigator fallback branch is dropped:
--     christoomey/vim-tmux-navigator isn't installed in this config
--     (absent from lazy-lock.json and plugins/init.lua), so that branch
--     is dead code here.
--   - guarded to only install mappings inside a herdr pane, so outside
--     herdr NvChad's own <C-w>h/j/k/l mappings are left untouched.

if not vim.env.HERDR_PANE_ID or vim.env.HERDR_PANE_ID == "" then
  return
end

local herdr_bin = vim.env.HERDR_BIN_PATH
if herdr_bin == nil or herdr_bin == "" then
  herdr_bin = "herdr"
end

-- Non-blocking: vim.fn.system() (what upstream uses) blocks the whole
-- editor on every edge-hit keypress while herdr's process spawns and
-- exits. vim.system (0.10+) is async by default; jobstart is the
-- pre-0.10 fallback for older Neovim.
local function run_async(cmd)
  if vim.system then
    vim.system(cmd)
  else
    vim.fn.jobstart(cmd)
  end
end

local function nav(wincmd, dir)
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd)
  if vim.api.nvim_get_current_win() ~= prev then
    return -- moved within Neovim
  end
  -- At a split edge: hand off to herdr. --pane is load-bearing — without
  -- it herdr resolves the server's globally focused pane, which is not
  -- necessarily the one this Neovim instance is running in.
  run_async { herdr_bin, "pane", "focus", "--direction", dir, "--pane", vim.env.HERDR_PANE_ID }
end

local function map(lhs, wincmd, dir, desc)
  vim.keymap.set("n", lhs, function()
    nav(wincmd, dir)
  end, { silent = true, noremap = true, desc = desc })
end

map("<C-h>", "h", "left", "Navigate left (vim/herdr)")
map("<C-j>", "j", "down", "Navigate down (vim/herdr)")
map("<C-k>", "k", "up", "Navigate up (vim/herdr)")
map("<C-l>", "l", "right", "Navigate right (vim/herdr)")
