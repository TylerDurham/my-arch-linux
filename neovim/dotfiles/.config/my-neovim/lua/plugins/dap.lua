-- https://github.com/mfussenegger/nvim-dap
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",        -- required by nvim-dap-ui
      "leoluz/nvim-dap-go",
      "theHamsta/nvim-dap-virtual-text",
    },
    keys = {
      { "<F5>",       function() require("dap").continue() end,           desc = "DAP: continue / start" },
      { "<S-F5>",     function() require("dap").terminate() end,          desc = "DAP: terminate session" },
      { "<F9>",       function() require("dap").toggle_breakpoint() end,  desc = "DAP: toggle breakpoint" },
      { "<F10>",      function() require("dap").step_over() end,          desc = "DAP: step over" },
      { "<F11>",      function() require("dap").step_into() end,          desc = "DAP: step into" },
      { "<S-F11>",    function() require("dap").step_out() end,           desc = "DAP: step out" },
      { "<leader>b",  function() require("dap").toggle_breakpoint() end,  desc = "DAP: toggle breakpoint" },
      {
        "<leader>B",
        function()
          require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
        end,
        desc = "DAP: conditional breakpoint",
      },
      { "<leader>Du", function() require("dapui").toggle() end,           desc = "DAP: toggle UI" },
      { "<leader>De", function() require("dapui").eval() end,             desc = "DAP: evaluate expression", mode = { "n", "v" } },
      { "<leader>Dr", function() require("dap").repl.toggle() end,        desc = "DAP: toggle REPL" },
      { "<leader>Dl", function() require("dap").run_last() end,           desc = "DAP: run last configuration" },
      { "<leader>Dc", function() require("dap").run_to_cursor() end,      desc = "DAP: run to cursor" },
      { "<leader>Dt", function() require("dap-go").debug_test() end,      desc = "DAP: debug nearest Go test" },
      { "<leader>DT", function() require("dap-go").debug_last_test() end, desc = "DAP: debug last Go test" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Registers the "go" adapter (Mason's dlv, found via PATH) and the standard
      -- launch configurations: debug package, debug test, attach to process.
      require("dap-go").setup()

      dapui.setup()
      require("nvim-dap-virtual-text").setup({})

      -- Open the UI with the session, close it when the session ends.
      dap.listeners.before.attach.dapui_config           = function() dapui.open() end
      dap.listeners.before.launch.dapui_config           = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config     = function() dapui.close() end

      -- Gutter signs. Colors reuse diagnostic highlight groups so they follow
      -- whichever colorscheme is active.
      local sign = vim.fn.sign_define
      sign("DapBreakpoint",          { text = "󰃤", texthl = "DiagnosticSignError" })
      sign("DapBreakpointCondition", { text = "󰇽", texthl = "DiagnosticSignWarn" })
      sign("DapBreakpointRejected",  { text = "", texthl = "DiagnosticSignHint" })
      sign("DapLogPoint",            { text = "󰛿", texthl = "DiagnosticSignInfo" })
      sign("DapStopped",             { text = "󰁕", texthl = "DiagnosticSignWarn", linehl = "Visual", numhl = "DiagnosticSignWarn" })
    end,
  },
}
