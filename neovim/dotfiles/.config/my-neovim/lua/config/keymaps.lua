-- My preferred mappings
map = vim.keymap.set

-- Quit all
map({"n", "v"}, "<leader>qq", "<cmd>quitall<cr>", { desc = "Close all files and quit" })
map({"n", "v"}, "<leader>qb", "<cmd>BufferCloseAllButCurrent<cr>", { desc = "Close all buffers but the current" })
map({"n", "v"}, "<leader>qr", "<cmd>BufferCloseBuffersRight<cr>", { desc = "Close all buffers to the right of the current" })
map({"n", "v"}, "<leader>ql", "<cmd>BufferCloseBuffersLeft<cr>", { desc = "Close all buffers to the left of the current" })

-- Escape
map("i", "jj", "<ESC>", { desc="Escape from mode 'INSERT'" })

-- Keep cursor in place when yanking in visual mode
map("v", "y", "ygv<Esc>", { desc = "Yank and keep cursor" })

-- Paste without overwriting the unnamed register (VERY useful)
-- When you yank something, then visually select and paste over text,
-- the yanked text gets replaced by what you just deleted. This fixes that:
map("v", "p", '"_dP', { desc = "Paste without yanking selection" })

-- Yank to system clipboard explicitly (even without unnamedplus)
map({"n", "v"}, "<leader>y", '"+y', { desc = "Yank to system clipboard" })
map("n", "<leader>Y", '"+Y',        { desc = "Yank line to system clipboard" })

-- Delete without yanking (black hole register)
map({"n", "v"}, "<leader>d", '"_d', { desc = "Delete without yanking" })

-- Paste from system clipboard explicitly
map({"n", "v"}, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
map({"n", "v"}, "<leader>P", '"+P', { desc = "Paste before from system clipboard" })

-- Line numbers
-- Toggle between number modes:
-- 1. relative + absolute (hybrid) -- normal editing
-- 2. absolute only               -- good for copying with mouse
-- 3. no numbers                  -- clean/distraction free

local function toggle_line_numbers()
    if vim.opt.relativenumber:get() then
        vim.opt.relativenumber = false
    elseif vim.opt.number:get() then
        vim.opt.number = false
    else
        vim.opt.number = true
        vim.opt.relativenumber = true
    end
end

-- Format current buffer
map("n", "<leader>fm", function() require("conform").format({ lsp_format = "fallback" }) end, { desc = "Format buffer" })

-- utility for current file
map("n", "<leader>ga", "<cmd>! git add %<cr>", { desc = "Git add current file"})
map("n", "<leader>X", "<cmd>! chmod +x %<cr>", { desc = "Make current file executable"})
map("n", "<leader>tn", toggle_line_numbers, { desc = "Toggle Line Numbers" })

