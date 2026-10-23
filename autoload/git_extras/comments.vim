" Review comments live in their own quickfix list, titled 'Review', so they
" don't mix with :Git difftool or grep results. Each entry is a repo path, a
" line (or range) on the branch side, and the comment. Saved as
" `path:line: comment` or `path:start-end: comment`, one per line. The
" list's context is the branch its unsaved comments are on, '' once saved.

let s:title = 'Review'

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'git-extras: ' . a:msg
  echohl None
endfunction

" The id of the 'Review' quickfix list, 0 if there is none
function! s:find_id() abort
  for l:nr in range(1, getqflist({'nr': '$'}).nr)
    let l:info = getqflist({'nr': l:nr, 'title': 1, 'id': 0})
    if l:info.title ==# s:title
      return l:info.id
    endif
  endfor
  return 0
endfunction

" The id of the 'Review' quickfix list, created if missing
function! s:list_id() abort
  let l:id = s:find_id()
  if l:id
    return l:id
  endif
  " Without 'items', ' ' would only retitle the current list
  call setqflist([], ' ', {'title': s:title, 'items': []})
  return getqflist({'nr': '$', 'id': 0}).id
endfunction

function! s:items() abort
  return getqflist({'id': s:list_id(), 'items': 1}).items
endfunction

" The current buffer's path relative to the work tree: a file, or a
" fugitive:// object (a commit's or the index's version of one)
function! s:repo_path() abort
  let l:worktree = FugitiveWorkTree()
  let l:path = FugitivePath(@%, '')
  if empty(l:worktree) || empty(l:path) || l:path =~# '^/'
    return ''
  endif
  return l:path
endfunction

" Warns when the unsaved comments are from another branch than HEAD
function! git_extras#comments#check() abort
  let l:id = s:find_id()
  let l:branch = l:id ? getqflist({'id': l:id, 'context': 0}).context : ''
  if type(l:branch) == v:t_string && !empty(l:branch) && l:branch !=# FugitiveHead(7)
    echohl WarningMsg
    echomsg 'git-extras: unsaved review comments from ' . l:branch . ' (:CommentsSave)'
    echohl None
  endif
endfunction

" Prompts for the comment unless text is given
function! git_extras#comments#add(line1, line2, text) abort
  call git_extras#comments#check()
  let l:path = s:repo_path()
  if empty(l:path)
    call s:error('not a file in a git work tree')
    return
  endif
  if @% =~# '^fugitive://' && git_extras#is_base(FugitiveParse(@%)[0])
    call s:error('comment on the branch side of the diff, not the merge-base')
    return
  endif
  let l:range = a:line1 == a:line2 ? a:line1 : a:line1 . '-' . a:line2
  let l:text = empty(a:text) ? input('Comment ' . l:path . ':' . l:range . ': ') : a:text
  if empty(l:text)
    return
  endif
  let l:item = {'filename': FugitiveWorkTree() . '/' . l:path,
        \ 'lnum': a:line1, 'text': l:text}
  if a:line2 != a:line1
    let l:item.end_lnum = a:line2
  endif
  call setqflist([], 'a', {'id': s:list_id(), 'items': [l:item],
        \ 'context': FugitiveHead(7)})
  redraw
  echo 'Review comments: ' . len(s:items())
endfunction

" Make the 'Review' list current and open it
function! git_extras#comments#open() abort
  let l:nr = getqflist({'id': s:list_id(), 'nr': 0}).nr
  execute 'silent chistory' l:nr
  copen
endfunction

" Comments as {path, line, start_line?, body}, paths relative to the work tree
function! s:comments() abort
  let l:prefix = FugitiveWorkTree() . '/'
  let l:comments = []
  for l:item in s:items()
    let l:file = fnamemodify(bufname(l:item.bufnr), ':p')
    let l:comment = {'path': stridx(l:file, l:prefix) == 0 ? l:file[len(l:prefix):] : l:file,
          \ 'line': l:item.lnum, 'body': l:item.text}
    if get(l:item, 'end_lnum', 0) > l:item.lnum
      let l:comment.start_line = l:item.lnum
      let l:comment.line = l:item.end_lnum
    endif
    call add(l:comments, l:comment)
  endfor
  return l:comments
endfunction

" Saves for the current branch (the commit when detached), in the git dir
" shared by all work trees, so never committed:
" git-extras/comments/<branch>/<time>.txt
function! s:dir() abort
  let l:common = FugitiveCommonDir()
  let l:head = FugitiveHead(7)
  return empty(l:common) || empty(l:head) ? ''
        \ : l:common . '/git-extras/comments/' . l:head
endfunction

