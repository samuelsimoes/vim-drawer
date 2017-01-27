if !&hid
  echohl WarningMsg
  echom "VimDrawer requires 'hidden' option enabled!"
  echohl None

  finish
endif

let s:dot_file_path = getcwd() . "/.vim-drawer.vim"

if filereadable(s:dot_file_path)
  exe "source " . s:dot_file_path
end

let s:all_vim_drawer_lists = []
let s:auto_classification = 1

function! <SID>get_spaces()
  return exists("g:vim_drawer_spaces") ? g:vim_drawer_spaces : []
endfunction

augroup VimDrawerGroup
  autocmd!
  au BufEnter * call <SID>add_tab_buffer()
  au BufDelete * call <SID>remove_tab_buffer()
augroup END

command! VimDrawer :call <SID>open_vim_drawer()
command! VimDrawerAutoClassificationToggle :call <SID>toggle_vim_drawer_auto_classification()

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

function! <SID>toggle_vim_drawer_auto_classification()
  let s:auto_classification = !s:auto_classification
endfunction

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

function! <SID>match_space_tab(file_path)
  let l:tabs = []

  for tab_id in range(1, tabpagenr("$"))
    call add(l:tabs, gettabvar(tab_id, "tablabel"))
  endfor

  let l:tab_name = 0
  let l:tab_index = 0
  " VimL sucks a lot so I can't check at the space name to check if it exists
  let l:existing_space = 0
  let l:spaces = <SID>get_spaces()

  for space in spaces
    if strlen(matchstr(a:file_path, space[1]))
      let l:tab_index = (index(tabs, space[0]) + 1)
      let l:tab_name = space[0]
      let l:existing_space = 1
      break
    end
  endfor

  return { "existing_space": existing_space, "name": tab_name, "id": tab_index }
endfunction

function! <SID>add_tab_buffer()
  call <SID>setup_tab()

  let l:current_buffer_id = bufnr("%")
  let l:current_buffer_index = index(t:vim_drawer_list, current_buffer_id)
  let l:buffer_is_on_drawer = current_buffer_index != -1
  let l:this_buffer_is_vim_drawer = current_buffer_id == bufnr("VimDrawer")

  if buffer_is_on_drawer && (!exists("t:reorder_drawer") || t:reorder_drawer)
    call remove(t:vim_drawer_list, current_buffer_index)
    call insert(t:vim_drawer_list, current_buffer_id, 0)
  end

  if buffer_is_on_drawer || this_buffer_is_vim_drawer || !getbufvar(current_buffer_id, "&modifiable") || !getbufvar(current_buffer_id, "&buflisted")
    return
  end

  let l:current_buffer_name = bufname(current_buffer_id)
  let l:previous_buffer_id = bufnr("#")
  let l:current_tab_id = tabpagenr()

  if s:auto_classification
    let l:match_space_tab = <SID>match_space_tab(current_buffer_name)
    let l:must_create_tab = !match_space_tab["id"]
    let l:must_change_tab = match_space_tab["id"] != current_tab_id

    if match_space_tab["existing_space"] && (must_create_tab || must_change_tab)
      if previous_buffer_id == -1 || previous_buffer_id == current_buffer_id
        exec ":enew"
      else
        exec ":b " . previous_buffer_id
      endif

      if must_create_tab
        exec ":tab sb " . current_buffer_id
        call <SID>setup_tab()
        let t:tablabel = match_space_tab["name"]
        redraw!
      elseif  must_change_tab
        exec ":tabn " . match_space_tab["id"]
        exec ":b " . current_buffer_id
      end
    end
  end

  if index(t:vim_drawer_list, bufnr("%")) == -1
    call insert(t:vim_drawer_list, current_buffer_id, 0)
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
  setlocal modifiable
  setlocal noreadonly

  let l:to_back_line = line(".")

  exe "normal! gg\"_dG"

  let l:buftext = ""

  for buffer_id in t:vim_drawer_list
    let bufname = substitute(bufname(buffer_id), getcwd() . "/", "", "g")
    if !strlen(bufname)
      let bufname = "--Unsaved Buffer--"
    end
    let buftext .= bufname . "\n"
  endfor

  silent! put! =buftext

  exe "normal! G\"_dd"

  exe ":" . to_back_line

  setlocal nomodifiable
  setlocal readonly
endfunction

function! <SID>set_up_buffer()
  call <SID>render_list()

  setlocal noshowcmd
  setlocal noswapfile
  setlocal buftype=nofile
  setlocal bufhidden=delete
  setlocal nobuflisted
  setlocal nowrap
  setlocal cursorline

  exe (index(t:vim_drawer_list, t:current_buffer_id) + 1)

  noremap <silent><buffer> <CR> :call<SID>open_buffer()<CR>
  noremap <silent><buffer><nowait> o :call<SID>open_buffer()<CR>
  noremap <silent><buffer> q :bd!<CR>
  noremap <silent><buffer><nowait> c :call<SID>close_buffer()<CR>
  noremap <silent><buffer><nowait> <space> :call<SID>preview_buffer()<CR>
endfunction

function! <SID>close_buffer()
  let l:current_buffer_id = bufnr("#")
  let l:buffer_position = (line(".") - 1)
  let l:buffer_id = get(t:vim_drawer_list, buffer_position)

  if getbufvar(buffer_id, "&mod")
    let l:confirmation = input("This buffer has unsaved modifications, do you really want close? (y/n): ")

    if confirmation == "y"
      exec ":bd! " . buffer_id
    else
      return
    end
  else
    exec ":bd " . buffer_id
  end

  let l:drawer_is_empty = len(t:vim_drawer_list) == 0
  let l:only_vim_drawer_opened = winnr("$") == 1

  if drawer_is_empty
    exec ":bd"
  elseif only_vim_drawer_opened
    exec ":b " . get(t:vim_drawer_list, 0)
    call <SID>open_vim_drawer()
  else
    call <SID>render_list()
  end
endfunction

function! <SID>preview_buffer()
  let t:reorder_drawer = 0
  let l:buffer_position = (line(".") - 1)

  exe "wincmd p"

  exec ":b " . get(t:vim_drawer_list, buffer_position)

  exe "wincmd p"
endfunction

function! <SID>open_buffer()
  let t:reorder_drawer = 1
  let l:buffer_position = (line(".") - 1)
  let l:buflistnr = bufnr("VimDrawer")

  exe "wincmd p"

  exec ":b " . get(t:vim_drawer_list, buffer_position)

  exec ":bd! " . buflistnr
endfunction
