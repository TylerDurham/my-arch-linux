return {
  name = "emmet_language_server",
  config = {
    cmd = { 'emmet-language-server', '--stdio' },
    filetypes = {
      'html', 'css', 'scss', 'sass',
      'javascriptreact', 'typescriptreact',
      'vue', 'svelte', 'astro', 'templ',
    },
    init_options = {
      showSuggestionsAsSnippets = true,
    },
    root_markers = { 'package.json', '.git' },
  },
}
