-- https://github.com/stevearc/conform.nvim
return {
  'stevearc/conform.nvim',
  event = 'BufWritePre',
  opts = {
    formatters_by_ft = {
      lua = { 'stylua' },
      go = { 'gofumpt', 'goimports' },
      css = { 'prettier' },
      html = { 'prettier' },
      javascript = { 'prettier' },
      typescript = { 'prettier' },
      templ = { 'templ' },
      sh = { 'shfmt' },
      nix = { 'nixfmt' },
    },
  },
}
