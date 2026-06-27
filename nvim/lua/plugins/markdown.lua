return {
  -- Rich in-buffer markdown rendering (headers, code blocks, tables, checkboxes)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    ft = { "markdown" },
    opts = {
      render_modes = { "n", "c" },
      heading = { enabled = true },
      code = { enabled = true, style = "full" },
      bullet = { enabled = true },
      checkbox = { enabled = true },
      table = { enabled = true },
    },
  },

  -- Browser-based preview via :MarkdownPreview
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = { "markdown" },
    -- Build with npm rather than yarn: `yarn install` rewrites the tracked
    -- app/yarn.lock and leaves the checkout dirty, which makes lazy.nvim refuse
    -- to update the plugin. `npm install` only writes an untracked
    -- package-lock.json, so the tree stays clean. (The mkdp#util#install()
    -- build function form fails with E117 here because the plugin is
    -- lazy-loaded and its autoload file is not on the runtimepath at build.)
    build = "cd app && npm install",
    config = function()
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_browser = ""
    end,
  },
}
