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
    -- Use the plugin's own installer (downloads a prebuilt binary) instead of
    -- `npm/yarn install`, which rewrites app/yarn.lock and leaves the git
    -- checkout dirty — that dirty state makes lazy.nvim refuse to update it.
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    config = function()
      vim.g.mkdp_auto_close = 1
      vim.g.mkdp_browser = ""
    end,
  },
}
