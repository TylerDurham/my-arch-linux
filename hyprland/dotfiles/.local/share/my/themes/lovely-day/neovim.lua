return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#01070a",
        dark_bg    = "#010508",
        darker_bg  = "#010405",
        lighter_bg = "#1a2023",

        fg         = "#9F9F84",
        dark_fg    = "#777763",
        light_fg   = "#adad96",
        bright_fg  = "#b7b7a3",
        muted      = "#636a6d",

        red        = "#a96d2f",
        yellow     = "#87804e",
        orange     = "#b6834e",
        green      = "#5d7f63",
        cyan       = "#368B8D",
        blue       = "#2895A3",
        purple     = "#966f4c",
        brown      = "#6d4f2f",

        bright_red    = "#d4903d",
        bright_yellow = "#aca663",
        bright_green  = "#7da580",
        bright_cyan   = "#54b2b4",
        bright_blue   = "#48bcce",
        bright_purple = "#be9364",

        accent               = "#2895A3",
        cursor               = "#9F9F84",
        foreground           = "#9F9F84",
        background           = "#01070a",
        selection             = "#1a2023",
        selection_foreground = "#9F9F84",
        selection_background = "#1a2023",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
