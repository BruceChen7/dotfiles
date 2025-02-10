local parse_user_messages = function(messages)
  local user_messages = {}
  for _, message in pairs(messages) do
    if message and message.role == "user" then
      table.insert(user_messages, message.content)
    end
  end
  return table.concat(user_messages, "\n")
end

require("avante").setup {
  -- add any opts here
  behaviour = {
    auto_suggestions = false,
    -- auto_set_keymaps = false,
  },
  provider = "deepseek",
  auto_suggestions_provider = "deepseek",
  mappings = {
    ask = "\\ak",
    edit = "\\am",
    refresh = "\\ar",
    --- @class AvanteConflictMappings
    diff = {
      ours = "\\co",
      theirs = "\\ct",
      none = "\\c0",
      both = "\\cb",
      next = "]x",
      prev = "[x",
    },
    jump = {
      next = "]]",
      prev = "[[",
    },
    submit = {
      normal = "<CR>",
      insert = "<C-s>",
    },
    suggestion = {
      accept = "<M-j>",
      -- next = "<\\n>",
      -- prev = "<[\\p>",
      -- dismiss = "<\\]>",
    },
  },
  vendors = {
    deepseek = {
      __inherited_from = "openai",
      api_key_name = "DEEPSEEK_API_KEY",
      endpoint = "https://api.deepseek.com",
      model = "deepseek-chat",
    },
  },
  -- vendors = {
  --   ["deepseek"] = {
  --     endpoint = "https://api.deepseek.com/beta/chat/completions",
  --     model = "deepseek-coder",
  --     api_key_name = "DEEPSEEK_API_KEY",
  --     __inherited_from = "openai",
  --   },
  -- },
}
