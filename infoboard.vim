if exists('g:loaded_infoboard')
    finish
endif
let g:loaded_infoboard = 1
let s:infoboard_agent = v:null
let s:infoboard_winid = -1
let s:infoboard_bufnr_list = []
let s:infoboard_default_bufnr = -1
let s:infoname_to_bufnr_map = {}
let s:infoboard_tabline = ""
let s:infoboard_start_lineno = 2
let s:infoboard_highlight_matchid = -1
let s:infoboard_highlight_matchids = []
let s:infoboard_cur_bufnr = -1
let s:current_buffer_start_col = -1
let s:current_buffer_end_col = -1

function! s:Error(msg)
    echohl ErrorMsg
    echom a:msg
    echohl None
endfunction

let s:state_stack = []
function! s:PushCurState()
    call add(s:state_stack, { 'winid': win_getid(), 'pos': getcurpos() })
endfunction

function! s:ResumeState()
    let l:state = remove(s:state_stack, '$')
    call win_gotoid(l:state['winid'])
    call setpos('.', l:state['pos'])
endfunction

function! s:GotoWinBuf(winid, bufnr)
    call s:PushCurState()
    call win_gotoid(a:winid)
    execute 'buffer ' . a:bufnr
    if a:winid == s:infoboard_winid
        setlocal nonumber
    endif
endfunction

" autocmd BufEnter * echom "enter buffer:" . bufnr()
" autocmd BufLeave * echom "leave buffer:" . bufnr()
" autocmd WinEnter * echom "enter window:" . win_getid()
" autocmd WinLeave * echom "leave window:" . win_getid()

highlight InfoboardCurrent guibg=#5c5c92 ctermbg=60 guifg=#ff8700 ctermfg=214
highlight InfoboardBackground guibg=#5c5c5c ctermbg=60 guifg=#d0d0d0 ctermfg=252

function! s:UpdateInfoboardBufferline()
    let l:bufferline = 'Infoboards >> '
    let l:buffer_cnt = len(s:infoboard_bufnr_list)
    let l:window_width = winwidth(0) - len('Infoboards >> ')
    let l:current_buffer_name = fnamemodify(bufname(s:infoboard_cur_bufnr), ':r:t')
    let l:max_current_buffer_width = min([len(l:current_buffer_name) + 3, float2nr(l:window_width * 0.5)])
    let l:max_other_buffer_width = float2nr((l:window_width - l:max_current_buffer_width) / max([1, l:buffer_cnt-1]))
    let l:max_other_buffer_width = max([l:max_other_buffer_width, 1])
    
    let l:current_buffer_start_col = -1
    let l:current_buffer_end_col = -1
    for i in s:infoboard_bufnr_list
        if !bufexists(i) 
            continue 
        endif
        let l:buffer_name = fnamemodify(bufname(i), ':r:t')
        let l:display_name = ''
        if i == s:infoboard_cur_bufnr
            let l:current_buffer_start_col = len(l:bufferline) + 2
            let l:display_name = strpart(l:buffer_name, 0, l:max_current_buffer_width - 3)
            let l:current_buffer_end_col = l:current_buffer_start_col + len(l:display_name)
        else
            let l:display_name = strpart(l:buffer_name, 0, l:max_other_buffer_width - 1)
        endif
        let l:bufferline .= ' ' . l:display_name . ' '
        if i != s:infoboard_bufnr_list[len(s:infoboard_bufnr_list) - 1]
            let l:bufferline .= '|'
        endif
    endfor
    let l:padding_len = max([winwidth(0) - len(l:bufferline), 0])
    let s:infoboard_tabline = l:bufferline . repeat(' ', padding_len)
    let s:current_buffer_start_col = l:current_buffer_start_col
    let s:current_buffer_end_col = l:current_buffer_end_col
endfunction

" this function must be call inside the infoboard
function! s:HightLight()
    for id in s:infoboard_highlight_matchids
        call matchdelete(id)
    endfor
    let s:infoboard_highlight_matchids = [] 
    let l:pattern = '\%1l\%>' . (s:current_buffer_start_col-1) . 'c\%<' . (s:current_buffer_end_col+1) . 'c'
    let s:infoboard_highlight_matchid = matchadd("InfoboardCurrent", l:pattern, 100)
    call add(s:infoboard_highlight_matchids, s:infoboard_highlight_matchid)
    let l:pattern = '\%1l\%>' . 0 . 'c\%<' . len(s:infoboard_tabline) . 'c'
    let s:infoboard_highlight_matchid = matchadd("InfoboardBackground", l:pattern, 10)
    call add(s:infoboard_highlight_matchids, s:infoboard_highlight_matchid)
endfunction

" this function must be called using noautocmd keyword
function! s:UpdateBufferList()
    " call s:GotoWinBuf(s:infoboard_winid, s:infoboard_cur_bufnr)
    call s:UpdateInfoboardBufferline()
    call setbufline(s:infoboard_cur_bufnr, 1, s:infoboard_tabline)
    " if the infoboard is not opened yet, don't highlight it
    if s:infoboard_winid != -1
        call s:HightLight()
    endif
    " call s:ResumeState()
