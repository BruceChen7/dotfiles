--  signify sign config
vim.g.signify_sign_add = '+'
vim.g.signify_sign_delete = '-'
vim.g.signify_sign_change = '~'
vim.g.signify_sign_delete_first_line = '‾'
vim.g.signify_sign_changedelete = vim.g.signify_sign_change
vim.g.signify_vcs_list = {'git', 'svn'}

vim.g.signify_vcs_cmds = {
	git = "git diff --no-color --diff-algorithm=histogram --no-ext-diff -U0 -- %f"
}
