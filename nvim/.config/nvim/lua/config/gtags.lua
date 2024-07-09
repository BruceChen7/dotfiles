vim.g.gutentags_project_root = { ".root", ".git", ".hg" }
vim.g.gutentags_ctags_tagfile = ".tags"
vim.g.gutentags_cache_dir = vim.fn.expand "~/.cache/tags"
-- Create a scheduled task to delete if the last modified time is older
-- than the specified time

local timer = vim.uv.new_timer()
timer:start(
  300 * 1000,
  300 * 1000,
  vim.schedule_wrap(function()
    local now = os.time()
    local path = vim.g.gutentags_cache_dir
    local files = vim.fn.globpath(path, "*", true, true)
    for _, file in ipairs(files) do
      local attributes = vim.loop.fs_stat(file)
      if attributes and (attributes.type == "file" or attributes.type == "directory") then
        local file_age = now - attributes.mtime.sec
        if file_age > 3600 * 24 * 7 then
          print("file: " .. file)
          -- delete file or directory
          -- using rm -rf
          vim.fn.system("rm -rf " .. file)
        end
      end
    end
    -- 遍历path下的所有文件, 删除超过max_age秒的文件
  end)
)

-- 禁止 gutentags 自动链接 gtags 数据库
vim.g.gutentags_auto_add_gtags_cscope = 0
vim.g.gutentags_define_advanced_commands = 1
-- ignore fiels in `.gitignore`
-- Avoid having a large database
vim.g.gutentags_file_list_command = "fd -e c -e h -e cpp -e cc -e go -e py -e lua"
-- for debug
vim.g.gutentags_trace = 0

-- vim.g.gutentags_cscope_build_inverted_index_maps = 1
-- vim.g.gutentags_ctags_extra_args = { "--fields=+niazS", "--extras=+q", "--c++-kinds=+px", "--c-kinds=+px" }
-- 使用 universal-ctags 的话需要下面这行，请反注释
local extra_tags = { "--fields=+niazS", "--extras=+q", "--c++-kinds=+px", "--c-kinds=+px" }
table.insert(extra_tags, "--output-format=e-ctags")
vim.g.gutentags_ctags_extra_args = extra_tags

local modules = {}
if vim.fn.executable "ctags" then
  table.insert(modules, "ctags")
  if vim.fn.executable "gtags" and vim.fn.executable "gtags-cscope" then
    table.insert(modules, "gtags_cscope")
  end
end
-- table.insert(modules, "cscope_maps")
-- table.insert(modules, "gtags_cscope")
vim.g.gutentags_modules = modules

if vim.fn.executable "gtags" and vim.fn.executable "gtags-cscope" then
  vim.env.GTAGSCONF = "/usr/share/gtags/gtags.conf"
  vim.env.GTAGSLABEL = "native-pygments"
  -- If it is neovim in mac
  local utils = require "utils"
  if utils.is_mac() then
    vim.env.GTAGSCONF = "/usr/local/share/gtags/gtags.conf"
  end
end
