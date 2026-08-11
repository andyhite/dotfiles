require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- diffview.nvim: reviewing a live, changing diff from inside nvim (see the
-- plugin spec comment in plugins/init.lua for why this exists alongside the
-- telescope git_status picker). <leader>g is otherwise only claimed by
-- NvChad's own <leader>gt (telescope git_status), so these sit next to it.
map("n", "<leader>gd", "<cmd>DiffviewOpen<CR>", { desc = "diffview open against index" })
map("n", "<leader>gc", "<cmd>DiffviewClose<CR>", { desc = "diffview close" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", { desc = "diffview file history (current file)" })
map("n", "<leader>gH", "<cmd>DiffviewFileHistory<CR>", { desc = "diffview file history (branch)" })

-- Loaded last: `require "nvchad.mappings"` above installs NvChad's
-- normal-mode <C-h/j/k/l> -> <C-w>h/j/k/l window mappings; herdr-nav must
-- load after so it replaces them (it's a no-op outside a herdr pane)
-- rather than being replaced by them.
require "herdr-nav"