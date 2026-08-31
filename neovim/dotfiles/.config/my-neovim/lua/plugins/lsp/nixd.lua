return {
  name = "nixd",
  -- nixd is not a Mason package; install via nix: nix-env -iA nixpkgs.nixd
  -- Hence opt out of lsp.mason.lua's install-by-default, or Mason would try to
  -- fetch a package that isn't in its registry.
  ensure_installed = false,
  config = {
    settings = {
      nixd = {
        nixpkgs = {
          expr = "import <nixpkgs> {}",
        },
        formatting = {
          command = { "nixfmt" },
        },
      },
    },
  },
}
