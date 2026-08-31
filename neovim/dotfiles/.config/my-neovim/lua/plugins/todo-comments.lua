return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  event = "BufReadPost",
  keys = {
    { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO comment" },
    { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev TODO comment" },
    { "<leader>ft", "<cmd>TodoTelescope<cr>",                   desc = "Telescope: find TODOs" },
    { "<leader>xt", "<cmd>Trouble todo toggle<cr>",             desc = "TODOs (Trouble)" },
  },
  opts = {},
}
