local lint = require "lint"

-- Linters live here rather than in lspconfig.lua because they ship no
-- language server. Mason lists them under the Linter category, and
-- NvChad's :MasonInstallAll reads this table to install them.
--
-- oxlint is deliberately absent: it does have a language server
-- (`oxlint --lsp`), so it's enabled in configs/lspconfig.lua instead, which
-- also gets us :LspOxlintFixAll and a persistent process.
lint.linters_by_ft = {
  -- rafters ships .github/.markdownlint.yaml.
  markdown = { "markdownlint" },

  -- the dotfiles installer plus scripts/ and entrypoint.sh across
  -- comfyui, runpod and image-sieve.
  sh = { "shellcheck" },
  bash = { "shellcheck" },
}

-- nvim-lint never runs on its own -- it only lints when asked.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("NvLint", { clear = true }),
  callback = function()
    require("lint").try_lint()
  end,
})
