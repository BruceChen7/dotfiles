require("gp").setup {
  -- openai_api_key = os.getenv "OPENAI_API_KEY",
  -- openai_api_endpoint = "https://api.deepseek.com/chat/completions",
  --
  providers = {
    openai = {
      endpoint = "https://api.deepseek.com/chat/completions",
      secret = os.getenv "OPENAI_API_KEY",
    },
  },
  chat_topic_gen_model = "deepseek-chat",
  agents = {
    -- disable all default agents
    {
      name = "ChatGPT4",
      disable = true,
    },
    {
      name = "CodeGPT3-5",
      disable = true,
    },
    {
      name = "CodeGPT4o",
      disable = true,
    },

    {
      name = "CodeGPT4",
      disable = true,
    },
    {
      name = "ChatGPT3-5",
      disable = true,
    },
    {
      name = "deepseek-chat",
      chat = true,
      command = false, -- string with model name or table with model name and parameters
      -- see `temperature` in ths page `https://platform.deepseek.com/api-docs/zh-cn/`
      model = { model = "deepseek-chat", temperature = 1.0, top_p = 1 },
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
  hooks = {
    Implement = function(gp, params)
      local template = "Having following from {{filename}}:\n\n"
        .. "```{{filetype}}\n{{selection}}\n```\n\n"
        .. "Please rewrite this according to the contained instructions."
        .. "\n\nRespond exclusively with the snippet that should replace the selection above."

      local agent = gp.get_command_agent()
      gp.info("Implementing selection with agent: " .. agent.name)

      gp.Prompt(
        params,
        gp.Target.rewrite,
        nil, -- command will run directly without any prompting for user input
        agent.model,
        template,
        agent.system_prompt
      )
    end,

    Tranlate = function(gp, params)
      local template = "Having following from {{filename}}:\n\n"
        .. "```{{filetype}}\n{{selection}}\n```\n\n"
        .. "Please rewrite this according to the contained instructions."
        .. "\n\nRespond exclusively with the snippet that should replace the selection above."

      local agent = gp.get_command_agent()
      gp.info("Implementing selection with agent: " .. agent.name)

      gp.Prompt(
        params,
        gp.Target.rewrite,
        nil, -- command will run directly without any prompting for user input
        agent.model,
        template,
        agent.system_prompt
      )
    end,
    -- example of adding command which explains the selected code
    Explain = function(gp, params)
      local template = "I have the following code from {{filename}}:\n\n"
        .. "```{{filetype}}\n{{selection}}\n```\n\n"
        .. "Please respond by explaining the code above."
      local agent = gp.get_chat_agent()
      gp.Prompt(params, gp.Target.enew "markdown", nil, agent.model, template, agent.system_prompt)
    end,
    -- example of usig enew as a function specifying type for the new buffer
    CodeReview = function(gp, params)
      local template = "I have the following code from {{filename}}:\n\n"
        .. "```{{filetype}}\n{{selection}}\n```\n\n"
        .. "Please analyze for code smells and suggest improvements."
      local agent = gp.get_chat_agent()
      gp.Prompt(params, gp.Target.enew "markdown", nil, agent.model, template, agent.system_prompt)
    end,
    -- example of adding command which opens new chat dedicated for translation
    Translator = function(gp, params)
      local agent = gp.get_command_agent()
      local chat_system_prompt = "You are a Translator, please translate between English and Chinese."
      gp.cmd.ChatNew(params, agent.model, chat_system_prompt)
    end,
  },
}

vim.keymap.set("v", "\\ge", function()
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

vim.keymap.set("v", "\\gc", function()
  local utils = require "utils"
  local visual_selection = utils.get_visual_selection()
  if visual_selection == nil then
    return
  end
  local command = "GpRewrite `"
    .. visual_selection
    .. "`按英文意思翻译成中文，要求只保留翻译的结果，结果去除引号\n\n"
  vim.cmd(command)
end, { desc = "gp rewrite to chinese" })

vim.keymap.set({ "v", "n" }, "\\gv", ":<C-u>'<,'>GpChatNew vsplit<cr>", { desc = "Visul Chat New" })
-- vim.keymap.set({ "n", "v", "x" }, "\\gs", "<cmd>GpStop<cr>", { desc = "GpStop" })
