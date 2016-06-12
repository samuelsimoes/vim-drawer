let s:dot_file_path = getcwd() . "/.vim-drawer.vim"

if filereadable(s:dot_file_path)
  exe "source " . s:dot_file_path
end

let s:all_vim_drawer_lists = []

function! <SID>get_spaces()
  return exists("g:vim_drawer_spaces") ? g:vim_drawer_spaces : {}
endfunction

augroup VimDrawerGroup
  autocmd!
  au BufEnter * call <SID>add_tab_buffer()
  au BufDelete * call <SID>remove_tab_buffer()
augroup END

command! VimDrawer :call <SID>open_vim_drawer()

function! VimDrawerTabLabel(tab_id)
  return gettabvar(a:tab_id, "tablabel")
endfunction

function! VimDrawerTabLine()
  let last_tab_id = tabpagenr("$")
  let current_tab_id = tabpagenr()
  let tabline = ""

  for tab_id in range(1, last_tab_id)
    let winnr = tabpagewinnr(tab_id)
    let buflist = tabpagebuflist(tab_id)
    let bufnr = buflist[winnr - 1]
    let bufname = bufname(bufnr)
    let title = VimDrawerTabLabel(tab_id)

    let tabline .= "%" . tab_id . "T"
    let tabline .= (tab_id == current_tab_id ? "%#TabLineSel#" : "%#TabLine#")
    let tabline .= " " . tab_id . " "

    let tabline .= title . " "
  endfor

  let tabline .= "%#TabLineFill#%T"

  if last_tab_id > 1
    let tabline .= "%="
    let tabline .= "%#TabLine#%999XX"
  endif

  return tabline
endfunction

if exists("+showtabline")
  set tabline=%!VimDrawerTabLine()
endif

if has("gui_running") && (&go =~# "e")
  set guitablabel=%{VimDrawerTabLabel(tabpagenr())}
  au BufEnter * set guitablabel=%{VimDrawerTabLabel(tabpagenr())}
end

function! <SID>remove_tab_buffer()
  let removed_buffer_id = expand("<abuf>")

  for vim_drawer_list in s:all_vim_drawer_lists
    for buffer_id in vim_drawer_list
      if buffer_id == removed_buffer_id
        call remove(vim_drawer_list, index(vim_drawer_list, buffer_id))
      end
    endfor
  endfor
endfunction

function! <SID>setup_tab()
  if !exists("t:vim_drawer_list")
    let t:vim_drawer_list = []
    call add(s:all_vim_drawer_lists, t:vim_drawer_list)
  end
endfunction

function! <SID>add_tab_buffer()
  let current_buffer_id = bufnr("%")
  let vim_drawer_buffer_id = bufnr("VimDrawer")

  call <SID>setup_tab()

  if index(t:vim_drawer_list, current_buffer_id) != -1 || current_buffer_id == vim_drawer_buffer_id || !getbufvar(current_buffer_id, "&modifiable") || !getbufvar(current_buffer_id, "&buflisted")
    return
  end

  let l:current_buffer_id = bufnr("%")
  let l:current_buffer_name = bufname(current_buffer_id)
  let l:previous_buffer_id = bufnr("#")
  let l:current_tab_id = tabpagenr()

  let l:tabs = []

  for tab_id in range(1, tabpagenr("$"))
    call add(l:tabs, gettabvar(tab_id, "tablabel"))
  endfor

  let l:spaces = <SID>get_spaces()

  for space_name in keys(spaces)
    if strlen(matchstr(current_buffer_name, spaces[space_name]))
      let l:tab_index = index(l:tabs, space_name)

      if tab_index == -1
        let l:tab_index = (current_tab_id + 1)
        exec ":tabnew"
        let t:tablabel = space_name
        redraw!
      else
        let l:tab_index = (tab_index + 1)
      endif
    end
  endfor

  " there"s no space, so just let the process continues
  if exists("l:tab_index")
    exec ":tabn " . current_tab_id

    exec ":b " . previous_buffer_id

    exec ":tabn " . tab_index

    exec ":b " . current_buffer_id
  end

  call <SID>setup_tab()

  if index(t:vim_drawer_list, bufnr("%")) == -1
    call add(t:vim_drawer_list, current_buffer_id)
  end
endfunction

function! <SID>open_vim_drawer()
  let t:vim_drawer_start_window = winnr()
  let t:current_buffer_id = bufnr("%")
  exec "silent! new VimDrawer"
  silent! exe "wincmd J"
  silent! exe "resize 10"
  call <SID>set_up_buffer()
endfunction

function! <SID>render_list()
  let l:buftext = ""

  for buffer_id in t:vim_drawer_list
    let bufname = bufname(buffer_id)
    if !strlen(bufname)
      let bufname = "--Unsaved Buffer--"
    end
    let buftext .= bufname . "\n"
  endfor

  silent! put! =buftext

  exe "normal! Gdd"
endfunction

function! <SID>set_up_buffer()
  call <SID>render_list()

  setlocal noshowcmd
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal nowrap
  setlocal readonly

  exe (index(t:vim_drawer_list, t:current_buffer_id) + 1)

  noremap <silent><buffer> <CR> :call<SID>open_buffer()<CR>
  noremap <silent><buffer> q :bd!<CR>
endfunction

function! <SID>open_buffer()
  let l:buffer_position = (line(".") - 1)
  let l:buflistnr = bufnr("VimDrawer")

  exec ":bd! " . buflistnr

  exec ":b " . get(t:vim_drawer_list, buffer_position)
endfunction
