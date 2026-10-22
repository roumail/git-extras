" git-review: review the current branch against the repo's default branch
" (main/master), and stage hunks in a vertical diff. Commands and <Plug>
" mappings only; no keys are bound here. Requires tpope/vim-fugitive.
if exists('g:loaded_git_review')
  finish
endif
let g:loaded_git_review = 1

" Required plugins are checked once every plugin has loaded (VimEnter, or now
" when loaded later): their g:loaded_* guards tell whether they are installed.
" Without them nothing below is defined.
function! s:init() abort
  let l:missing = filter({
        \ 'tpope/vim-fugitive': 'g:loaded_fugitive',
        \ }, '!exists(v:val)')
  if !empty(l:missing)
    echohl WarningMsg
    echomsg 'git-review: not loaded, requires ' . join(sort(keys(l:missing)), ', ')
    echohl None
    return
  endif

  " Index | working tree: dp/do move hunks, :w in the index buffer stages
  command! DiffThis call git_review#diff_this()
  " Current file at the merge-base with main | working tree (what the PR changes)
  command! DiffMain call git_review#diff_main()
  " Changed files since the merge-base with main, in the quickfix list
  command! ChangesMain call git_review#changes_main()
  " One tab per changed file, each a diff against the merge-base with main
  command! ReviewMain call git_review#review_main()
  " Commits on this branch that main doesn't have; extra args go to git log
  command! -nargs=* -complete=file LogMain call git_review#log_main(<q-args>)
  " Close the fugitive side of the diff in this tab and turn diff mode off
  command! DiffClose call git_review#diff_close()

  nnoremap <Plug>(git-review-diff-this) <Cmd>DiffThis<CR>
  nnoremap <Plug>(git-review-diff-main) <Cmd>DiffMain<CR>
  nnoremap <Plug>(git-review-changes-main) <Cmd>ChangesMain<CR>
  nnoremap <Plug>(git-review-review-main) <Cmd>ReviewMain<CR>
  nnoremap <Plug>(git-review-log-main) <Cmd>LogMain<CR>
  nnoremap <Plug>(git-review-diff-close) <Cmd>DiffClose<CR>
endfunction

if v:vim_did_enter
  call s:init()
else
  augroup git_review_init
    autocmd!
    autocmd VimEnter * ++once call s:init()
  augroup END
endif
