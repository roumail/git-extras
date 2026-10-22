" git-extras: additions to vim-fugitive. Review a branch against the repo's
" default branch (main/master), stage hunks in a vertical diff, collect review
" comments, and list open PRs. Commands and <Plug> mappings only; no keys are
" bound here. Requires tpope/vim-fugitive; the GitHub commands need gh.
if exists('g:loaded_git_extras')
  finish
endif
let g:loaded_git_extras = 1

" Required plugins are checked once every plugin has loaded (VimEnter, or now
" when loaded later): their g:loaded_* guards tell whether they are installed.
" Without them nothing below is defined.
function! s:init() abort
  let l:missing = filter({
        \ 'tpope/vim-fugitive': 'g:loaded_fugitive',
        \ }, '!exists(v:val)')
  if !empty(l:missing)
    echohl WarningMsg
    echomsg 'git-extras: not loaded, requires ' . join(sort(keys(l:missing)), ', ')
    echohl None
    return
  endif

  " Index | working tree: dp/do move hunks, :w in the index buffer stages
  command! DiffThis call git_extras#diff_this()
  " Current file at the merge-base with main | working tree (what the PR changes)
  command! DiffMain call git_extras#diff_main()
  " The commands below take an optional branch (default HEAD), e.g.
  " origin/feature, to review it without checking it out.
  " Changed files since the merge-base with main, in the quickfix list
  command! -nargs=? -complete=customlist,git_extras#complete_branch
        \ ChangesMain call git_extras#changes_main(<q-args>)
  " One tab per changed file, each a diff against the merge-base with main
  command! -nargs=? -complete=customlist,git_extras#complete_branch
        \ ReviewMain call git_extras#review_main(<q-args>)
  " Commits on the branch that main doesn't have; further args go to git log
  command! -nargs=* -complete=customlist,git_extras#complete_log
        \ LogMain call git_extras#log_main(<q-args>)
  " Close the fugitive side of the diff in this tab and turn diff mode off
  command! DiffClose call git_extras#diff_close()

  " Review comments, in their own quickfix list titled 'Review'
  " Comment on the line or range, on the branch side of a diff; prompts
  " unless the comment is given
  command! -range -nargs=* ReviewComment
        \ call git_extras#comments#add(<line1>, <line2>, <q-args>)
  " Open the 'Review' list
  command! ReviewComments call git_extras#comments#open()
  " Write the comments to a file (default: review.txt in the git dir) and
  " load them back
  command! -nargs=? -complete=file ReviewSave call git_extras#comments#save(<q-args>)
  command! -nargs=? -complete=file ReviewLoad call git_extras#comments#load(<q-args>)
  if executable('gh')
    " Post the comments as a pending review on the branch's PR (or number)
    command! -nargs=? ReviewSubmit call git_extras#comments#submit(<q-args>)
    " Open PRs (default 20), latest first; <CR> checks one out
    command! -nargs=? PRs call git_extras#prs#open(<q-args>)
  endif

  nnoremap <Plug>(git-extras-diff-this) <Cmd>DiffThis<CR>
  nnoremap <Plug>(git-extras-diff-main) <Cmd>DiffMain<CR>
  nnoremap <Plug>(git-extras-changes-main) <Cmd>ChangesMain<CR>
  nnoremap <Plug>(git-extras-review-main) <Cmd>ReviewMain<CR>
  nnoremap <Plug>(git-extras-log-main) <Cmd>LogMain<CR>
  nnoremap <Plug>(git-extras-diff-close) <Cmd>DiffClose<CR>
  nnoremap <Plug>(git-extras-comment) <Cmd>ReviewComment<CR>
  xnoremap <Plug>(git-extras-comment) :ReviewComment<CR>
endfunction

if v:vim_did_enter
  call s:init()
else
  augroup git_extras_init
    autocmd!
    autocmd VimEnter * ++once call s:init()
  augroup END
endif
