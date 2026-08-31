return {
  name = "gopls",
  -- ensure_installed = true,
  config = {
    settings = {
      gopls = {
        analyses = { unusedparams = true, shadow = true },
        staticcheck = true,
        gofumpt = true,
      },
    },
  },
}
