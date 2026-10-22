" Review comments live in their own quickfix list, titled 'Review', so they
" don't mix with :ChangesMain or grep results. Each entry is a repo path, a
" line (or range) on the branch side, and the comment. Saved as
" `path:line: comment` or `path:start-end: comment`, one per line.

let s:title = 'Review'

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'git-review: ' . a:msg
  echohl None
endfunction

" The id of the 'Review' quickfix list, created if missing
function! s:list_id() abort
  for l:nr in range(1, getqflist({'nr': '$'}).nr)
    let l:info = getqflist({'nr': l:nr, 'title': 1, 'id': 0})
    if l:info.title ==# s:title
      return l:info.id
    endif
  endfor
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

" Prompts for the comment unless text is given
function! git_review#comments#add(line1, line2, text) abort
  let l:path = s:repo_path()
  if empty(l:path)
    call s:error('not a file in a git work tree')
    return
  endif
  if @% =~# '^fugitive://' && git_review#is_base(FugitiveParse(@%)[0])
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
  call setqflist([], 'a', {'id': s:list_id(), 'items': [l:item]})
  redraw
  echo 'Review comments: ' . len(s:items())
endfunction

" Make the 'Review' list current and open it
function! git_review#comments#open() abort
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

" Default file: review.txt in the git dir (per work tree, never committed)
function! s:file(file) abort
  if !empty(a:file)
    return fnamemodify(a:file, ':p')
  endif
  let l:gitdir = FugitiveGitDir()
  return empty(l:gitdir) ? '' : l:gitdir . '/review.txt'
endfunction

function! git_review#comments#save(file) abort
  let l:file = s:file(a:file)
  if empty(FugitiveWorkTree()) || empty(l:file)
    call s:error('not in a git work tree')
    return
  endif
  let l:lines = map(s:comments(), {_, c -> c.path . ':'
        \ . (has_key(c, 'start_line') ? c.start_line . '-' : '') . c.line
        \ . ': ' . c.body})
  call writefile(l:lines, l:file)
  echo 'Saved ' . len(l:lines) . ' review comments to ' . fnamemodify(l:file, ':~')
endfunction

" Replaces the 'Review' list with the comments in the file
function! git_review#comments#load(file) abort
  let l:file = s:file(a:file)
  let l:worktree = FugitiveWorkTree()
  if empty(l:worktree) || empty(l:file)
    call s:error('not in a git work tree')
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
  call setqflist([], 'r', {'id': s:list_id(), 'items': l:items})
  call git_review#comments#open()
endfunction

" Posts the comments as one pending review on a PR (the current branch's, or
" number), so you can check them on GitHub and submit there or with gh.
function! git_review#comments#submit(number) abort
  let l:worktree = FugitiveWorkTree()
  if empty(l:worktree)
    call s:error('not in a git work tree')
    return
  endif
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
