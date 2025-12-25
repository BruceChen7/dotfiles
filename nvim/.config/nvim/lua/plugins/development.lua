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

  -- {
  --   "supermaven-inc/supermaven-nvim",
  --   config = function()
  --     require("supermaven-nvim").setup {
  --       keymaps = {
  --         accept_suggestion = "<c-y>",
  --         clear_suggestion = "<Left>",
  --         accept_word = "<C-j>",
  --       },
  --       -- ignore_filetypes = { cpp = true }, -- or { "cpp", }
  --       color = {
  --         suggestion_color = "#ffffff",
  --         cterm = 244,
  --       },
  --       log_level = "info", -- set to "off" to disable logging completely
  --       disable_inline_completion = true, -- disables inline completion for use with cmp
  --       disable_keymaps = true, -- disables built in keymaps for more manual control
  --     }
  --   end,
  --   event = "InsertEnter",
  -- },

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

      -- 创建Go格式化器工厂函数
      local function make_go_formatter(cmd_name)
        return function(bufnr)
          local filename = vim.api.nvim_buf_get_name(bufnr)
          -- 如果以.pb.go结尾，什么都不执行
          if filename:match "%.pb%.go$" then
            -- print("skip " .. filename)
            return { command = "" }
          end
          -- 返回指定的命令配置
          return { command = cmd_name }
        end
      end
      require("conform").formatters.gofmt = make_go_formatter "gofmt"
      require("conform").formatters.goimports = make_go_formatter "goimports"
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
  {
    "AndrewRadev/linediff.vim",
    cmd = { "Linediff", "LinediffReset", "LinediffAdd", "LinediffLast", "LinediffShow", "LinediffPick", "LinediffMerge" },
  },
}
