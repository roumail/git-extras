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

## Review comments

Comments collect in their own quickfix list, titled `Review`, so they don't mix
with `:ChangesMain` or grep results. A comment is on a line or a range, on the
branch side of a diff (or a file in the work tree); the merge-base side is
refused.

| Command | `<Plug>` mapping | What it does |
| --- | --- | --- |
| `:[range]ReviewComment [text]` | `<Plug>(git-review-comment)` (normal and visual) | Add a comment on the line or range; prompts unless `text` is given. |
| `:ReviewComments` | | Open the `Review` list. |
| `:ReviewSave [file]` | | Write the comments, one per line, as `path:line: comment` or `path:start-end: comment`. Paths are relative to the repo root. The default file is `review.txt` in the git dir, which is per work tree and never committed. |
| `:ReviewLoad [file]` | | Replace the `Review` list with the comments in the file. |
| `:ReviewSubmit [number]` | | Post the comments as one **pending** review on the branch's PR, or PR `number`, through `gh api`. Only you see it until you submit it on GitHub. Defined only when `gh` is installed. |

Line numbers are for the branch's version of the file. A checked-out PR with
uncommitted changes can shift them, and GitHub rejects the whole review if a
line is outside the PR's diff.

No keys are bound; bind the `<Plug>` mappings yourself, for example:

```vim
nmap <leader>cd <Plug>(git-review-diff-main)
nmap <leader>cf <Plug>(git-review-changes-main)
nmap <leader>cl <Plug>(git-review-log-main)
nmap <leader>cc <Plug>(git-review-comment)
xmap <leader>cc <Plug>(git-review-comment)
```

## Install

Requires vim-fugitive; without it the plugin warns once and defines nothing.

```vim
Plug 'tpope/vim-fugitive'
Plug 'roumail/git-review'
```
