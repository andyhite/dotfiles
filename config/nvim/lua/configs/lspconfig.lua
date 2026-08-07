require("nvchad.configs.lspconfig").defaults()

local servers = {
  -- web
  "html",
  "cssls",
  "ts_ls", -- typescript / javascript / bun
  "eslint", -- monorepo lint + code actions

  -- languages
  "pyright", -- python types
  "ruff", -- python lint / format
  "gopls", -- go
  "rust_analyzer", -- rust

  -- config & data
  "yamlls", -- gh actions, helm values
  "jsonls", -- package.json, tsconfig, turbo.json
  "taplo", -- toml
  "sqls", -- sql migrations
  "dockerls", -- dockerfiles

  -- prose & shell
  "marksman", -- markdown
  "bashls", -- shell scripts
}

vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
