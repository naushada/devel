return {
  {
    "nvim-lua/plenary.nvim",
    lazy = false,
    config = function()
      -- OSC52 clipboard: tunnels copy/paste through the terminal to the host clipboard.
      -- Works inside Docker/Podman containers without X11 or pbcopy.
      vim.g.clipboard = {
        name = "OSC52",
        copy = {
          ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
          ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
        },
        paste = {
          ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
          ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
        },
      }
      vim.opt.clipboard = "unnamedplus"
    end,
  },
}
