# git-wt

A small CLI for managing Git worktrees from a bare repository.

## Requirements

- Git
- Bash
- [fzf](https://github.com/junegunn/fzf) for interactive branch selection

## Install

```sh
install -m 755 wt ~/.local/bin/wt
```

## Usage

```sh
wt init my-repo                         # create ~/repos/my-repo.git
wt clone git@github.com:owner/repo.git  # clone to ~/repos/repo.git
cd ~/repos/repo.git/main
wt                                  # choose an unchecked-out branch with fzf
wt feature/my-branch                # create or open a worktree
wt list                             # list worktrees
wt rm feature/my-branch             # remove its worktree and local branch
wt rm                                # choose one or more worktrees to remove
```

`wt init <name>` creates a bare repository at `~/repos/<name>.git`. `wt clone <repo-url>` clones a remote there and creates a worktree for its default branch. Worktrees live inside the bare repository and are named after their branches. Existing local or remote branches are checked out; new branches start from the remote default branch. `wt` fetches `origin` before selecting or creating a worktree.

`wt rm` refuses to remove a dirty worktree. Pass `--force` to override that check:

```sh
wt rm feature/my-branch --force
```

## Hooks

Source `~/.config/wt/hooks` to run shell functions around lifecycle operations. Hooks are useful for project-specific setup and cleanup—for example, copying an untracked `.env` file into a new worktree, installing dependencies, or stopping local services before removal.

Available hooks are:

- `wt_pre_init`, `wt_post_init`
- `wt_pre_clone`, `wt_post_clone`
- `wt_pre_add`, `wt_post_add`
- `wt_pre_rm`, `wt_post_rm`

Each runs in the `wt` process and can stop the operation by returning non-zero. Hooks receive context through environment variables: `WT_REPO_ROOT`, `WT_REPO_NAME`, `WT_BRANCH`, and `WT_WORKTREE_PATH`.

```bash
# ~/.config/wt/hooks
wt_post_add() {
  cp "$HOME/.config/wt/env/$WT_REPO_NAME" "$WT_WORKTREE_PATH/.env"
}
```
