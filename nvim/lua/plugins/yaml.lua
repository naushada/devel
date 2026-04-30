return {
  -- YAML formatting via prettier (format on save)
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        yaml = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_format = "fallback",
      },
    },
  },

  -- YAML LSP for validation and hover docs
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        yamlls = {
          settings = {
            yaml = {
              validate = true,
              hover = true,
              completion = true,
              format = { enable = false }, -- let conform handle formatting
            },
          },
        },
      },
    },
  },
}