" The given file, else a new save for the branch, timestamped so they sort
function! s:save_file(file) abort
  if !empty(a:file)
    return fnamemodify(a:file, ':p')
  endif
  let l:dir = s:dir()
  return empty(l:dir) ? '' : l:dir . '/' . strftime('%Y%m%d-%H%M%S') . '.txt'
endfunction

" The branch's save names (<time>.txt), newest first
function! s:saves() abort
  let l:dir = s:dir()
  return empty(l:dir) ? []
        \ : reverse(sort(map(glob(l:dir . '/*.txt', 1, 1), 'fnamemodify(v:val, ":t")')))
endfunction

" The given file, else the branch's latest save ('' when there is none). A
" bare save name, as completed, is one of the branch's saves.
function! s:load_file(file) abort
  if index(s:saves(), a:file) >= 0
    return s:dir() . '/' . a:file
  elseif !empty(a:file)
    return fnamemodify(a:file, ':p')
  endif
  let l:saves = s:saves()
  return empty(l:saves) ? '' : s:dir() . '/' . l:saves[0]
endfunction

" The branch's saves, newest first; files once the arg looks like a path
function! git_extras#comments#complete_load(lead, cmdline, pos) abort
  if a:lead =~# '[/~.]'
    return getcompletion(a:lead, 'file')
  endif
  return filter(s:saves(), 'stridx(v:val, a:lead) == 0')
        \ + getcompletion(a:lead, 'file')
endfunction

function! git_extras#comments#save(file) abort
  let l:file = s:save_file(a:file)
  if empty(FugitiveWorkTree()) || empty(l:file)
    call s:error('not in a git work tree')
    return
  endif
  let l:lines = map(s:comments(), {_, c -> c.path . ':'
        \ . (has_key(c, 'start_line') ? c.start_line . '-' : '') . c.line
        \ . ': ' . c.body})
  call mkdir(fnamemodify(l:file, ':h'), 'p')
  call writefile(l:lines, l:file)
  call setqflist([], 'a', {'id': s:list_id(), 'context': ''})
  echo 'Saved ' . len(l:lines) . ' review comments to ' . fnamemodify(l:file, ':~')
endfunction

" Replaces the 'Review' list with the comments in the file
function! git_extras#comments#load(file) abort
  let l:file = s:load_file(a:file)
  let l:worktree = FugitiveWorkTree()
  if empty(l:worktree)
    call s:error('not in a git work tree')
    return
  endif
  if empty(l:file)
    call s:error('no saved comments for ' . FugitiveHead(7))
    return
  endif
  if !filereadable(l:file)
    call s:error('no review file ' . fnamemodify(l:file, ':~'))
    return
  endif
  let l:items = []
  for l:line in readfile(l:file)
    let l:m = matchlist(l:line, '^\(.\{-}\):\(\d\+\)\%(-\(\d\+\)\)\=: \(.*\)$')
    if empty(l:m)
      continue
    endif
    let l:item = {'filename': l:worktree . '/' . l:m[1],
          \ 'lnum': str2nr(l:m[2]), 'text': l:m[4]}
    if !empty(l:m[3])
      let l:item.end_lnum = str2nr(l:m[3])
    endif
    call add(l:items, l:item)
  endfor
  call setqflist([], 'r', {'id': s:list_id(), 'items': l:items, 'context': ''})
  call git_extras#comments#open()
endfunction

" Posts the comments as one pending review on a PR (the current branch's, or
" number), so you can check them on GitHub and submit there or with gh.
function! git_extras#comments#submit(number) abort
  let l:worktree = FugitiveWorkTree()
  if empty(l:worktree)
    call s:error('not in a git work tree')
    return
  endif
  if !git_extras#require_remote(':CommentsSubmit')
    return
  endif
  call git_extras#comments#check()
  let l:comments = s:comments()
  if empty(l:comments)
    call s:error('no review comments')
    return
  endif
  for l:c in l:comments
    let l:c.side = 'RIGHT'
    if has_key(l:c, 'start_line')
      let l:c.start_side = 'RIGHT'
    endif
  endfor
  let l:cd = 'cd ' . shellescape(l:worktree) . ' && '
  let l:number = a:number
  if empty(l:number)
    let l:number = trim(system(l:cd . 'gh pr view --json number --jq .number'))
    if v:shell_error
      call s:error('no PR for this branch; pass its number')
      return
    endif
  endif
  let l:out = system(l:cd . 'gh api repos/{owner}/{repo}/pulls/' . l:number
        \ . '/reviews --input - --jq .html_url',
        \ json_encode({'comments': l:comments}))
  if v:shell_error
    call s:error('gh: ' . substitute(trim(l:out), '\n', ' ', 'g'))
    return
  endif
  echo 'Pending review with ' . len(l:comments) . ' comments: ' . trim(l:out)
endfunction
