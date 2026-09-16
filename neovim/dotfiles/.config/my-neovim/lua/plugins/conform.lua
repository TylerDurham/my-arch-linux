-- https://github.com/stevearc/conform.nvim
return {
  'stevearc/conform.nvim',
  event = 'BufWritePre',
  opts = {
    formatters_by_ft = {
      css = { 'prettier' },
      go = { 'gofumpt', 'goimports' },
      html = { 'prettier' },
      javascript = { 'prettier' },
      lua = { 'stylua' },
      nix = { 'nixfmt' },
      sh = { 'shfmt' },
      templ = { 'templ' },
      typescript = { 'prettier' },
      yaml = { 'yamlfix' },
    },
  },
}
