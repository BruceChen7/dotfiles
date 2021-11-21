do
  local ok, _ = pcall(require, 'impatient')
  if not ok then
    error("could not call impatient")
  end
end
require("util")
require("util.packer")
require("buildin")
require("options")
require("plugins")
require("keymaps")
require("style")
require("lsp")
