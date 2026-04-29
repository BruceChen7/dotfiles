local pack = require "core.pack"
local gh = pack.github

return {
  name = "tools",
  specs = {
    { src = gh "keaising/im-select.nvim" },
  },
  setup = function()
    pack.safe_call("im-select", function()
      pack.packadd "im-select.nvim"
      local utils = require "utils"
      local function get_im_select()
        if not utils.is_mac() then
          return "keyboard-us"
        end
        return "com.apple.keylayout.ABC"
      end

      local function get_default_command()
        if not utils.is_mac() then
          return "fcitx5-remote"
        end
        if vim.fn.executable "macism" == 0 then
          vim.notify "macism not installed"
          return nil
        end
        return "macism"
      end

      require("im_select").setup {
        default_im_select = get_im_select(),
        default_command = get_default_command(),
        set_default_events = { "InsertLeave", "CmdlineLeave" },
        set_previous_events = { "InsertEnter" },
        keep_quiet_on_no_binary = false,
        async_switch_im = true,
      }
    end)
  end,
}
