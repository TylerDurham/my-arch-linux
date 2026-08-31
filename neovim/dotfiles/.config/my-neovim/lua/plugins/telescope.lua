-- https://github.com/nvim-telescope/telescope.nvim
return {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require "telescope.actions"

      local map = vim.keymap.set
      local ts = require("telescope.builtin")

      map({"n", "v"}, "<leader>fw", "<cmd>Telescope live_grep<cr>", { desc = "Telescope: live grep"})
      map({"n", "v"}, "<leader>ff", function()
        ts.find_files({ hidden = true })
      end,
      { desc = "Telescope: find all files" })
      map({"n", "v"}, "<leader>fn", function()
        ts.find_files({ cwd = "~/.config/nvim", hidden = true })
      end,
      { desc = "Telescope: find NeoVim config files" })
      map({"n", "v"}, "<leader>fa", "<cmd>Telescope find_files<CR>", { desc = "Telescope: find files"})
      map({"n", "v"}, "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Telescope: find keymaps"})

      -- Custom theme selector
      map({"n", "v"}, "<leader>th",
      function()
        local cs = require("config.colorscheme").select()
      end, 
      { desc = "Telescope: select theme" })

      opts.defaults = vim.tbl_deep_extend("force", opts.defaults or {}, {
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
          "--hidden",
          "--glob",
          "!.git/*",
        },
        mappings = {
          i = {
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-u>"] = actions.preview_scrolling_up,
            ["<C-d>"] = actions.preview_scrolling_down,
          },
          n = {
            ["k"] = actions.move_selection_previous,
            ["j"] = actions.move_selection_next,
            ["gg"] = actions.move_to_top,
            ["G"] = actions.move_to_bottom,
            ["<C-u>"] = actions.preview_scrolling_up,
            ["<C-d>"] = actions.preview_scrolling_down,
            ["q"] = actions.close,
          },
        },
      })
    end,
  }
