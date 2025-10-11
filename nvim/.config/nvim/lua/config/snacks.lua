require("snacks").setup {
  bigfile = { enabled = false },
  picker = { enabled = true },
  image = { enabled = true },
  terminal = { enabled = true },
}

-- 加载 snacks 目录下的快捷键配置
local snacks_dir = vim.fn.stdpath("config") .. "/lua/config/snacks"
if vim.fn.isdirectory(snacks_dir) == 1 then
  for _, file in ipairs(vim.fn.readdir(snacks_dir)) do
    if file:match("%.lua$") and file ~= "init.lua" then
      local module_name = "config.snacks." .. file:gsub("%.lua$", "")
      local module = require(module_name)
      if module.setup then
        module.setup()
      end
    end
  end
end
