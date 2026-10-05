-- Headless :MasonInstallAll, run by .chezmoiscripts/run_onchange_after_80-nvchad.
-- The interactive command installs asynchronously, so `nvim --headless
-- +MasonInstallAll +qa` quits mid-download with nothing installed. This walks
-- the same package list (NvChad derives it from configs/lspconfig.lua,
-- configs/conform.lua, configs/lint.lua and chadrc's M.mason.pkgs) and blocks
-- until every install reports back. Exit 1 if any failed, so the script's
-- retry-on-next-apply policy applies to this step too.
return function()
  -- All four are lazy-loaded (cmd/event gated) and never load in a headless run.
  require("lazy").load { plugins = { "mason.nvim", "nvim-lspconfig", "conform.nvim", "nvim-lint" } }
  local mr = require "mason-registry"
  mr.refresh()

  local pending, failed = 0, {}
  for _, tool in ipairs(require("nvchad.mason").get_pkgs()) do
    local name = tool:match "^[^@]+"
    local pkg = mr.get_package(name)
    if not pkg:is_installed() then
      pending = pending + 1
      pkg:install({}, function(ok, err)
        if not ok then
          table.insert(failed, name .. ": " .. tostring(err))
        end
        pending = pending - 1
      end)
    end
  end

  -- ponytail: one flat 20-minute ceiling for the whole batch; per-package
  -- timeouts if a single slow download ever masks a hung one.
  vim.wait(20 * 60 * 1000, function()
    return pending == 0
  end, 1000)

  if pending > 0 then
    table.insert(failed, pending .. " install(s) still running at timeout")
  end
  if #failed > 0 then
    io.stderr:write(table.concat(failed, "\n") .. "\n")
    os.exit(1)
  end
end
