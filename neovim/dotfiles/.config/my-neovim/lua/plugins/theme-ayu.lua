return {
  "Shatur/neovim-ayu",
  config = function()
    require('ayu').setup({
      -- Options
      mirage = false,  -- Use mirage variant for dark background
      terminal = true, -- Sync terminal colors
      overrides = {}   -- Custom highlight groups
    })
  end
}
