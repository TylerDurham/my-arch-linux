return {
  "goolord/alpha-nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")
    local opts = require("config.settings")
    local colorscheme = require("config.colorscheme").current()
    
    -- ASCII art header
    dashboard.section.header.val = vim.split(opts.alpha.header, "\n", { trimempty = true })

    -- Buttons
    dashboard.section.buttons.val = {
      dashboard.button("c", "  New file",        "<cmd>ene<CR>"),
      dashboard.button("f", "  Find file",       "<cmd>Telescope find_files<CR>"),
      dashboard.button("g", "  Find text",       "<cmd>Telescope live_grep<CR>"),
      dashboard.button("n", "  Config",          "<cmd>e $MYVIMRC<CR>"),
      dashboard.button("r", "  Recent files",    "<cmd>Telescope oldfiles<CR>"),
      dashboard.button("t", "  Change theme (current: " .. colorscheme .. ")",    "<cmd>ThemeSelect<CR>"),
      dashboard.button("q", "  Quit",            "<cmd>qa<CR>"),
    }

    -- Footer (e.g. plugin count)
    local stats = require("lazy").stats()
    dashboard.section.footer.val = "⚡ " .. stats.count .. " plugins loaded"

    alpha.setup(dashboard.opts)
  end,
}
