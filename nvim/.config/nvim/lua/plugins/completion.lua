local pack = require "core.pack"
local gh = pack.github

return {
  name = "completion",
  specs = {
    { src = gh "saghen/blink.cmp", name = "blink.cmp", version = "v1" },
    { src = gh "archie-judd/blink-cmp-words" },
  },
  setup = function()
    pack.safe_call("blink.cmp", function()
      pack.packadd "blink.cmp"
      require("blink.cmp").setup {
        appearance = {
          use_nvim_cmp_as_default = true,
          nerd_font_variant = "mono",
        },
        completion = {
          keyword = { range = "full" },
          accept = { auto_brackets = { enabled = true } },
          menu = {
            auto_show = function()
              return vim.bo.buftype ~= "prompt" and vim.b.completion ~= false and vim.bo.filetype ~= "TelescopePrompt"
            end,
          },
          documentation = {
            auto_show = true,
            auto_show_delay_ms = 200,
          },
          list = {
            selection = {
              preselect = false,
              auto_insert = true,
            },
          },
        },
        sources = {
          default = { "lsp", "path", "snippets", "buffer" },
          providers = {
            thesaurus = {
              name = "blink-cmp-words",
              module = "blink-cmp-words.thesaurus",
              opts = {
                score_offset = 0,
                definition_pointers = { "!", "&", "^" },
              },
            },
            dictionary = {
              name = "blink-cmp-words",
              module = "blink-cmp-words.dictionary",
              opts = {
                dictionary_search_threshold = 3,
                score_offset = 0,
                definition_pointers = { "!", "&", "^" },
              },
            },
          },
          per_filetype = {
            text = { "dictionary" },
            markdown = { "thesaurus" },
            gitcommit = { "dictionary", "buffer", "path" },
          },
        },
        cmdline = {
          enabled = true,
          keymap = {
            ["<Tab>"] = {
              function(cmp)
                if cmp.is_ghost_text_visible() and not cmp.is_menu_visible() then
                  return cmp.accept()
                end
              end,
              "show_and_insert",
              "select_next",
            },
            ["<S-Tab>"] = { "show_and_insert", "select_prev" },
            ["<C-j>"] = { "select_next" },
            ["<C-k>"] = { "select_prev" },
            ["<C-y>"] = { "select_and_accept" },
            ["<C-e>"] = { "cancel" },
          },
          sources = function()
            local type = vim.fn.getcmdtype()
            if type == "/" or type == "?" then
              return { "buffer" }
            end
            if type == ":" or type == "@" then
              return { "cmdline" }
            end
            return {}
          end,
        },
        keymap = {
          ["<C-e>"] = { "hide", "fallback" },
          ["<C-y>"] = { "fallback" },
          ["<enter>"] = { "select_and_accept", "fallback" },
          ["<C-k>"] = { "select_prev", "fallback" },
          ["<C-j>"] = { "select_next", "fallback" },
          ["<C-b>"] = { "scroll_documentation_up", "fallback" },
          ["<C-f>"] = { "scroll_documentation_down", "fallback" },
          ["<Tab>"] = { "snippet_forward", "fallback" },
          ["<S-Tab>"] = { "snippet_backward", "fallback" },
        },
        signature = { enabled = true },
      }
    end)
  end,
}
