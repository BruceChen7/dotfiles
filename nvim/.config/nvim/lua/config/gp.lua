require("gp").setup {
  openai_api_key = os.getenv "OPENAI_API_KEY",
  openai_api_endpoint = "https://api.deepseek.com/chat/completions",
  chat_topic_gen_model = "deepseek-coder",
  agents = {
    -- disable all default agents
    {
      name = "ChatGPT4",
    },
    {
      name = "CodeGPT3-5",
    },

    {
      name = "CodeGPT4",
    },
    {
      name = "ChatGPT3-5",
    },
    {
      name = "deepseek-coder",
      chat = true,
      command = false, -- string with model name or table with model name and parameters
      model = { model = "deepseek-coder", temperature = 1.0, top_p = 1 },
      -- system prompt (use this to specify the persona/role of the AI)
      system_prompt = "You are now a general AI assistant",
      "If you don't know, just say you don't know",
      "Work step by step on your problem",
    },

    {
      name = "deepseek-coder",
      chat = false,
      command = true, -- string with model name or table with model name and parameters
      model = { model = "deepseek-coder", temperature = 1.0, top_p = 1 },
      system_prompt = "You are an AI working as a code editor.\n\n"
        .. "Please AVOID COMMENTARY OUTSIDE OF THE SNIPPET RESPONSE.\n"
        .. "START AND END YOUR ANSWER WITH:\n\n```",
    },
  },
}

vim.keymap.set("v", "<space>re", function()
  local utils = require "utils"

  local visual_selection = utils.get_visual_selection()
  if visual_selection == nil then
    return
  end
  -- Get the selected content in visual mode
  local command = "GpRewrite `"
    .. visual_selection
    .. "`按中文意思翻译成英文，只保留翻译的结果，结果去除引号\n\n"
  vim.cmd(command)
end, { desc = "gp rewrite to english" })

vim.keymap.set({ "n", "v" }, "<space>gp", function() end)

vim.keymap.set("v", "<space>rc", function()
  local utils = require "utils"
  local visual_selection = utils.get_visual_selection()
  if visual_selection == nil then
    return
  end
  local command = "GpRewrite `"
    .. visual_selection
    .. "`按英文意思翻译成中文，要求只保留翻译的结果，结果去除引号\n\n"
  vim.cmd(command)
end, { desc = "gp rewrite to english" })

vim.keymap.set("v", "<space>gc", ":<C-u>'<,'>GpChatNew vsplit<cr>", { desc = "Visual Chat New" })
vim.keymap.set({ "n", "i", "v", "x" }, "<space>gs", "<cmd>GpStop<cr>", { desc = "GpStop" })