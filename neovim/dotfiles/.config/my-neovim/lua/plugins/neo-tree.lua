-- https://github.com/nvim-neo-tree/neo-tree.nvim
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
        local map = vim.keymap.set  -- local to avoid polluting global scope

        require("neo-tree").setup({
            buffers = {
              follow_current_file = { enabled = true },
            },
            enable_git_status = true,
            default_component_configs = {
              git_status = {
                symbols = {
                  added     = "󰐕",
                  modified  = "󰏫",
                  deleted   = "󰆴",
                  renamed   = "󰁕",
                  untracked = "󰋗",
                  ignored   = "󰟢",
                  unstaged  = "󱅩",
                  staged    = "󱗖",
                  conflict  = "󰞇",
                }
              }
            },
            filesystem = {
              filtered_items = {
                  hide_dotfiles = false,
                  hide_gitignored=true,
                  hide_by_name = {
                    ".git",
                    "node_modules",
                  }
              }
          }
        })

        map("n", "<leader>ee", "<cmd>Neotree toggle reveal<cr>", { desc = "Toggle Neotree" })
        map("n", "<leader>ef", "<cmd>Neotree focus reveal<cr>", { desc = "Focus Neotree" })
        map("n", "<leader>er", "<cmd>Neotree reveal<cr>", { desc = "Reveal file" })
        map("n", "<leader>eg", "<cmd>Neotree float git_status<cr>", { desc = "Git status" })

      end,
  },
}
