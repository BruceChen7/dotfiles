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
          typescript = { "ts_fmt_script" },
          typescriptreact = { "ts_fmt_script" },
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

      local function read_package_json(root)
        local package_json = root .. "/package.json"
        if vim.fn.filereadable(package_json) ~= 1 then
          return nil
        end
        local ok_read, content = pcall(vim.fn.readfile, package_json)
        if not ok_read then
          return nil
        end
        local ok_decode, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
        if not ok_decode then
          return nil
        end
        return data
      end

      local function detect_package_manager(root, package_json)
        if package_json and package_json.packageManager then
          local name = package_json.packageManager:match("^(%w+)")
          if name == "pnpm" or name == "yarn" or name == "npm" then
            return name
          end
        end

        if vim.fn.filereadable(root .. "/pnpm-lock.yaml") == 1 then
          return "pnpm"
        end
        if vim.fn.filereadable(root .. "/yarn.lock") == 1 then
          return "yarn"
        end
        if vim.fn.filereadable(root .. "/package-lock.json") == 1 then
          return "npm"
        end

        return "npm"
      end

      local function make_ts_fmt_formatter()
        return function(bufnr)
          local filename = vim.api.nvim_buf_get_name(bufnr)
          if filename == "" then
            return { command = "" }
          end

          local root = require("lspconfig.util").root_pattern("package.json")(filename)
          if not root then
            return { command = "" }
          end

          local package_json = read_package_json(root)
          local scripts = package_json and package_json.scripts or nil
          local script_name
          if scripts then
            if scripts.fmt then
              script_name = "fmt"
            elseif scripts.format then
              script_name = "format"
            end
          end

          if not script_name then
            return { command = "" }
          end

          local package_manager = detect_package_manager(root, package_json)
          local command
          local args
          if package_manager == "pnpm" then
            command = "pnpm"
            args = { script_name }
          elseif package_manager == "yarn" then
            command = "yarn"
            args = { script_name }
          else
            command = "npm"
            args = { "run", script_name }
          end

          return {
            command = command,
            args = args,
            cwd = root,
            stdin = false,
          }
        end
      end

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
      require("conform").formatters.ts_fmt_script = make_ts_fmt_formatter()
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
