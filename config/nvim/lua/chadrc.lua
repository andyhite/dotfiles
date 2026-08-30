-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	-- gruvbox is NvChad's own bundled base46 theme, but its bg (#282828) is
	-- gruvbox's standard/medium shade, not the Hard variant's #1d2021 every
	-- other tool here runs — NvChad ships no "hard" variant, so this is the
	-- closest available match rather than a byte-exact one, same situation
	-- as github_dark before it.
	theme = "gruvbox",

	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },
}

-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
