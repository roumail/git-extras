# git-review

Review the current branch the way a pull request shows it, and stage hunks in a
vertical diff, on top of [vim-fugitive](https://github.com/tpope/vim-fugitive).

"Main" is the repo's default branch: `origin/HEAD`, else `origin/main`,
`origin/master`, `main` or `master`, resolved per repo when a command runs.
Diffs are against the **merge-base** of `HEAD` and main, so they show only
what this branch changes, not what landed on main since it forked. They
include uncommitted changes.

`:ChangesMain`, `:ReviewMain` and `:LogMain` also take a branch, local or
remote, to review it without checking it out: `:ReviewMain origin/feature`.
Diffs are then from that branch's merge-base with main to its last commit.
`<Tab>` completes branches, most recent first. Run `:Git fetch` first to see
new remote branches.

| Command | `<Plug>` mapping | What it does |
| --- | --- | --- |
| `:DiffThis` | `<Plug>(git-review-diff-this)` | `:Gvdiffsplit`: index on the left, working tree on the right. `dp` on a hunk in the working tree stages it, `do` in the index unstages it; `:w` the index buffer to keep it. |
| `:DiffMain` | `<Plug>(git-review-diff-main)` | The current file at the merge-base, beside the working tree. |
| `:ChangesMain [branch]` | `<Plug>(git-review-changes-main)` | Files changed since the merge-base, in the quickfix list (`:Git difftool --name-status`). Step with `:cnext`, `:DiffMain` on each. |
| `:ReviewMain [branch]` | `<Plug>(git-review-review-main)` | One tab per changed file, each already a diff against the merge-base (`:Git difftool -y`). |
| `:LogMain [branch] [args]` | `<Plug>(git-review-log-main)` | Commits on the branch that main lacks (`:Git log base..branch`). `<CR>` on a commit opens it. Extra args go to `git log`, e.g. `:LogMain -p -- %`. |
| `:DiffClose` | `<Plug>(git-review-diff-close)` | Close the `fugitive://` windows in this tab and `:diffoff!`. |

Reviewing a PR: check it out (`gh pr checkout`), then `:ChangesMain` or
`:ReviewMain`.

No keys are bound; bind the `<Plug>` mappings yourself, for example:

```vim
nmap <leader>cd <Plug>(git-review-diff-main)
nmap <leader>cf <Plug>(git-review-changes-main)
nmap <leader>cl <Plug>(git-review-log-main)
```

## Install

Requires vim-fugitive; without it the plugin warns once and defines nothing.

```vim
Plug 'tpope/vim-fugitive'
Plug 'roumail/git-review'
```
