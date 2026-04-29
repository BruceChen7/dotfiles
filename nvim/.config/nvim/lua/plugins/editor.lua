local pack = require "core.pack"
local gh = pack.github

local function setup_switch()
  pack.packadd "switch.vim"
  local camel_to_pascal_pat = [=[\<\(\l\)\(\l\+\(\u\l\+\)\+\)\>]=]
  local camel_to_pascal_repl = [=[\=toupper(submatch(1)) . submatch(2)]=]
  local pascal_to_snake_pat = [=[\<\(\u\l\+\)\(\u\l\+\)\+\>]=]
  local pascal_to_snake_repl = [=[\=tolower(substitute(submatch(0), '\(\l\)\(\u\)', '\1_\2', 'g'))]=]
  local snake_to_upper_pat = [=[\<\(\l\+\)\(_\l\+\)\+\>]=]
  local snake_to_upper_repl = [=[\U\0]=]
  local upper_to_kebab_pat = [=[\<\(\u\+\)\(_\u\+\)\+\>]=]
  local upper_to_kebab_repl = [=[\=tolower(substitute(submatch(0), '_', '-', 'g'))]=]
  local kebab_to_camel_pat = [=[\<\(\l\+\)\(-\l\+\)\+\>]=]
  local kebab_to_camel_repl = [=[\=substitute(submatch(0), '-\(\l\)', '\u\1', 'g')]=]

  vim.g.switch_mapping = ""
  vim.g["switch_custom_definitions"] = {
    vim.fn["switch#NormalizedCaseWords"] { "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" },
    vim.fn["switch#Words"] { "yes", "no" },
    vim.fn["switch#Words"] { "true", "false" },
    vim.fn["switch#Words"] { "on", "off" },
    vim.fn["switch#Words"] { "left", "right" },
    vim.fn["switch#Words"] { "up", "down" },
    vim.fn["switch#Words"] { "enable", "disable" },
    vim.fn["switch#Words"] { "debug", "info", "warning", "error", "critical" },
    vim.fn["switch#Words"] { "public", "private", "protected" },
    vim.fn["switch#Words"] { "const", "let", "var" },
    vim.fn["switch#Words"] { "import", "export" },
    vim.fn["switch#Words"] { "async", "sync" },
    vim.fn["switch#Words"] { "get", "set" },
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
    vim.fn["switch#Words"] { "GET", "POST", "PUT", "PATCH", "DELETE" },
    vim.fn["switch#Words"] { "pending", "active", "completed", "cancelled" },
    vim.fn["switch#Words"] { "todo", "doing", "done" },
    vim.fn["switch#Words"] { "low", "medium", "high", "critical" },
    vim.fn["switch#Words"] { "success", "failure" },
    vim.fn["switch#Words"] { "valid", "invalid" },
    vim.fn["switch#Words"] { "loading", "loaded", "error" },
    vim.fn["switch#Words"] { "block", "inline", "flex", "grid", "none" },
    vim.fn["switch#Words"] { "static", "relative", "absolute", "fixed", "sticky" },
    vim.fn["switch#Words"] { "visible", "hidden" },
    vim.fn["switch#Words"] { "dotted", "dashed", "solid" },
    { "&&", "||" },
    { "++", "--" },
    { "+=", "-=" },
    { ">", "<" },
    {
      [camel_to_pascal_pat] = camel_to_pascal_repl,
      [pascal_to_snake_pat] = pascal_to_snake_repl,
      [snake_to_upper_pat] = snake_to_upper_repl,
      [upper_to_kebab_pat] = upper_to_kebab_repl,
      [kebab_to_camel_pat] = kebab_to_camel_repl,
    },
  }

  vim.keymap.set("n", "<m-=>", "<cmd>Switch<cr>", { noremap = true, desc = "switch" })

  local group = vim.api.nvim_create_augroup("CustomSwitches", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "gitrebase" },
    callback = function()
      vim.b["switch_custom_definitions"] = {
        { "pick", "reword", "edit", "squash", "fixup", "exec", "drop" },
      }
    end,
  })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "markdown" },
    callback = function()
      local fk = [=[\v^(\s*[*+-] )?\[ \]]=]
      local sk = [=[\v^(\s*[*+-] )?\[x\]]=]
      local tk = [=[\v^(\s*[*+-] )?\[-\]]=]
      local fok = [=[\v^(\s*\d+\. )?\[ \]]=]
      local fik = [=[\v^(\s*\d+\. )?\[x\]]=]
      local sik = [=[\v^(\s*\d+\. )?\[-\]]=]

      vim.b["switch_custom_definitions"] = {
        {
          [fk] = [=[\1[x]]=],
          [sk] = [=[\1[-]]=],
          [tk] = [=[\1[ ]]=],
        },
        {
          [fok] = [=[\1[x]]=],
          [fik] = [=[\1[-]]=],
          [sik] = [=[\1[ ]]=],
        },
      }
    end,
  })
