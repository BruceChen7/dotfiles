local pack = require "core.pack"
local gh = pack.github

return {
  name = "navigation",
  specs = {
    { src = gh "folke/flash.nvim" },
    { src = gh "christoomey/vim-tmux-navigator" },
    { src = gh "aaronik/treewalker.nvim" },
    { src = gh "ibhagwan/fzf-lua" },
    { src = gh "ThePrimeagen/harpoon", version = "harpoon2" },
    { src = gh "piersolenski/import.nvim" },
    { src = gh "shahshlok/vim-coach.nvim" },
  },
  setup = function()
    pack.safe_call("flash", function()
      pack.packadd "flash.nvim"
      require("flash").setup {
        modes = {
          search = { enabled = false },
          char = { keys = {} },
        },
      }
    end)

    vim.keymap.set({ "n", "x", "o" }, "s", function()
      require("flash").jump()
    end, { desc = "Flash" })
    vim.keymap.set({ "n", "x", "o" }, "S", function()
      require("flash").treesitter()
    end, { desc = "Flash Treesitter" })
    vim.keymap.set("o", "r", function()
      require("flash").remote()
    end, { desc = "Remote Flash" })

    pack.packadd "vim-tmux-navigator"
    vim.keymap.set("n", "<c-h>", "<cmd>TmuxNavigateLeft<cr>")
    vim.keymap.set("n", "<c-j>", "<cmd>TmuxNavigateDown<cr>")
    vim.keymap.set("n", "<c-k>", "<cmd>TmuxNavigateUp<cr>")
    vim.keymap.set("n", "<c-l>", "<cmd>TmuxNavigateRight<cr>")
    vim.keymap.set("x", "<c-h>", ":<C-U>TmuxNavigateLeft<cr>")
    vim.keymap.set("x", "<c-j>", ":<C-U>TmuxNavigateDown<cr>")
    vim.keymap.set("x", "<c-k>", ":<C-U>TmuxNavigateUp<cr>")
    vim.keymap.set("x", "<c-l>", ":<C-U>TmuxNavigateRight<cr>")

    pack.safe_call("treewalker", function()
      pack.packadd "treewalker.nvim"
      require("treewalker").setup { highlight = true, highlight_duration = 250 }
    end)
    vim.keymap.set("n", "\\wj", "<cmd>Treewalker Down<CR>", { noremap = true, desc = "treewalker down" })
    vim.keymap.set("n", "\\wk", "<cmd>Treewalker Up<CR>", { noremap = true, desc = "Treewalker up" })
    vim.keymap.set("n", "\\wh", "<cmd>Treewalker Left<CR>", { noremap = true, desc = "treewalker left" })
    vim.keymap.set("n", "\\wl", "<cmd>Treewalker Right<CR>", { noremap = true, desc = "treewalker right" })
    vim.keymap.set("n", "<C-S-k>", "<cmd>Treewalker SwapUp<cr>", { silent = true, desc = "treewalker swap up" })
    vim.keymap.set("n", "<C-S-j>", "<cmd>Treewalker SwapDown<cr>", { silent = true, desc = "treewalker swap down" })
    vim.keymap.set("n", "<C-S-h>", "<cmd>Treewalker SwapLeft<cr>", { silent = true, desc = "treewalker swap left" })
    vim.keymap.set("n", "<C-S-l>", "<cmd>Treewalker SwapRight<cr>", { silent = true, desc = "treewalker swap right" })

    pack.setup_config("fzf-lua", "config/fzf")
    pack.setup_config("harpoon", "config/harpoon")

    pack.safe_call("import.nvim", function()
      pack.packadd "import.nvim"
      require("import").setup { picker = "snacks", insert_at_top = false }
      vim.keymap.set("n", "\\i", function()
        require("import").pick()
      end, { desc = "Import dependency" })
    end)

    pack.safe_call("vim-coach", function()
      pack.packadd "snacks.nvim"
      pack.packadd "vim-coach.nvim"
      require("vim-coach").setup()
      vim.keymap.set("n", "<leader>?", "<cmd>VimCoach<cr>", { desc = "Vim Coach" })
    end)
  end,
}
