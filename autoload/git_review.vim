" Runs git in the current buffer's repo; returns stdout lines, or v:null on
" failure.
function! s:git(args) abort
  let l:result = FugitiveExecute(a:args)
  if l:result.exit_status != 0
    return v:null
  endif
  return filter(copy(l:result.stdout), '!empty(v:val)')
endfunction

function! s:error(msg) abort
  echohl ErrorMsg
  echomsg 'git-review: ' . a:msg
  echohl None
endfunction

" The default branch as a ref: origin/HEAD, else main or master. The remote
" ref is preferred, since the local branch is often stale after a fetch or a
" `gh pr checkout`.
function! git_review#main_ref() abort
  let l:head = s:git(['symbolic-ref', '--short', 'refs/remotes/origin/HEAD'])
  if !empty(l:head)
    return l:head[0]
  endif
  for l:ref in ['refs/remotes/origin/main', 'refs/remotes/origin/master',
        \ 'refs/heads/main', 'refs/heads/master']
    if s:git(['show-ref', '--verify', '--quiet', l:ref]) isnot v:null
      return substitute(l:ref, '^refs/\%(remotes\|heads\)/', '', '')
    endif
  endfor
  return ''
endfunction

" The commit where the current branch forked from main, so diffs show only
" this branch's changes (like a PR), not what landed on main since.
function! s:base() abort
  if empty(FugitiveGitDir())
    call s:error('not in a git repository')
    return ''
  endif
  let l:main = git_review#main_ref()
  if empty(l:main)
    call s:error('no origin/HEAD, main or master found')
    return ''
  endif
  let l:base = s:git(['merge-base', 'HEAD', l:main])
  if empty(l:base)
    call s:error('no merge-base between HEAD and ' . l:main)
    return ''
  endif
  return l:base[0]
endfunction

function! git_review#diff_this() abort
  Gvdiffsplit
endfunction

function! git_review#diff_main() abort
  let l:base = s:base()
  if !empty(l:base)
    execute 'Gvdiffsplit' l:base
  endif
endfunction

function! git_review#changes_main() abort
  let l:base = s:base()
  if !empty(l:base)
    execute 'Git difftool --name-status' l:base
  endif
endfunction

function! git_review#review_main() abort
  let l:base = s:base()
  if !empty(l:base)
    execute 'Git difftool -y' l:base
  endif
endfunction

function! git_review#log_main(args) abort
  let l:base = s:base()
  if !empty(l:base)
    execute 'Git log --oneline --decorate' l:base . '..HEAD' a:args
  endif
endfunction

function! git_review#diff_close() abort
  for l:win in reverse(range(1, winnr('$')))
    if bufname(winbufnr(l:win)) =~# '^fugitive://' && winnr('$') > 1
      execute l:win . 'close'
    endif
  endfor
  diffoff!
endfunction
