-- credits to original theme for existing https://github.com/primer/github-vscode-theme
-- This exists because base46's bundled `github_dark` theme is the *legacy* GitHub Dark
-- palette (bg #24292E), not GitHub Dark Default (bg #0d1117) -- the theme this repo
-- standardizes on everywhere else (Ghostty, hunk, omp). base46 resolves a theme name by
-- trying `base46.themes.<name>` first and falling back to `themes.<name>` (see
-- ~/.local/share/nvim/lazy/base46/lua/base46/init.lua lines 49-50), so this file at
-- `lua/themes/github_dark_default.lua` is picked up as a first-class user theme without
-- needing to patch base46 itself.
--
-- Chrome hex comes from Ghostty's bundled "GitHub Dark Default" theme resource, so nvim's
-- backgrounds and UI accents match the terminal underneath byte-for-byte. Two named
-- background intermediates (darker_black, one_bg) are introduced to keep the surface
-- ladder monotonic -- base46 needs more background steps than the terminal palette
-- defines, and a non-monotonic ladder makes floats indistinguishable from the buffer.
--
-- The SYNTAX half (base_16's base08-base0F, plus `orange` below) is deliberately NOT
-- sourced from that 16-color ANSI palette. Primer's editor theme colors code with four
-- hues the ANSI-16 row simply cannot express -- #8b949e comment, #a5d6ff string,
-- #ffa657 variable, #7ee787 tag -- so mapping syntax onto ANSI slots is what makes a
-- "GitHub" theme stop looking like GitHub: keywords land on the variable color, strings
-- go the wrong blue. These values are lifted from primer/github-vscode-theme's own
-- tokenColors for github-dark-default (via shikijs/textmate-grammars-themes), which is
-- the same source hunk's Shiki theme id and Zed's extension both render from.

local M = {}

M.base_30 = {
	white = "#e6edf3",
	darker_black = "#010409", -- intermediate: darker than the terminal bg, for insets/floats
	black = "#0d1117", --  nvim bg (exact match: canonical page background)
	black2 = "#161b22", -- exact match: canonical raised-panel background
	one_bg = "#1c2128", -- intermediate: between raised-panel and the next surface step
	one_bg2 = "#21262d", -- StatusBar (filename) -- exact match: canonical "one step further"
	one_bg3 = "#21262d", -- reuse of one_bg2: canonical palette has no lighter bg tier above it
	grey = "#6e7681", -- Line numbers -- exact match: Primer editorLineNumber.foreground
	-- base46 sources the `Comment` highlight from grey_fg, NOT from base_16's base03,
	-- so Primer's #8b949e comment color has to be set here or comments render too dim.
	grey_fg = "#8b949e", -- exact match: Primer syntax `comment`
	grey_fg2 = "#6e7681", -- dimmer secondary UI text (tree/telescope), not code comments
	light_grey = "#b1bac4", -- exact match: canonical muted foreground
	red = "#ff7b72", -- StatusBar (username) -- exact match: ANSI 1 (normal red)
	baby_pink = "#ffa198", -- exact match: ANSI 9 (bright red)
	pink = "#d2a8ff", -- approximation: canonical palette has no pink, reuses bright purple
	line = "#21262d", -- for lines like vertsplit -- exact match: raised-panel tier
	green = "#3fb950", -- StatusBar (file percentage) -- exact match: ANSI 2 (normal green)
	vibrant_green = "#56d364", -- exact match: ANSI 10 (bright green)
	nord_blue = "#58a6ff", -- Mode indicator -- exact match: canonical accent (ANSI 4)
	blue = "#79c0ff", -- exact match: ANSI 12 (bright blue)
	yellow = "#d29922", -- exact match: ANSI 3 (normal yellow/warning)
	sun = "#e3b341", -- exact match: ANSI 11 (bright yellow), for small emphasized glyphs
	purple = "#d2a8ff", -- exact match: ANSI 13 (bright purple)
	dark_purple = "#bc8cff", -- exact match: ANSI 5 (normal purple)
	teal = "#39c5cf", -- exact match: ANSI 6 (normal cyan)
	orange = "#ffa657", -- exact match: Primer syntax `variable` / `entity.name`
	cyan = "#56d4dd", -- exact match: ANSI 14 (bright cyan)
	statusline_bg = "#161b22", -- exact match: raised-panel background
	lightbg = "#21262d", -- exact match: canonical "one step further"
	pmenu_bg = "#58a6ff", -- Command bar suggestions -- exact match: canonical accent
	folder_bg = "#58a6ff", -- exact match: canonical accent
}

M.base_16 = {
	base00 = "#0d1117", -- Default bg -- exact match: canonical page background
	base01 = "#161b22", -- Lighter bg (status bar, line number, folding mks)
	base02 = "#21262d", -- Selection bg
	base03 = "#8b949e", -- Comments, invisibles, line hl -- Primer syntax `comment`
	base04 = "#b1bac4", -- Dark fg (status bars) -- exact match: canonical muted foreground
	base05 = "#e6edf3", -- Default fg (caret, delimiters, Operators) -- exact match
	base06 = "#e6edf3", -- Light fg (not often used)
	base07 = "#ffffff", -- Light bg (not often used) -- exact match: ANSI 15
	base08 = "#ffa657", -- Variables, XML Tags, Markup Lists -- Primer `variable`
	base09 = "#79c0ff", -- Integers, Boolean, Constants -- Primer `constant`
	base0A = "#7ee787", -- Classes, Markup Bold -- Primer `entity.name.tag`
	base0B = "#a5d6ff", -- Strings, Markup Code, Diff Inserted -- Primer `string`
	base0C = "#79c0ff", -- Support, regex, escape chars -- Primer `support`, same blue
	base0D = "#d2a8ff", -- Function, methods, headings -- Primer `entity.name.function`
	base0E = "#ff7b72", -- Keywords -- Primer `keyword` / `storage.type`
	base0F = "#ffa198", -- Deprecated, open/close embedded tags -- Primer `invalid`
}

M.type = "dark"

-- base46's bundled `github_dark` carries five treesitter polish entries. Three are
-- dropped here because they actively fight the palette this file exists to reproduce:
-- `@punctuation.bracket` painted brackets orange, `@string` forced strings to the default
-- foreground (which would override base0B and undo Primer's #a5d6ff strings entirely),
-- and `@constructor` painted constructors bright green. GitHub colors none of those that
-- way. The two kept below are the ones Primer genuinely agrees with: object member keys
-- render at the default foreground (Primer's `meta.object.member` is #e6edf3), and the
-- tag-attribute link is structural rather than a color claim.
M.polish_hl = {
	treesitter = {
		["@variable.member.key"] = { fg = M.base_30.white },
		["@tag.attribute"] = { link = "@function.method" },
	},
}

M = require("base46").override_theme(M, "github_dark_default")

return M
