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

### Nix

```sh
nix profile install .  # install from a checkout
nix develop            # Bash, Git, fzf, ShellCheck, and shfmt
```

## Usage

```sh
wt init my-repo                         # choose where to create my-repo.git
wt clone git@github.com:owner/repo.git  # choose where to clone repo.git
cd ~/repos/repo.git/main
wt                                  # choose an unchecked-out branch with fzf
wt feature/my-branch                # create or open a worktree
wt list                             # list worktrees
wt rm feature/my-branch             # remove its worktree and local branch
wt rm                                # choose one or more worktrees to remove
```

`wt init` and `wt clone` prompt for a repository directory. Worktrees live inside the selected bare repository and are named after their branches. Existing local or remote branches are checked out; new branches start from the remote default branch. `wt` fetches `origin` before selecting or creating a worktree.

`wt rm` refuses to remove dirty worktrees, the bare repository's default branch, and branches not merged into their configured upstream (or `HEAD` when no upstream is configured). Pass `--force` to override these checks:

```sh
wt rm feature/my-branch --force
```

## Configuration

Repository directories are configured in `${XDG_CONFIG_HOME:-$HOME/.config}/wt/config` using Git config syntax:

```ini
[wt]
    reposDir = ~/repos/personal
    reposDir = ~/repos/work
    hooksFile = ~/dotfiles/wt-hooks
```

`wt init` and `wt clone` always use `fzf` to choose between the configured directories and `here`, which means the current directory. Without any `reposDir` entries, `$HOME/repos` is offered instead. `hooksFile` defaults to `${XDG_CONFIG_HOME:-$HOME/.config}/wt/hooks`.

## Hooks

Source `~/.config/wt/hooks` to run shell functions around lifecycle operations. Hooks are useful for project-specific setup and cleanup—for example, copying an untracked `.env` file into a new worktree, installing dependencies, or stopping local services before removal.

Available hooks are:

- `wt_pre_init`, `wt_post_init`
- `wt_pre_clone`, `wt_post_clone`
- `wt_pre_add`, `wt_post_add`
- `wt_pre_rm`, `wt_post_rm`

Each runs in the `wt` process and can stop the operation by returning non-zero. Hooks receive context through environment variables: `WT_REPOS_DIR`, `WT_REPO_ROOT`, `WT_REPO_NAME`, `WT_BRANCH`, and `WT_WORKTREE_PATH`.

```bash
# ~/.config/wt/hooks
wt_post_add() {
  cp "$HOME/.config/wt/env/$WT_REPO_NAME" "$WT_WORKTREE_PATH/.env"
}
```
