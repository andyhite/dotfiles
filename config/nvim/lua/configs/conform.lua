--- Python splits two ways across the repos on this machine: culora, training,
--- photo-culling and comfyui-andypack all configure [tool.ruff], while circuit
--- enforces isort + black through .pre-commit-config.yaml. Pick per project so
--- the editor never fights the hook.
---@param bufnr integer
---@return string[]
local function python_formatters(bufnr)
  local fname = vim.api.nvim_buf_get_name(bufnr)

  if fname ~= "" then
    if vim.fs.find({ "ruff.toml", ".ruff.toml" }, { path = fname, upward = true })[1] then
      return { "ruff_organize_imports", "ruff_format" }
    end

    local pyproject = vim.fs.find("pyproject.toml", { path = fname, upward = true })[1]
    if pyproject then
      for line in io.lines(pyproject) do
        if line:match "^%[tool%.ruff" then
          return { "ruff_organize_imports", "ruff_format" }
        end
      end
    end
  end

  return { "isort", "black" }
end

local options = {
  formatters_by_ft = {
    lua = { "stylua" },

    -- conform resolves prettier from the project's own node_modules/.bin, so
    -- each repo's .prettierrc and plugins apply -- including plotroom's
    -- prettier-plugin-tailwindcss, which needs the local install to load.
    javascript = { "prettier" },
    javascriptreact = { "prettier" },
    typescript = { "prettier" },
    typescriptreact = { "prettier" },
    json = { "prettier" },
    jsonc = { "prettier" },
    css = { "prettier" },
    scss = { "prettier" },
    html = { "prettier" },
    yaml = { "prettier" },

    -- prettier only. markdownlint is wired as a linter in configs/lint.lua;
    -- running its --fix here as well would have two tools rewriting the same
    -- buffer on every format.
    markdown = { "prettier" },

    python = python_formatters,

    sh = { "shfmt" },
    bash = { "shfmt" },

    -- Go is deliberately absent: gopls runs gofmt and organises imports
    -- itself, matching circuit's go-fmt / go-imports pre-commit hooks.
  },

  formatters = {
    isort = {
      -- circuit's pre-commit passes --profile black explicitly; its
      -- pyproject [tool.isort] sets line_length and known_first_party but
      -- not the profile, so pass it here to keep editor and hook identical.
      prepend_args = { "--profile", "black" },
    },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
