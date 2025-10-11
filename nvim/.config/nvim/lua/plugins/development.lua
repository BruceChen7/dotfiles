-- 调试和开发工具插件
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "igorlfs/nvim-dap-view" },
      { "theHamsta/nvim-dap-virtual-text" },
    },
    config = function()
      require "config/dap"
    end,
    event = "LspAttach",
  },

  {
    "Exafunction/codeium.vim",
    config = function()
      require "config/codeium"
    end,
    event = "InsertEnter",
  },

  {
    "stevearc/conform.nvim",
    config = function()
      require("conform").setup {
        -- log_level = vim.log.levels.TRACE,
        formatters_by_ft = {
          lua = { "stylua" },
          go = { "gofmt", "goimports" },
          zig = { "zigfmt" },
          markdown = { "autocorrect", "trim_empty_lines" },
          typst = { "autocorrect" },
          python = { "ruff" },
        },
        format_on_save = function(bufnr)
          return { timeout_ms = 1000, lsp_fallback = true }
        end,
        formatters = {
          autocorrect = {
            command = "autocorrect",
            args = { "--stdin", "$FILENAME" },
            -- args = { "$FILENAME" },
            -- stdin == true,
          },
          -- `filename` is original file content
          -- 这里不能使用`$FILENAME`，因为`$FILENAME`是当前文件的内容(上次保存的内容)
          -- 你需要的是修改后的内容
          trim_empty_lines = {
            command = "awk",
            args = {
              -- awk 脚本：删除文件末尾空行，但保留段落间空行
              -- /^$/ 匹配空行，将换行符累积到变量n中
              -- /./ 匹配非空行，先输出累积的空行，再输出当前行，最后重置n
              '/^$/{n=n RS}; /./{printf "%s%s%s",n,$0,RS; n=""}',
            },
          },
        },
      }
    end,
    event = "VeryLazy",
  },

  {
    "saecki/crates.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("crates").setup()
    end,
    ft = { "rust" },
  },

  {
    "williamboman/mason-lspconfig.nvim",
    -- version = "v1.*",
    event = "VeryLazy",
  },
}