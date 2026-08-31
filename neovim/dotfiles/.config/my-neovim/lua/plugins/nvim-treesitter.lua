-- https://github.com/nvim-treesitter/nvim-treesitter
local ensure_installed = {
  "bash",
  "css",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "html",
  "javascript",
  "lua",
  "markdown",
  "markdown_inline",
  "python",
  "templ",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
}

return {
  'nvim-treesitter/nvim-treesitter',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').setup()

    -- The `main` branch dropped the `ensure_installed` option -- parsers are
    -- installed explicitly instead. Without this nothing is ever installed, and
    -- anything that reads the syntax tree (e.g. nvim-dap-go's "debug nearest
    -- test") fails. Only install what's missing so startup stays fast.
    local ts = require('nvim-treesitter')
    local installed = ts.get_installed()
    local missing = vim.tbl_filter(function(lang)
      return not vim.tbl_contains(installed, lang)
    end, ensure_installed)

    if #missing > 0 then
      ts.install(missing)
    end
  end,
}
