require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- Loaded last: `require "nvchad.mappings"` above installs NvChad's
-- normal-mode <C-h/j/k/l> -> <C-w>h/j/k/l window mappings; herdr-nav must
-- load after so it replaces them (it's a no-op outside a herdr pane)
-- rather than being replaced by them.
require "herdr-nav"