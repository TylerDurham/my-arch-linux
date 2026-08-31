return {
  -- "just" is the lspconfig/vim.lsp name (see lspconfig's lsp/just.lua);
  -- "just-lsp" is only the Mason package name, which mason-lspconfig maps to
  -- for us. Using the package name here meant vim.lsp.enable resolved nothing.
  name = "just",
}
