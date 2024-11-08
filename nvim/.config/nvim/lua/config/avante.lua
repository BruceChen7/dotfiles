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
    ["deepseek"] = {
      endpoint = "https://api.deepseek.com/beta/chat/completions",
      model = "deepseek-coder",
      api_key_name = "DEEPSEEK_API_KEY",
      parse_curl_args = function(opts, code_opts)
        return {
          url = opts.endpoint,
          headers = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. os.getenv(opts.api_key_name),
          },
          body = {
            model = opts.model,
            messages = { -- you can make your own message, but this is very advanced
              { role = "system", content = code_opts.system_prompt },
              {
                role = "user",
                content = parse_user_messages(require("avante.providers.openai").parse_messages(code_opts)),
              },
            },
            -- https://platform.deepseek.com/api-docs/zh-cn/quick_start/parameter_settings
            temperature = 0.0,
            max_tokens = 8092,
            stream = true, -- this will be set by default.
          },
        }
      end,
      parse_response_data = function(data_stream, event_state, opts)
        require("avante.providers").openai.parse_response(data_stream, event_state, opts)
      end,
    },
  },
}
