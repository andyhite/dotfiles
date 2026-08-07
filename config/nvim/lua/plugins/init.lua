return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = "User FilePost",
    config = function()
      require "configs.lint"
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = function()
      local conf = require "nvchad.configs.telescope"

      -- builtin.git_status builds its list with finders.new_oneshot_job, so
      -- it runs git once at open and never notices later edits. The only
      -- built-in refresh is bolted onto git_staging_toggle, which means you
      -- can't reload without touching the index.
      --
      -- Reopen rather than picker:refresh(): the finder builder is a local
      -- closure in telescope, so reusing it means duplicating its cwd and
      -- git_command handling, which would rot on upgrade. default_text keeps
      -- whatever was typed.
      local function reload(prompt_bufnr)
        local prompt = require("telescope.actions.state").get_current_line()
        require("telescope.actions").close(prompt_bufnr)
        require("telescope.builtin").git_status { default_text = prompt }
      end

      -- <C-g>, not <C-r>: that's the prefix for <C-r><C-w> / <C-r><C-a> /
      -- <C-r><C-f>, which insert the cword / cWORD / cfile.
      conf.pickers = vim.tbl_deep_extend("force", conf.pickers or {}, {
        git_status = {
          mappings = { i = { ["<C-g>"] = reload }, n = { ["<C-g>"] = reload } },
        },
      })

      return conf
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
