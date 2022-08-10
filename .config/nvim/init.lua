-- for speed up nvim load
do
  local ok, _ = pcall(require, "impatient")
  if not ok then
    print "could not call impatient"
  end
end

require "util"
require "util.packer"
require "buildin"
require "options"
require "plugins"
require "keymaps"
require "style"
require "lsp"
