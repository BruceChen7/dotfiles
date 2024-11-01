require("llm").setup {
  max_tokens = 512,
  url = "https://open.bigmodel.cn/api/paas/v4/chat/completions",
  model = "glm-4-flash",
  prefix = {
    user = { text = "😃 ", hl = "Title" },
    assistant = { text = "⚡ ", hl = "Added" },
  },

  save_session = true,
  max_history = 30,
  keys = {
    -- The keyboard mapping for the input window.
    ["Input:Submit"] = { mode = "i", key = "<cr>" },
    ["Input:Cancel"] = { mode = "i", key = "<C-c>" },
    ["Input:Resend"] = { mode = "n", key = "<C-r>" },

    -- only works when "save_session = true"
    ["Input:HistoryNext"] = { mode = "i", key = "<C-S-j>" },
    ["Input:HistoryPrev"] = { mode = "i", key = "<C-S-k>" },

    -- The keyboard mapping for the output window in "split" style.
    ["Output:Ask"] = { mode = "n", key = "i" },
    ["Output:Cancel"] = { mode = "n", key = "<C-c>" },
    ["Output:Resend"] = { mode = "n", key = "<C-r>" },

    -- The keyboard mapping for the output and input windows in "float" style.
    ["Session:Toggle"] = { mode = "n", key = "<leader>ac" },
    ["Session:Close"] = { mode = "n", key = "<esc>" },
  },
}

vim.keymap.set("n", "<leader>lc", ":LLMSessionToggle<cr>", { desc = "Toggle LLM session" })
vim.keymap.set(
  "v",
  "<leader>le",
  "<cmd>LLMSelectedTextHandler 请解释下面这段代码<cr>",
  { desc = "Explain selected text" }
)
vim.keymap.set("x", "<leader>lt", "<cmd>LLMSelectedTextHandler 英译汉<cr>", { desc = "Translate selected text" })
