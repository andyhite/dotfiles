-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	-- Tracked at lua/themes/github_dark_default.lua, an exact match to Ghostty's
	-- bundled "GitHub Dark Default" theme (bg #0d1117). base46 resolves a theme name
	-- by trying base46.themes.<name> first and falling back to themes.<name>, which
	-- is how this repo's own theme file gets picked up here -- it exists because
	-- base46's bundled github_dark is the legacy GitHub Dark palette (bg #24292E),
	-- not Dark Default.
	theme = "github_dark_default",

	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },
}

-- :MasonInstallAll derives its list from configs/lspconfig.lua, configs/conform.lua
-- and configs/lint.lua through NvChad's lspconfig-name → mason-name table. oxlint
-- is enabled in lspconfig.lua but absent from that table, so it's named here or
-- a fresh machine never gets it.
M.mason = { pkgs = { "oxlint" } }

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
