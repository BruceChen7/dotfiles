local wilder = require "wilder"
wilder.setup { modes = { ":", "/", "?" }, next_key = "<c-j>", previous_key = "<c-k>" }
wilder.set_option(
  "renderer",
  wilder.popupmenu_renderer {
    highlighter = wilder.basic_highlighter(),
    left = { " ", wilder.popupmenu_devicons() },
    right = { " ", wilder.popupmenu_scrollbar() },
  }
)

wilder.set_option("pipeline", {
  wilder.branch(
    wilder.python_file_finder_pipeline {
      -- to use ripgrep : {'rg', '--files'}
      -- to use fd      : {'fd', '-tf'}
      file_command = { "rg", "--files" },
      -- to use fd      : {'fd', '-td'}
      dir_command = { "fd", "-td" },
      -- use {'cpsm_filter'} for performance, requires cpsm vim plugin
      -- found at https://github.com/nixprime/cpsm
      filters = { "fuzzy_filter", "difflib_sorter" },
    },
    wilder.cmdline_pipeline(),
    wilder.python_search_pipeline()
  ),
})
