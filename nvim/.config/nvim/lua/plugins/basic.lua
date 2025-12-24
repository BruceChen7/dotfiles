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
      -- Vim 正则: \< \> 词边界, \l 小写, \u 大写, \+ 一个或多个, \(\) 捕获组
      local camel_case = [=[\<\(\l\)\(\l\+\(\u\l\+\)\+\)\>]=] -- myVariableName: 小写开头 + (小写 + 大写小写)+
      local pascal_case = [=[\<\(\u\l\+\)\(\u\l\+\)\+\>]=] -- MyVariableName: (大写小写)+
      local snake_case = [=[\<\(\l\+\)\(_\l\+\)\+\>]=] -- my_variable_name: 小写 + (_小写)+
      local screaming = [=[\<\(\u\+\)\(_\u\+\)\+\>]=] -- MY_VARIABLE_NAME: 大写 + (_大写)+
      local kebab_case = [=[\<\(\l\+\)\(\-\l\+\)\+\>]=] -- my-variable-name: 小写 + (-小写)+
      local dot_case = [=[\<\(\l\+\)\(\.\l\+\)\+\>]=] -- my.variable.name: 小写 + (.小写)+
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
        vim.fn["switch#NormalizedCase"] { "yes", "no" },
        vim.fn["switch#NormalizedCase"] { "true", "false" },
        vim.fn["switch#NormalizedCase"] { "on", "off" },
        vim.fn["switch#NormalizedCase"] { "left", "right" },
        vim.fn["switch#NormalizedCase"] { "up", "down" },
        vim.fn["switch#NormalizedCase"] { "enable", "disable" },
        vim.fn["switch#NormalizedCase"] { "Always", "Never" },
        vim.fn["switch#NormalizedCase"] { "debug", "info", "warning", "error", "critical" },
        vim.fn["switch#NormalizedCase"] { "==", "!=", "~=" },
        -- 编程常用
        vim.fn["switch#NormalizedCase"] { "public", "private", "protected" },
        vim.fn["switch#NormalizedCase"] { "const", "let", "var" },
        vim.fn["switch#NormalizedCase"] { "import", "export" },
        vim.fn["switch#NormalizedCase"] { "async", "sync" },
        vim.fn["switch#NormalizedCase"] { "static", "dynamic" },
        vim.fn["switch#NormalizedCase"] { "get", "set" },
        vim.fn["switch#NormalizedCase"] { "push", "pop" },
        vim.fn["switch#NormalizedCase"] { "add", "remove" },
        vim.fn["switch#NormalizedCase"] { "show", "hide" },
        vim.fn["switch#NormalizedCase"] { "open", "close" },
        vim.fn["switch#NormalizedCase"] { "start", "stop" },
        vim.fn["switch#NormalizedCase"] { "begin", "end" },
        vim.fn["switch#NormalizedCase"] { "first", "last" },
        vim.fn["switch#NormalizedCase"] { "next", "prev" },
        vim.fn["switch#NormalizedCase"] { "before", "after" },
        vim.fn["switch#NormalizedCase"] { "min", "max" },
        vim.fn["switch#NormalizedCase"] { "asc", "desc" },
        vim.fn["switch#NormalizedCase"] { "read", "write" },
        vim.fn["switch#NormalizedCase"] { "input", "output" },
        vim.fn["switch#NormalizedCase"] { "row", "column" },
        vim.fn["switch#NormalizedCase"] { "width", "height" },
        vim.fn["switch#NormalizedCase"] { "horizontal", "vertical" },
        vim.fn["switch#NormalizedCase"] { "and", "or" },
        vim.fn["switch#NormalizedCase"] { "all", "any", "none" },
        -- HTTP 方法
        vim.fn["switch#NormalizedCase"] { "GET", "POST", "PUT", "PATCH", "DELETE" },
        -- 状态相关
        vim.fn["switch#NormalizedCase"] { "pending", "active", "completed", "cancelled" },
        vim.fn["switch#NormalizedCase"] { "todo", "doing", "done" },
        vim.fn["switch#NormalizedCase"] { "low", "medium", "high", "critical" },
        vim.fn["switch#NormalizedCase"] { "success", "failure" },
        vim.fn["switch#NormalizedCase"] { "valid", "invalid" },
        vim.fn["switch#NormalizedCase"] { "loading", "loaded", "error" },
        -- CSS 常用
        vim.fn["switch#NormalizedCase"] { "block", "inline", "flex", "grid", "none" },
        vim.fn["switch#NormalizedCase"] { "static", "relative", "absolute", "fixed", "sticky" },
        vim.fn["switch#NormalizedCase"] { "visible", "hidden" },
        vim.fn["switch#NormalizedCase"] { "solid", "dashed", "dotted" },
        -- 符号相关
        { "0", "1" },
        { "&&", "||" },
        { "++", "--" },
        { "+=", "-=" },
        { ">=", "<=" },
        { ">>>", "<<<" },
        -- case 转换
        {
          [camel_case] = [=[\=toupper(submatch(1)) . submatch(2)]=],
          [pascal_case] = [=[\=tolower(substitute(submatch(0), '\(\l\)\(\u\)', '\1_\2', 'g'))]=],
          [snake_case] = [=[\U\0]=],
          [screaming] = [=[\=tolower(substitute(submatch(0), '_', '-', 'g'))]=],
          [kebab_case] = [=[\=substitute(submatch(0), '-', '.', 'g')]=],
          [dot_case] = [=[\=substitute(submatch(0), '\.\(\l\)', '\u\1', 'g')]=],
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
