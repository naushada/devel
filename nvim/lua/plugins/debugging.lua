return {
  {
    "mfussenegger/nvim-dap",
    optional = true,
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")

      -- Locate lldb-dap (renamed from lldb-vscode in LLVM 17+)
      local lldb_dap = vim.fn.exepath("lldb-dap") ~= "" and vim.fn.exepath("lldb-dap")
        or vim.fn.exepath("lldb-vscode") ~= "" and vim.fn.exepath("lldb-vscode")
        or "lldb-dap"

      dap.adapters.lldb = {
        type    = "executable",
        command = lldb_dap,
        name    = "lldb",
      }

      local cpp_config = {
        {
          name        = "Launch executable",
          type        = "lldb",
          request     = "launch",
          program     = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/", "file")
          end,
          cwd         = "${workspaceFolder}",
          stopOnEntry = false,
          args        = {},
        },
        {
          name        = "Attach to process",
          type        = "lldb",
          request     = "attach",
          pid         = require("dap.utils").pick_process,
          args        = {},
        },
      }

      dap.configurations.cpp = cpp_config
      dap.configurations.c   = cpp_config
    end,
  },
}
