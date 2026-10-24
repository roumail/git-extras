" Review comments are vim-review's (:Comment, :Comments, :CommentsSave,
" :CommentsLoad). This is its provider for git work trees: comments are on
" files in the work tree or the branch side of a fugitive diff, paths are
" relative to the work tree, and saves are per branch in the git dir. Plus
" :CommentsSubmit, which posts them to the branch's PR.

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'git-extras: ' . a:msg
  echohl None
endfunction

" The current buffer's path relative to the work tree: a file, or a
" fugitive:// object (a commit's or the index's version of one). {} outside
" a work tree, so vim-review's default applies.
function! s:target() abort
  if empty(FugitiveWorkTree())
    return {}
  endif
  let l:path = FugitivePath(@%, '')
  if empty(l:path) || l:path =~# '^/'
    return {'error': 'not a file in the git work tree'}
  endif
  if @% =~# '^fugitive://' && git_extras#is_base(FugitiveParse(@%)[0])
    return {'error': 'comment on the branch side of the diff, not the merge-base'}
  endif
  return {'path': l:path}
endfunction

" Saves for the current branch (the commit when detached), in the git dir
" shared by all work trees, so never committed:
" git-extras/comments/<branch>/<time>.txt
function! s:save_dir() abort
  let l:common = FugitiveCommonDir()
  let l:head = FugitiveHead(7)
  return empty(l:common) || empty(l:head) ? ''
        \ : l:common . '/git-extras/comments/' . l:head
endfunction

" Makes this vim-review's provider
function! git_extras#comments#init() abort
  call review#use({
        \ 'root': function('FugitiveWorkTree'),
        \ 'target': function('s:target'),
        \ 'save_dir': function('s:save_dir'),
        \ 'scope': function('FugitiveHead', [7]),
        \ })
endfunction

" Warns when the unsaved comments are from another branch than HEAD
function! git_extras#comments#check() abort
  if exists('g:loaded_review')
    call review#check()
  endif
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
  call review#check()
  let l:comments = review#list()
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
