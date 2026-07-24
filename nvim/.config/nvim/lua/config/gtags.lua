-- ============================================================================
-- GNU Global + Universal Ctags 的关系
-- ============================================================================
--
-- GNU Global 自身只内置支持少量语言（C/C++、Java、YACC、PHP、Assembly），
-- 但它提供了一套"插件解析器"（plug-in parser）机制来扩展语言支持。
-- Universal Ctags 就是最常用的插件解析器之一。
--
-- 工作流程：
--
--   1. gutentags 用 fd 列出项目中的源文件，写入 gtags.files
--   2. gtags 读取 gtags.files，根据文件扩展名匹配 langmap（定义在 gtags.conf
--      或 ~/.globalrc 中），决定用哪个解析器处理
--   3. 对于 langmap 中已有的语言（如 Go、Rust、Python、JavaScript 等），
--      Global 调用 Universal Ctags 的插件库（$ctagslib，即
--      universal-ctags.la）来解析文件
--   4. ctags 解析出符号信息（函数、类、接口、变量等）返回给 Global
--   5. Global 将这些信息构建成自己的 GTAGS（符号定义）、GRTAGS（符号引用）
--      和 GPATH（文件路径）数据库
--   6. 编辑器通过 gutentags_plus、vim-preview 等插件查询这些数据库，
--      实现 :Gtags / :Go / 预览窗口等导航功能
--
-- 选择哪个解析器通过 GTAGSLABEL 控制，可选值定义在 gtags.conf 中：
--   - native         仅 Global 内置解析器（只支持少数语言）
--   - universal-ctags 使用 Universal Ctags（最快，tag 类型最丰富）
--   - pygments       使用 Pygments 解析器（Python 实现，较慢）
--   - native-pygments 内置优先，没有的 fallback 到 Pygments
--
-- 本配置选择了 universal-ctags，因为：
--   ① 纯 C 实现，解析速度最快
--   ② 支持的語言最广（50+ 种语言）
--   ③ 每种语言的 tag kind 最丰富（函数、类、接口、属性、变量等）
--   ④ 社区活跃，持续更新
--
-- 但 Universal Ctags 对 Zig 的支持尚未加入上游。如需 Zig 支持，
-- 需要安装 Pygments（pip3 install pygments）并切换到
-- GTAGSLABEL=pygments 或 native-pygments，但速度会明显下降。
--
-- ============================================================================

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
-- ignore files in `.gitignore`
-- Avoid having a large database
vim.g.gutentags_file_list_command = "fd -e c -e h -e cpp -e cc -e go -e rs -e zig -e py -e lua -e ts -e tsx -e js -e jsx -e mjs"
-- for debug
vim.g.gutentags_trace = 0

-- 使用 universal-ctags
local extra_tags = { "--fields=+niazS", "--extras=+q" }
-- C/C++: enable prototypes (+p) and external symbols (+x)
table.insert(extra_tags, "--c++-kinds=+px")
table.insert(extra_tags, "--c-kinds=+px")
-- Go: packages, functions, constants, types, variables, structs, interfaces, members
table.insert(extra_tags, "--kinds-Go=+pfcntvsima")
-- Rust: modules, structs, traits, impls, functions, enums, type-aliases, macros, methods, constants
table.insert(extra_tags, "--kinds-Rust=+nsictfgMmePC")
-- JavaScript: functions, classes, methods, properties, constants, globals, generators, fields
table.insert(extra_tags, "--kinds-JavaScript=+fcmpCvgGMS")
-- Lua: functions
table.insert(extra_tags, "--kinds-Lua=+f")
-- Python: classes, functions, members, variables, modules
table.insert(extra_tags, "--kinds-Python=+cfmvIi")
-- TypeScript: functions, classes, interfaces, enums, methods, namespaces, properties, variables, constants
table.insert(extra_tags, "--typescript-kinds=+fcimenpvlC")
-- Map .tsx to TypeScript parser (not built-in by default)
table.insert(extra_tags, "--map-TypeScript=+.tsx")
table.insert(extra_tags, "--output-format=e-ctags")
vim.g.gutentags_ctags_extra_args = extra_tags

local modules = {}
if vim.fn.executable "ctags" then
  table.insert(modules, "ctags")
  if vim.fn.executable "gtags" and vim.fn.executable "gtags-cscope" then
    table.insert(modules, "gtags_cscope")
  end
end
vim.g.gutentags_modules = modules

if vim.fn.executable "gtags" and vim.fn.executable "gtags-cscope" then
  local utils = require "utils"
  -- Use personal globalrc that inherits from universal-ctags and adds TypeScript
  local globalrc = vim.fn.expand "~/.globalrc"
  if vim.fn.filereadable(globalrc) == 1 then
    vim.env.GTAGSCONF = globalrc
  else
    -- Fallback: use system gtags.conf
    if utils.is_mac() then
      if vim.fn.filereadable "/opt/homebrew/share/gtags/gtags.conf" == 1 then
        vim.env.GTAGSCONF = "/opt/homebrew/share/gtags/gtags.conf"
      end
    end
  end
  -- Use custom universal-ctags-ts label (inherits system universal-ctags + adds TypeScript)
  -- Defined in ~/.globalrc
  vim.env.GTAGSLABEL = "universal-ctags-ts"
end
