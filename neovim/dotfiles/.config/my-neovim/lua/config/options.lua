-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.mapleader = " "       -- Space as leader (most popular choice)
vim.g.maplocalleader = " "  -- Space as local leader

local opt = vim.opt

-- Line numbers
opt.number = true          -- Show absolute line numbers
opt.relativenumber = true  -- Show relative line numbers (great for motions)

-- Indentation
opt.tabstop = 2            -- Number of spaces a tab counts for
opt.shiftwidth = 2         -- Spaces used for each step of (auto)indent
opt.expandtab = true       -- Convert tabs to spaces
opt.autoindent = true      -- Copy indent from current line when starting a new one
opt.smartindent = true     -- Smarter autoindenting (e.g. after { in C-like files)

-- Wrapping
opt.wrap = false           -- Disable line wrapping (keeps code clean)

-- Clipboard
vim.opt.clipboard = "unnamedplus"  -- use system clipboard for all operations

-- Apperance
opt.termguicolors = true   -- Enable 24-bit RGB colors in the terminal
opt.cursorline = true      -- Highlight the line the cursor is on
opt.signcolumn = "yes"     -- Always show the sign column (prevents layout shifts)
opt.colorcolumn = "100"     -- Visual ruler at column 80
opt.scrolloff = 8          -- Keep 8 lines visible above/below cursor
opt.sidescrolloff = 8      -- Keep 8 columns visible left/right of cursor
opt.showmode = false       -- Don't show -- INSERT -- (use a statusline plugin instead)
opt.swapfile = false

vim.api.nvim_create_user_command("LspRestart", function()
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    c.stop()
  end
  vim.cmd("edit")
end, {})
