require("nvchad.configs.lspconfig").defaults()

local servers = {
  -- web
  "html",
  "cssls",
  "ts_ls", -- typescript / javascript / bun
  "eslint", -- flat-config eslint in most repos
  -- oxlint is workspace_required with .oxlintrc.json root markers, so it
  -- only starts in circuit/frontend, where those 18 configs live.
  "oxlint",
  "tailwindcss", -- plotroom uses prettier-plugin-tailwindcss

  -- languages
  -- basedpyright over pyright: verified it honours [tool.pyright] -- which
  -- culora, training and photo-culling set -- as well as [tool.basedpyright]
  -- which circuit sets and runs in pre-commit. One server covers both.
  "basedpyright", -- python types
  "ruff", -- python lint / format, gated below
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

-- Only start ruff where the project opts in. culora, training,
-- photo-culling and comfyui-andypack all declare [tool.ruff]; circuit lints
-- with pylint and formats with black + isort, so running ruff there would
-- duplicate pylint's findings under a different rule set.
vim.lsp.config("ruff", {
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    if fname == "" then
      return
    end

    local toml = vim.fs.find({ "ruff.toml", ".ruff.toml" }, { path = fname, upward = true })[1]
    if toml then
      return on_dir(vim.fs.dirname(toml))
    end

    local pyproject = vim.fs.find("pyproject.toml", { path = fname, upward = true })[1]
    if pyproject then
      for line in io.lines(pyproject) do
        if line:match "^%[tool%.ruff" then
          return on_dir(vim.fs.dirname(pyproject))
        end
      end
    end
  end,
})

vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
