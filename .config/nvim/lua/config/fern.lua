-- fern.vim
u = require "util"
u.map("n", "ne", ":Fern .  -reveal=% <CR>")
u.map("n", "nE", ":Fern . -opener=vsplit -reveal=% <CR>")
u.map("n", "nc", ":Fern %:h  -reveal=% <CR>")
u.map("n", "nC", ":Fern %:h -opener=vsplit -reveal=% <CR>")

vim.cmd [[
    function! InitFern() abort
        " Define NERDTree like mappings
        nmap <buffer> o <Plug>(fern-action-open:edit)
        nmap <buffer> go <Plug>(fern-action-open:edit)<C-w>p
        nmap <buffer> t <Plug>(fern-action-open:tabedit)
        nmap <buffer> T <Plug>(fern-action-open:tabedit)gT
        nmap <buffer> i <Plug>(fern-action-open:split)
        nmap <buffer> gi <Plug>(fern-action-open:split)<C-w>p
        nmap <buffer> s <Plug>(fern-action-open:vsplit)
        nmap <buffer> gs <Plug>(fern-action-open:vsplit)<C-w>p
        nmap <buffer> ma <Plug>(fern-action-new-path)
        nmap <buffer> P gg
        nmap <buffer> as <Plug>(fern-action-open:select)

        nmap <buffer> C <Plug>(fern-action-enter)
        nmap <buffer> u <Plug>(fern-action-leave)
        nmap <buffer> r <Plug>(fern-action-reload)
        nmap <buffer> R gg<Plug>(fern-action-reload)<C-o>
        nmap <buffer> cd <Plug>(fern-action-cd)
        nmap <buffer> CD gg<Plug>(fern-action-cd)<C-o>

        nmap <buffer> I <Plug>(fern-action-hidden)

        nmap <buffer> q :<C-u>quit<CR>
    endfunction

    augroup fern-custom
       autocmd! *
       autocmd FileType fern call InitFern()
    augroup END
]]
