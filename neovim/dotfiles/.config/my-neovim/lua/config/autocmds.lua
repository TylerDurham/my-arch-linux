
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
  callback = function()
    vim.highlight.on_yank({
      higroup = "CustomYank",
      timeout = 300,
    })
  end,
})


local colors = require("lib.colors")
-- Usage:
local yank = colors.get_color("Keyword", "fg")

vim.api.nvim_set_hl(0, "CustomYank", { bg = yank, fg = "#000000" }) -- Soft banana yellow
