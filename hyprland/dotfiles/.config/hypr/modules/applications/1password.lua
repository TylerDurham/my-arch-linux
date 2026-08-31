
hl.window_rule({
  name = "1password",
  match = {
    class = "^(1[p|P]assword)$"
  },
  no_screen_share = true,
  workspace = "10"
})

-- hl.notification.create({ text="1Password window rule set.", timeout=1000 })