end

return {
  name = "editor",
  specs = {
    { src = gh "AndrewRadev/switch.vim" },
    { src = gh "karb94/neoscroll.nvim" },
    { src = gh "kevinhwang91/nvim-hlslens" },
    { src = gh "kevinhwang91/nvim-ufo" },
    { src = gh "kevinhwang91/promise-async" },
    { src = gh "gennaro-tedesco/nvim-peekup" },
    { src = gh "ptdewey/yankbank-nvim" },
    { src = gh "carbon-steel/detour.nvim" },
    { src = gh "folke/trouble.nvim" },
    { src = gh "smjonas/live-command.nvim" },
    { src = gh "nvim-pack/nvim-spectre" },
    { src = gh "nvim-lua/plenary.nvim" },
    { src = gh "ojroques/nvim-osc52" },
  },
  setup = function()
    setup_switch()
    pack.setup_config("neoscroll.nvim", "config/neoscroll")
    pack.setup_config("nvim-hlslens", "config/hlslen")
    pack.packadd "promise-async"
    pack.setup_config("nvim-ufo", "config/ufo")
    pack.packadd "nvim-peekup"
    pack.packadd "detour.nvim"

    pack.safe_call("yankbank", function()
      pack.packadd "yankbank-nvim"
      require("yankbank").setup { max_entries = 20, num_behavior = "prefix" }
      vim.keymap.set("n", "<leader>yy", "<cmd>YankBank<CR>", { noremap = true, desc = "yank history list" })
    end)

    vim.keymap.set("n", "<c-w><enter>", "<cmd>Detour<cr>", { desc = "Detour" })
    vim.keymap.set("n", "<c-w>.", "<cmd>DetourCurrentWindow<cr>", { desc = "Detour current window" })

    pack.safe_call("live-command", function()
      pack.packadd "live-command.nvim"
      require("live-command").setup { commands = { Norm = { cmd = "norm" } } }
    end)

    pack.safe_call("spectre", function()
      pack.packadd "plenary.nvim"
      pack.packadd "nvim-spectre"
      vim.keymap.set("n", "<leader>S", function()
        require("spectre").toggle()
      end, { desc = "Toggle Spectre" })
      vim.keymap.set("n", "<leader>sw", function()
        require("spectre").open_visual { select_word = true }
      end, { desc = "Search current word" })
      vim.keymap.set("v", "<leader>sw", function()
        require("spectre").open_visual()
      end, { desc = "Search selection" })
      vim.keymap.set("n", "<leader>sp", function()
        require("spectre").open_file_search { select_word = true }
      end, { desc = "Search on current file" })
      require("spectre").setup {
        mapping = {
          run_current_replace = {
            map = "<leader>rc",
            cmd = "<cmd>lua require('spectre.actions').run_current_replace()<CR>",
            desc = "replace current line",
          },
          run_replace = {
            map = "<leader>rr",
            cmd = "<cmd>lua require('spectre.actions').run_replace()<CR>",
            desc = "replace all",
          },
        },
      }
    end)

    pack.safe_call("trouble", function()
      pack.packadd "trouble.nvim"
      require("trouble").setup {}
    end)

    vim.keymap.set("n", "\\xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
    vim.keymap.set("n", "\\xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Buffer Diagnostics (Trouble)" })
    vim.keymap.set("n", "\\cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols (Trouble)" })
    vim.keymap.set("n", "\\cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", { desc = "LSP references (Trouble)" })
    vim.keymap.set("n", "\\xL", "<cmd>Trouble loclist toggle<cr>", { desc = "Location List (Trouble)" })
    vim.keymap.set("n", "\\xQ", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })

    pack.safe_call("osc52", function()
      pack.packadd "nvim-osc52"
      vim.keymap.set("n", "\\c", require("osc52").copy_operator, { expr = true, desc = "copy to clipboard" })
      vim.keymap.set("x", "\\c", require("osc52").copy_visual, { desc = "copy to clipboard" })
    end)
  end,
}
