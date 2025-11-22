return {
  { "skywind3000/asynctasks.vim" },
  { "skywind3000/asyncrun.vim" },
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
      local fk = [=[\<\(\l\)\(\l\+\(\u\l\+\)\+\)\>]=]
      local sk = [=[\<\(\u\l\+\)\(\u\l\+\)\+\>]=]
      local tk = [=[\<\(\l\+\)\(_\l\+\)\+\>]=]
      local fok = [=[\<\(\u\+\)\(_\u\+\)\+\>]=]
      local folk = [=[\<\(\l\+\)\(\-\l\+\)\+\>]=]
      local fik = [=[\<\(\l\+\)\(\.\l\+\)\+\>]=]
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
        {
          [fk] = [=[\=toupper(submatch(1)) . submatch(2)]=],
          [sk] = [=[\=tolower(substitute(submatch(0), '\(\l\)\(\u\)', '\1_\2', 'g'))]=],
          [tk] = [=[\U\0]=],
          [fok] = [=[\=tolower(substitute(submatch(0), '_', '-', 'g'))]=],
          [folk] = [=[\=substitute(submatch(0), '-', '.', 'g')]=],
          [fik] = [=[\=substitute(submatch(0), '\.\(\l\)', '\u\1', 'g')]=],
        },
      }
      vim.keymap.set("n", "<m-m>", "<cmd>Switch<cr>", { noremap = true, desc = "switch" })
    end,
    init = function()
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
