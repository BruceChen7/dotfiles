local U = require "util"
-- leaderf config
-- CTRL+p 打开文件模糊匹配
vim.g.Lf_ShortcutF = "<C-p>"
-- ALT+n 打开 buffer 模糊匹配
vim.g.Lf_ShortcutB = "<m-n>"
-- " 显示绝对路径
vim.g.Lf_ShowRelativePath = 0
-- 显示图标
vim.g.Lf_ShowDevIcons = 1
-- " 隐藏帮助
vim.g.Lf_HideHelp = 0

vim.g.Lf_MruMaxFiles = 2048
-- " 如何识别项目目录，从当前文件目录向父目录递归知道碰到下面的文件/目录
vim.g.Lf_RootMarkers = { ".project", ".root", ".svn", ".git" }
vim.g.Lf_WorkingDirectoryMode = "Ac"
vim.g.Lf_WindowHeight = 0.40
vim.g.Lf_CacheDirectory = vim.fn.expand "~/.vim/cache"
vim.g.Lf_PreviewResult = { Function = 0, BufTag = 0 }
vim.g.Lf_MruFileExclude = { "*.so", "*.exe", "*.py[co]", "*.sw?", "~$*", "*.bak", "*.tmp", "*.dll" }
vim.g.Lf_StlColorscheme = "powerline"
vim.g.Lf_StlSeparator = { left = "", right = "", font = "" }
vim.g.Lf_WildIgnore = {
  dir = { ".svn", ".git", ".hg" },
  file = { "*.sw?", "~$*", "*.bak", "*.exe", "*.o", "*.so", "*.py[co]" },
}

-- ALT+m 打开最近使用的文件 MRU，进行模糊匹配
U.map("n", "<m-m>", ":LeaderfMru<cr>")
U.map("n", "<m-p>", ":LeaderfFunction<cr>")
-- " ALT+SHIFT+p 打开 tag 列表，i 进入模糊匹配，ESC退出
U.map("n", "<m-P>", ":LeaderfBufTag<cr>")
-- ALT+n 打开 buffer 列表进行模糊匹配
U.map("n", "<m-n>", ":LeaderfBuffer<cr>")
-- " ALT+t 全局 tags 模糊匹配
U.map("n", "<m-t>", ":LeaderfTag<cr>")
U.map("n", "<c-p>", ":LeaderfFile<cr>")

vim.cmd [[
    noremap <space>lf :<C-U><C-R>=printf("Leaderf! rg -e %s ", expand("<cword>"))<CR>
]]

-- leaderf config
