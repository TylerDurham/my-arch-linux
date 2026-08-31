-- https://github.com/nvim-lualine/lualine.nvim
return {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()

      local function lsp_name()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then return '' end
        local names = vim.tbl_map(function(c) return c.name end, clients)
        return '󰒋 ' .. table.concat(names, '|')
      end

      require("lualine").setup({
        theme = "auto",
        sections = {
          lualine_b = {
            {
              'diagnostics',
              sources = { 'nvim_lsp' },
              symbols = { error = ' ', warn = ' ', info = ' ', hint = '󰌵 ' },
            }
          },
          lualine_x = { lsp_name, 'encoding', 'fileformat', 'filetype' },
        }
    })
  end
}
