# git-extras

Additions to [vim-fugitive](https://github.com/tpope/vim-fugitive): review a
branch the way a pull request shows it, stage hunks in a vertical diff, collect
review comments, and list open pull requests.

"Main" is the repo's default branch: `origin/HEAD`, else `origin/main`,
`origin/master`, `main` or `master`, resolved per repo when a command runs.
Diffs are against the **merge-base** of `HEAD` and main, so they show only
what this branch changes, not what landed on main since it forked. They
include uncommitted changes.

The `:Branch*` commands show the branch like a PR's tabs on GitHub: its
changed files as diffs, and its commits. They take a
branch, local or remote, to review it without checking it out:
`:BranchDiff origin/feature`.
Diffs are then from that branch's merge-base with main to its last commit.
`<Tab>` completes branches, most recent first. Run `:Git fetch` first to see
new remote branches.

| Command | `<Plug>` mapping | What it does |
| --- | --- | --- |
| `:DiffThis` | `<Plug>(git-extras-diff-this)` | `:Gvdiffsplit`: index on the left, working tree on the right. `dp` on a hunk in the working tree stages it, `do` in the index unstages it; `:w` the index buffer to keep it. |
| `:DiffThis!` | `<Plug>(git-extras-diff-main)` | The current file at the merge-base on the left, working tree on the right: what the branch changes in it. |
| `:BranchDiff [branch]` | `<Plug>(git-extras-branch-diff)` | One tab per changed file, each already a diff against the merge-base (`:Git difftool -y`). |
| `:BranchCommits [branch] [args]` | `<Plug>(git-extras-branch-commits)` | Commits on the branch that main lacks (`:Git log base..branch`). `<CR>` on a commit opens it. Extra args go to `git log`, e.g. `:BranchCommits --stat` or `:BranchCommits -- %`. |
| `:DiffClose` | `<Plug>(git-extras-diff-close)` | Close the `fugitive://` windows in this tab and `:diffoff!`. |

Reviewing a PR: check it out (`gh pr checkout`), then `:BranchDiff` and
`:BranchCommits`.

## Open pull requests

`:PRs [count]` lists the repo's open pull requests, most recently updated first
(default 20), in a scratch buffer: number, review state (`draft`, `approved`,
`changes`, `review`, or `-`), age, author, branch and title.

| Key | What it does |
| --- | --- |
| `<CR>` | `gh pr checkout` the PR, then go back to where you were. `:BranchDiff` / `:BranchCommits` review it. |
| `o` | Open the PR in the browser. |
| `r` | Refresh. |
| `q` | Close. |

Defined only when [gh](https://cli.github.com) is installed.

## Review comments

Comments collect in their own quickfix list, titled `Review`, so they don't mix
with `:Git difftool` or grep results. A comment is on a line or a range, on the
branch side of a diff (or a file in the work tree); the merge-base side is
refused.

| Command | `<Plug>` mapping | What it does |
| --- | --- | --- |
| `:[range]Comment [text]` | `<Plug>(git-extras-comment)` (normal and visual) | Add a comment on the line or range; prompts unless `text` is given. |
| `:Comments` | | Open the `Review` list. |
| `:CommentsSave [file]` | | Write the comments, one per line, as `path:line: comment` or `path:start-end: comment`. Paths are relative to the repo root. Without `file`, each save is a new file named for the branch and time, `git-extras/comments/<branch>/<YYYYmmdd-HHMMSS>.txt` in the git dir, so it is never committed and reviews of different branches stay apart. |
| `:CommentsLoad [file]` | | Replace the `Review` list with the comments in the file; without `file`, the current branch's latest save. `<Tab>` lists the branch's saves, newest first, then files. |
| `:CommentsSubmit [number]` | | Post the comments as one **pending** review on the branch's PR, or PR `number`, through `gh api`. Only you see it until you submit it on GitHub. Defined only when `gh` is installed. |

Other plugins can read the comments with `git_extras#comments#list()`
(`{path, line, start_line?, body}`, paths relative to the work tree) and empty
them with `git_extras#comments#clear()`.

Switching branches with unsaved comments (`:Git checkout`, `:PRs`) warns
once; `:Comment` and `:CommentsSubmit` warn too. Nothing is cleared.

Line numbers are for the branch's version of the file. A checked-out PR with
uncommitted changes can shift them, and GitHub rejects the whole review if a
line is outside the PR's diff.

No keys are bound; bind the `<Plug>` mappings yourself, for example:

```vim
nmap <leader>cd <Plug>(git-extras-diff-main)
nmap <leader>cl <Plug>(git-extras-branch-commits)
nmap <leader>cc <Plug>(git-extras-comment)
xmap <leader>cc <Plug>(git-extras-comment)
```

## Install

Requires vim-fugitive; without it the plugin warns once and defines nothing.
`:PRs` and `:CommentsSubmit` also need `gh`, and are left out without it.

```vim
Plug 'tpope/vim-fugitive'
Plug 'roumail/git-extras'
```