endfunction

function! s:UpdateBufferListWhenEnterBuf()
    if index(s:infoboard_bufnr_list, bufnr()) == -1
        return
    endif
    let s:infoboard_cur_bufnr = bufnr()
    if s:infoboard_winid == -1
        return
    endif
    noautocmd call s:UpdateBufferList()
endfunction

" Create a new infoboard window
function! s:CreateInfoboardWindow()
    call s:PushCurState()

    execute 'belowright ' . float2nr(&lines * 0.25) . 'new'
    let s:infoboard_winid = win_getid()
    let s:infoboard_default_bufnr = bufnr()
    setlocal bufhidden=hide
    setlocal buftype=nofile
    setlocal nobuflisted
    setlocal wrap
    setlocal noswapfile
    setlocal nospell
    setlocal nolist
    setlocal nocursorline
    setlocal nofoldenable
    setlocal nonumber
    " it might be called from ToggleInfoboard/InfoboardRegister, so we need to load all
    " registered buffer if needed
    for bufnr in s:infoboard_bufnr_list
        noautocmd call win_execute(s:infoboard_winid, 'buffer ' . bufnr)
        call setbufvar(bufnr, '&number', 0) 
    endfor
    if len(s:infoboard_bufnr_list) != 0
        noautocmd call win_execute(s:infoboard_winid, 'bdelete ' . s:infoboard_default_bufnr)
        let s:infoboard_default_bufnr = -1
        noautocmd call s:UpdateBufferList()
    endif
    call s:ResumeState()
endfunction

" Initialize infoboard
" call s:CreateInfoboardWindow()

function! s:InfoboardUnRegister(source_name)
    if !has_key(s:infoname_to_bufnr_map, a:source_name)
        return
    endif
    let l:bufnr = s:infoname_to_bufnr_map[a:source_name]
    call remove(s:infoname_to_bufnr_map, a:source_name)
    let l:idx = index(s:infoboard_bufnr_list, l:bufnr)
    call remove(s:infoboard_bufnr_list, l:idx)
    if s:infoboard_winid == -1
        silent! noautocmd execute 'bdelete ' . l:bufnr 
        return
    elseif l:bufnr == s:infoboard_cur_bufnr
        noautocmd call s:SwitchToNextBuffer()  
    endif
    if l:bufnr == s:infoboard_cur_bufnr
        noautocmd call win_execute(s:infoboard_winid, 'close') 
        let s:infoboard_winid = -1
        let s:infoboard_cur_bufnr = -1
        let s:infoboard_highlight_matchids = []
    endif
    silent! noautocmd execute 'bdelete ' . l:bufnr
    call s:UpdateBufferList()
endfunction

function! s:InfoboardRegister(source_name)
    " return early if this name has been registered
    if has_key(s:infoname_to_bufnr_map, a:source_name)
        call s:Error(a:source_name . " has been registered")
        return
    endif
    " create a new buffer for this info source
    silent! let l:bufnr = bufadd(a:source_name)
    silent! call bufload(l:bufnr)
    call setbufvar(l:bufnr, '&bufhidden', 'hide')
    call setbufvar(l:bufnr, '&buftype', 'nofile')
    call setbufvar(l:bufnr, '&swapfile', 0)
    call setbufvar(l:bufnr, '&buflisted', 0)
    " record source name and bufnr
    let s:infoname_to_bufnr_map[a:source_name] = l:bufnr
    call add(s:infoboard_bufnr_list, l:bufnr)
    let s:infoboard_cur_bufnr = l:bufnr
    " create infoboard window if needed 
    if s:infoboard_winid == -1
        noautocmd call s:CreateInfoboardWindow()
    else
        noautocmd call win_execute(s:infoboard_winid, 'buffer ' . l:bufnr)
        noautocmd call setbufvar(l:bufnr, '&number', 0)
        noautocmd call s:GotoWinBuf(s:infoboard_winid, l:bufnr)
        noautocmd call s:UpdateBufferList()
        noautocmd call s:ResumeState()
    endif
    " delete the default buffer if needed 
    if s:infoboard_default_bufnr != -1
        noautocmd call win_execute(s:infoboard_winid, 'bdelete ' . s:infoboard_default_bufnr)
        let s:infoboard_default_bufnr = -1
    endif
endfunction

function! s:InfoboardClear(source_name)
    if !has_key(s:infoname_to_bufnr_map, a:source_name)
        call s:Error("cannot find infoboard for " . a:source_name)
        return
    endif
    let l:bufnr = s:infoname_to_bufnr_map[a:source_name]
    " noautocmd call s:GotoWinBuf(s:infoboard_winid, l:bufnr)
    noautocmd call deletebufline(l:bufnr, s:infoboard_start_lineno, '$')
    " noautocmd call s:ResumeState()
