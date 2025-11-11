local fyler = require "fyler"

fyler.setup {
  hooks = {
    -- function(path) end
    on_delete = nil,
    -- function(src_path, dst_path) end
    on_rename = nil,
    -- function(hl_groups, palette) end
    on_highlight = nil,
  },
  integrations = {
    icon = "mini_icons",
  },
  views = {
    finder = {
      -- Close explorer when file is selected
      close_on_select = true,
      -- Auto-confirm simple file operations
      confirm_simple = false,
      -- Replace netrw as default explorer
      default_explorer = true,
      -- Move deleted files/directories to the system trash
      delete_to_trash = true,
      -- Git status
      git_status = {
        enabled = true,
        symbols = {
          Untracked = "?",
          Added = "+",
          Modified = "*",
          Deleted = "x",
          Renamed = ">",
          Copied = "~",
          Conflict = "!",
          Ignored = "#",
        },
      },
      -- Icons for directory states
      icon = {
        directory_collapsed = nil,
        directory_empty = nil,
        directory_expanded = nil,
      },
      -- Indentation guides
      indentscope = {
        enabled = true,
        group = "FylerIndentMarker",
        marker = "│",
      },
      -- Key mappings
      mappings = {
        ["q"] = "CloseView",
        ["<CR>"] = "Select",
        ["o"] = "Select",
        ["<C-t>"] = "SelectTab",
        ["|"] = "SelectVSplit",
        ["-"] = "SelectSplit",
        ["u"] = "GotoParent",
        ["="] = "GotoCwd",
        ["."] = "GotoNode",
        ["#"] = "CollapseAll",
        ["<BS>"] = "CollapseNode",
      },
      -- Current file tracking
      follow_current_file = true,
      -- File system watching(includes git status)
      watcher = {
        enabled = true,
      },
      -- Window configuration
      win = {
        border = vim.o.winborder == "" and "single" or vim.o.winborder,
        buf_opts = {
          filetype = "fyler",
          syntax = "fyler",
          buflisted = false,
          buftype = "acwrite",
          expandtab = true,
          shiftwidth = 2,
        },
        kind = "replace",
        kinds = {
          float = {
            height = "70%",
            width = "70%",
            top = "10%",
            left = "15%",
          },
          replace = {},
          split_above = {
            height = "70%",
          },
          split_above_all = {
            height = "70%",
          },
          split_below = {
            height = "70%",
          },
          split_below_all = {
            height = "70%",
          },
          split_left = {
            width = "70%",
          },
          split_left_most = {
            width = "20%",
          },
          split_right = {
            width = "20%",
          },
          split_right_most = {
            width = "30%",
          },
        },
        win_opts = {
          concealcursor = "nvic",
          conceallevel = 3,
          cursorline = false,
          number = false,
          relativenumber = false,
          winhighlight = "Normal:FylerNormal",
          wrap = false,
        },
      },
    },
  },
}

vim.keymap.set("n", "nc", function()
  -- Toggle Fyler with optional settings
  fyler.toggle {
    kind = "split_left_most", -- (Optional) Use custom window layout
  }
end, { desc = "Toggle Fyler" })

vim.keymap.set("n", "nC", function()
  -- Toggle Fyler with optional settings
  fyler.open {
    kind = "split_right", -- (Optional) Use custom window layout
  }
end, { desc = "Toggle Fyler" })
