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

  {
    "sindrets/diffview.nvim",
    -- Command-gated, not event-gated: this is a deliberate review action,
    -- never something a normal edit/save/buffer-open should pay to load.
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
    },
    -- The telescope git_status picker above is a one-shot snapshot — that's
    -- exactly why the <C-g> reload override exists on it: telescope has no
    -- native way to notice the index changed under it. diffview solves the
    -- same "review my changes" problem differently: a live file panel plus
    -- a real diff view that tracks the working tree/index as you stage and
    -- edit, and a proper 3-way merge-conflict view telescope has no
    -- equivalent for. herdr-reviewr covers the standalone-pane review case
    -- (reviewing from outside, e.g. a fleet worker's branch); this covers
    -- the "I'm already inside nvim on this repo" case. Keep the telescope
    -- override above — it's still the right tool for jumping straight to a
    -- changed file by name, diffview is for sitting inside the diff.
    opts = {
      -- Diffs are unreadable without hunk-level highlighting once more than
      -- one file is open at once; enhanced_diff_hl trades a bit of extra
      -- highlight work for that. Everything else (keymaps, layout) is left
      -- at diffview's defaults — the mappings.lua entries below reach the
      -- commands NvChad's whichkey can't discover for a lazy-loaded plugin
      -- anyway, and past that, diffview's own in-buffer keymaps (its :h
      -- diffview-config-keymaps defaults) are already sane and don't
      -- collide with anything bound elsewhere in this config.
      enhanced_diff_hl = true,
    },
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
