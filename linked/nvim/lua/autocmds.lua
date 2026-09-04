require "nvchad.autocmds"

-- `nvim ~/foo/bar` used to behave like `vim ~/foo/bar`: netrw opened a
-- filetree rooted at that path. Netrw is disabled (see configs/lazy.lua)
-- and nvim-tree only lazy-loads on :NvimTreeToggle/:NvimTreeFocus (see
-- NvChad's plugins/init.lua), so without this, a directory argument opens
-- an empty buffer instead of a filetree at that path.
vim.api.nvim_create_autocmd("VimEnter", {
  desc = "Open nvim-tree rooted at a directory passed on the command line",
  callback = function()
    local arg = vim.fn.argv(0)
    if vim.fn.argc() == 1 and type(arg) == "string" and vim.fn.isdirectory(arg) == 1 then
      vim.cmd.cd(arg)
      require("nvim-tree.api").tree.open()
    end
  end,
})
