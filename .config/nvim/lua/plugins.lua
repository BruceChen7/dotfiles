local execute = vim.api.nvim_command
local fn = vim.fn
-- /Users/username/.local/share/nvim/site/pack/packer/start/packer.nvim
local packer_install_dir = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
local is_linux = true

if is_linux then
  plug_url_format = 'https://hub.fastgit.org/%s'
else
  plug_url_format = 'https://github.com/%s'
end

local packer_repo = string.format(plug_url_format, 'wbthomason/packer.nvim')
local install_cmd = string.format('10split |term git clone --depth=1 %s %s', packer_repo, packer_install_dir)

if fn.empty(fn.glob(packer_install_dir)) > 0 then
  vim.api.nvim_echo({{'Installing packer.nvim', 'Type'}}, true, {})
  -- execute 'packadd packer.nvim'
end

vim.cmd [[packadd packer.nvim]]

-- https://github.com/wbthomason/packer.nvim#requirements
return require('packer').startup(function()
  -- Packer can manage itself
  use 'wbthomason/packer.nvim'
  use 'bronson/vim-trailing-whitespace'
  use 'tpope/vim-fugitive'
  use 'lambdalisue/fern.vim'
  use 'skywind3000/vim-preview'
  use 'skywind3000/vim-quickui'
  use 'skywind3000/asynctasks.vim'
  use 'skywind3000/asyncrun.vim'
  use 'Yggdroot/LeaderF'
  use 'neovim/nvim-lspconfig'
  use 'hrsh7th/nvim-cmp' -- Autocompletion plugin
  use 'hrsh7th/cmp-nvim-lsp' -- LSP source for nvim-cmp
  use 'saadparwaiz1/cmp_luasnip' -- Snippets source for nvim-cmp
  use 'L3MON4D3/LuaSnip' -- Snippets plugin
end)

-- vim.api.nvim_exec([[
--     function! s:init_fern() abort
--         " Define NERDTree like mappings
--         nmap <buffer> o <Plug>(fern-action-open:edit)
--         nmap <buffer> go <Plug>(fern-action-open:edit)<C-w>p
--         nmap <buffer> t <Plug>(fern-action-open:tabedit)
--         nmap <buffer> T <Plug>(fern-action-open:tabedit)gT
--         nmap <buffer> i <Plug>(fern-action-open:split)
--         nmap <buffer> gi <Plug>(fern-action-open:split)<C-w>p
--         nmap <buffer> s <Plug>(fern-action-open:vsplit)
--         nmap <buffer> gs <Plug>(fern-action-open:vsplit)<C-w>p
--         nmap <buffer> ma <Plug>(fern-action-new-path)
--         nmap <buffer> P gg
--         nmap <buffer> as <Plug>(fern-action-open:select)

--         nmap <buffer> C <Plug>(fern-action-enter)
--         nmap <buffer> u <Plug>(fern-action-leave)
--         nmap <buffer> r <Plug>(fern-action-reload)
--         nmap <buffer> R gg<Plug>(fern-action-reload)<C-o>
--         nmap <buffer> cd <Plug>(fern-action-cd)
--         nmap <buffer> CD gg<Plug>(fern-action-cd)<C-o>

--         nmap <buffer> I <Plug>(fern-action-hidden)

--         nmap <buffer> q :<C-u>quit<CR>
--     endfunction

--     noremap ne :Fern .  -reveal=% <CR>
--     noremap nE :Fern . -opener=vsplit -reveal=% <CR>
--     " noremap nc :Fern %:h -drawer -reveal=% -toggle <CR>
--     " current buffer directory
--     noremap nc :Fern %:h  -reveal=% <CR>
--     noremap nC :Fern %:h -opener=vsplit -reveal=% <CR>
--     augroup fern-custom
--         autocmd! *
--         autocmd FileType fern call s:init_fern()
--     augroup END

-- ]], false)
