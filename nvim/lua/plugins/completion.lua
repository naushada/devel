return {
  -- nvim-cmp (LazyVim < v14)
  {
    "hrsh7th/nvim-cmp",
    optional = true,
    dependencies = {
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
    },
    opts = function(_, opts)
      local cmp = require("cmp")
      opts.window = {
        completion    = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
      }
      opts.sources = cmp.config.sources({
        { name = "nvim_lsp", priority = 1000 },
        { name = "luasnip",  priority = 750  },
        { name = "buffer",   priority = 500  },
        { name = "path",     priority = 250  },
      })
      return opts
    end,
  },

  -- blink.cmp (LazyVim v14+)
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 100,
        },
      },
    },
  },
}