endfunction

function! s:InfoboardSetLine(source_name, lineno, msg)
    if !has_key(s:infoname_to_bufnr_map, a:source_name)
        call s:Error("cannot find infoboard for " . a:source_name)
        return
    endif
    let l:bufnr = s:infoname_to_bufnr_map[a:source_name]
    " noautocmd call s:GotoWinBuf(s:infoboard_winid, l:bufnr)
    if type(a:lineno) == type(0)
        noautocmd call setbufline(l:bufnr, a:lineno + s:infoboard_start_lineno - 1, a:msg)
    elseif a:lineno == "$" && line('$') > s:infoboard_start_lineno
        noautocmd call setbufline(l:bufnr, a:lineno, a:msg)
    else
        call s:Error("unsupport argument msg=" . a:lineno)
    endif
    " noautocmd call s:ResumeState()
endfunction

function! s:InfoboardInsertLine(source_name, lineno, msg)
    if !has_key(s:infoname_to_bufnr_map, a:source_name)
        call s:Error("cannot find infoboard for " . a:source_name)
        return
    endif
    let l:bufnr = s:infoname_to_bufnr_map[a:source_name]
    " noautocmd call s:GotoWinBuf(s:infoboard_winid, l:bufnr)
    if type(a:lineno) == type(0)
        noautocmd call appendbufline(l:bufnr, a:lineno + s:infoboard_start_lineno - 1, a:msg)
    elseif a:lineno == "$"
        noautocmd call appendbufline(l:bufnr, a:lineno, a:msg)
    else
        call s:Error("unsupport argument msg=" . a:lineno)
    endif
    " noautocmd call s:ResumeState()
endfunction


autocmd BufEnter * call s:UpdateBufferListWhenEnterBuf()

function! s:SwitchInfoboardBuffer(name)
    if has_key(s:infoname_to_bufnr_map, a:name) != 1
        call s:Error("cannot find info name:" . a:name)
        return
    endif
    if s:infoboard_cur_bufnr == s:infoname_to_bufnr_map[a:name]
        return
    endif
    if s:infoboard_winid == -1
        return
    endif
    noautocmd call s:GotoWinBuf(s:infoboard_winid, s:infoname_to_bufnr_map[a:name])
    let s:infoboard_cur_bufnr = s:infoname_to_bufnr_map[a:name]
    noautocmd call s:UpdateBufferList()
    noautocmd call s:ResumeState()
endfunction

function! s:SwitchToNextBuffer()
    if len(s:infoboard_bufnr_list) < 1 || s:infoboard_winid == -1
        return
    endif
    let l:next_bufnr_idx = index(s:infoboard_bufnr_list, s:infoboard_cur_bufnr)
    if l:next_bufnr_idx == -1
        let l:next_bufnr_idx = 0
    else
        let l:next_bufnr_idx += 1
        if l:next_bufnr_idx >= len(s:infoboard_bufnr_list)
            let l:next_bufnr_idx = 0
        endif
    endif
    let l:next_bufnr = s:infoboard_bufnr_list[l:next_bufnr_idx]
    if l:next_bufnr == s:infoboard_cur_bufnr
        return
    endif
    noautocmd call s:GotoWinBuf(s:infoboard_winid, l:next_bufnr)
    let s:infoboard_cur_bufnr = l:next_bufnr
    noautocmd call s:UpdateBufferList()
    noautocmd call s:ResumeState()
endfunction

function! s:ToggleInfoboard()
    if s:infoboard_winid != -1
        noautocmd call win_execute(s:infoboard_winid, 'close')
        let s:infoboard_winid = -1
        let s:infoboard_highlight_matchids = []
    else
        noautocmd call s:CreateInfoboardWindow()
    endif
endfunction

command! -nargs=1 SwitchInfo call s:SwitchInfoboardBuffer(<q-args>)
command! NextInfo call s:SwitchToNextBuffer()
command! ToggleInfoboard call s:ToggleInfoboard()

function! s:CreateInfoboardAgent()
    let l:obj = {}

    function! l:obj.RegisterInfoSource(source_name) dict
        call s:InfoboardRegister(a:source_name)
    endfunction

    function! l:obj.UnRegisterInfoSource(source_name) dict
        call s:InfoboardUnRegister(a:source_name)
    endfunction

    function! l:obj.ClearInfoboard(source_name) dict
        call s:InfoboardClear(a:source_name)
    endfunction

    function! l:obj.SetLine(source_name, lineno, msg) dict
        call s:InfoboardSetLine(a:source_name, a:lineno, a:msg)
    endfunction

    function! l:obj.InsertLine(source_name, lineno, msg) dict
        call s:InfoboardInsertLine(a:source_name, a:lineno, a:msg)
    endfunction
    return l:obj
endfunction

function! GetInfoboardAgent()
    return s:infoboard_agent
endfunction

let s:infoboard_agent = s:CreateInfoboardAgent()

nnoremap <leader>ni :NextInfo<CR>

