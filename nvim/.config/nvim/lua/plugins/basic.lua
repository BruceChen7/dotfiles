return {
  { "skywind3000/asynctasks.vim" },
  {
    "skywind3000/asyncrun.vim",
    config = function()
      require "config/cmd"
    end,
  },
  -- {
  --   "suliatis/Jumppack.nvim",
  --   config = true,
  -- },
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*", -- recommended, use latest release instead of latest commit
    ft = "markdown",
    -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
    -- event = {
    --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
    --   -- refer to `:h file-pattern` for more examples
    --   "BufReadPre path/to/my-vault/*.md",
    --   "BufNewFile path/to/my-vault/*.md",
    -- },
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
      legacy_commands = false,
      workspaces = {
        {
          name = "personal",
          path = "~/work/notes",
        },
      },
      -- see below for full list of options 👇
    },
  },

  {
    "AndrewRadev/switch.vim",
    config = function()
      -- camelCase -> PascalCase
      local camel_to_pascal_pat = [=[\<\(\l\)\(\l\+\(\u\l\+\)\+\)\>]=]
      local camel_to_pascal_repl = [=[\=toupper(submatch(1)) . submatch(2)]=]
      -- PascalCase -> snake_case
      local pascal_to_snake_pat = [=[\<\(\u\l\+\)\(\u\l\+\)\+\>]=]
      local pascal_to_snake_repl = [=[\=tolower(substitute(submatch(0), '\(\l\)\(\u\)', '\1_\2', 'g'))]=]
      -- snake_case -> UPPER_CASE
      local snake_to_upper_pat = [=[\<\(\l\+\)\(_\l\+\)\+\>]=]
      local snake_to_upper_repl = [=[\U\0]=]
      -- UPPER_CASE -> kebab-case
      local upper_to_kebab_pat = [=[\<\(\u\+\)\(_\u\+\)\+\>]=]
      local upper_to_kebab_repl = [=[\=tolower(substitute(submatch(0), '_', '-', 'g'))]=]
      -- kebab-case -> camelCase
      local kebab_to_camel_pat = [=[\<\(\l\+\)\(-\l\+\)\+\>]=]
      local kebab_to_camel_repl = [=[\=substitute(submatch(0), '-\(\l\)', '\u\1', 'g')]=]

      vim.g["switch_custom_definitions"] = {
        vim.fn["switch#NormalizedCaseWords"] {
          "sunday",
          "monday",
          "tuesday",
          "wednesday",
          "thursday",
          "friday",
          "saturday",
        },
        vim.fn["switch#Words"] { "yes", "no" },
        vim.fn["switch#Words"] { "true", "false" },
        vim.fn["switch#Words"] { "on", "off" },
        vim.fn["switch#Words"] { "left", "right" },
        vim.fn["switch#Words"] { "up", "down" },
        vim.fn["switch#Words"] { "enable", "disable" },
        vim.fn["switch#Words"] { "Always", "Never" },
        vim.fn["switch#Words"] { "debug", "info", "warning", "error", "critical" },
        vim.fn["switch#Words"] { "==", "!=", "~=" },
        -- 编程常用
        vim.fn["switch#Words"] { "public", "private", "protected" },
        vim.fn["switch#Words"] { "const", "let", "var" },
        vim.fn["switch#Words"] { "import", "export" },
        vim.fn["switch#Words"] { "async", "sync" },
        vim.fn["switch#Words"] { "static", "dynamic" },
        vim.fn["switch#Words"] { "get", "set" },
        vim.fn["switch#Words"] { "push", "pop" },
        vim.fn["switch#Words"] { "add", "remove" },
        vim.fn["switch#Words"] { "show", "hide" },
        vim.fn["switch#Words"] { "open", "close" },
        vim.fn["switch#Words"] { "start", "stop" },
        vim.fn["switch#Words"] { "begin", "end" },
        vim.fn["switch#Words"] { "first", "last" },
        vim.fn["switch#Words"] { "next", "prev" },
        vim.fn["switch#Words"] { "before", "after" },
        vim.fn["switch#Words"] { "min", "max" },
        vim.fn["switch#Words"] { "asc", "desc" },
        vim.fn["switch#Words"] { "read", "write" },
        vim.fn["switch#Words"] { "input", "output" },
        vim.fn["switch#Words"] { "row", "column" },
        vim.fn["switch#Words"] { "width", "height" },
        vim.fn["switch#Words"] { "horizontal", "vertical" },
        vim.fn["switch#Words"] { "and", "or" },
        vim.fn["switch#Words"] { "int8", "int16", "int32", "int64", "uint8", "uint16", "uint32", "uint64" },
        -- HTTP 方法
        vim.fn["switch#Words"] { "GET", "POST", "PUT", "PATCH", "DELETE" },
        -- 状态相关
        vim.fn["switch#Words"] { "pending", "active", "completed", "cancelled" },
        vim.fn["switch#Words"] { "todo", "doing", "done" },
        vim.fn["switch#Words"] { "low", "medium", "high", "critical" },
        vim.fn["switch#Words"] { "success", "failure" },
        vim.fn["switch#Words"] { "valid", "invalid" },
        vim.fn["switch#Words"] { "loading", "loaded", "error" },
        -- CSS 常用
        vim.fn["switch#Words"] { "block", "inline", "flex", "grid", "none" },
        vim.fn["switch#Words"] { "static", "relative", "absolute", "fixed", "sticky" },
        vim.fn["switch#Words"] { "visible", "hidden" },
        vim.fn["switch#Words"] { "dotted", "dashed", "dotted" },

        -- 符号相关
        { "1", "1" },
        { "&&", "||" },
        { "++", "--" },
        { "+=", "-=" },
        { ">", "<" },
        -- case 转换
        --         {

        {
          [camel_to_pascal_pat] = camel_to_pascal_repl,
          [pascal_to_snake_pat] = pascal_to_snake_repl,
          [snake_to_upper_pat] = snake_to_upper_repl,
          [upper_to_kebab_pat] = upper_to_kebab_repl,
          [kebab_to_camel_pat] = kebab_to_camel_repl,
        },
      }
      -- vim.keymap.set("n", "gs", "<Nop>")
      vim.keymap.set("n", "<m-=>", "<cmd>Switch<cr>", { noremap = true, desc = "switch" })
    end,
    init = function()
      vim.g.switch_mapping = ""
      local custom_switches = vim.api.nvim_create_augroup("CustomSwitches", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = custom_switches,
        pattern = { "gitrebase" },
        callback = function()
          vim.b["switch_custom_definitions"] = {
            { "pick", "reword", "edit", "squash", "fixup", "exec", "drop" },
          }
        end,
      })
      -- (un)check markdown buxes
      -- Markdown checkbox state cycling for unordered lists (*, -, + bullets)
      vim.api.nvim_create_autocmd("FileType", {
        group = custom_switches,
        pattern = { "markdown" },
        callback = function()
          -- Regex patterns for unordered list checkboxes
          local fk = [=[\v^(\s*[*+-] )?\[ \]]=] -- Empty checkbox [ ]
          local sk = [=[\v^(\s*[*+-] )?\[x\]]=] -- Checked checkbox [x]
          local tk = [=[\v^(\s*[*+-] )?\[-\]]=] -- Intermediate state checkbox [-]

          -- Regex patterns for ordered list checkboxes (numbers like 1., 2., etc.)
          local fok = [=[\v^(\s*\d+\. )?\[ \]]=] -- Empty checkbox in ordered list
          local fik = [=[\v^(\s*\d+\. )?\[x\]]=] -- Checked checkbox in ordered list
          local sik = [=[\v^(\s*\d+\. )?\[-\]]=] -- Intermediate state checkbox in ordered list

          vim.b["switch_custom_definitions"] = {
            -- Unordered list checkbox cycling: [ ] -> [x] -> [-] -> [ ]
            {
              [fk] = [=[\1[x]]=], -- empty -> checked
              [sk] = [=[\1[-]]=], -- checked -> intermediate
              [tk] = [=[\1[ ]]=], -- intermediate -> empty
            },
            -- Ordered list checkbox cycling: [ ] -> [x] -> [-] -> [ ]
            {
              [fok] = [=[\1[x]]=], -- empty -> checked
              [fik] = [=[\1[-]]=], -- checked -> intermediate
              [sik] = [=[\1[ ]]=], -- intermediate -> empty
            },
          }
        end,
      })
    end,
  },
}
