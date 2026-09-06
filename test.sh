#!/usr/bin/env bash
set -euo pipefail

wt="$(cd "$(dirname "$0")" && pwd)/wt"
tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export TEST_HOOK_LOG="$tmp/hooks.log"
export TEST_HOOK_DIRS="$tmp/hook-dirs.log"
export FZF_LOG="$tmp/fzf.log"
mkdir -p "$tmp/bin" "$XDG_CONFIG_HOME/wt"
cat >"$tmp/bin/fzf" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FZF_LOG"
grep -Fx "$FZF_CHOICE"
EOF
chmod +x "$tmp/bin/fzf"
export PATH="$tmp/bin:$PATH"

(cd "$tmp" && "$wt" --help) | grep -qx '  wt list'

git config --file "$XDG_CONFIG_HOME/wt/config" --add wt.reposDir "$tmp/repos/first"
git config --file "$XDG_CONFIG_HOME/wt/config" --add wt.reposDir "$tmp/repos/second"
cat >"$tmp/hooks" <<'EOF'
log_hook() {
  printf '%s %s %s\n' "$1" "$WT_BRANCH" "$WT_WORKTREE_PATH" >>"$TEST_HOOK_LOG"
}
wt_post_init() { log_hook post-init; printf 'init %s\n' "$WT_REPOS_DIR" >>"$TEST_HOOK_DIRS"; }
wt_pre_clone() { printf 'clone %s\n' "$WT_REPOS_DIR" >>"$TEST_HOOK_DIRS"; }
wt_pre_add() { log_hook pre-add; }
wt_post_add() { log_hook post-add; }
wt_pre_rm() { log_hook pre-rm; }
wt_post_rm() { log_hook post-rm; }
EOF
git config --file "$XDG_CONFIG_HOME/wt/config" wt.hooksFile "$tmp/hooks"
git init --initial-branch=main "$tmp/source" >/dev/null
git -C "$tmp/source" config user.name test
git -C "$tmp/source" config user.email test@example.com
touch "$tmp/source/file"
git -C "$tmp/source" add file
git -C "$tmp/source" commit -m initial >/dev/null
FZF_CHOICE="$tmp/repos/second" "$wt" clone "$tmp/source"
repo="$tmp/repos/second/source.git"
[[ "$(git -C "$repo" rev-parse --is-bare-repository)" == true ]]
[[ "$(git -C "$repo" remote get-url origin)" == "$tmp/source" ]]

mkdir "$tmp/here"
(cd "$tmp/here" && FZF_CHOICE=here "$wt" init local)
[[ "$(git -C "$tmp/here/local.git" rev-parse --is-bare-repository)" == true ]]

fzf_calls="$(wc -l <"$FZF_LOG")"
"$wt" init spaced --dir "$tmp/repos with spaces"
[[ "$(git -C "$tmp/repos with spaces/spaced.git" rev-parse --is-bare-repository)" == true ]]
mkdir "$tmp/clone-caller"
(cd "$tmp/clone-caller" && "$wt" clone ../source --dir 'relative repos')
[[ "$(git -C "$tmp/clone-caller/relative repos/source.git" rev-parse --is-bare-repository)" == true ]]
[[ "$(wc -l <"$FZF_LOG")" == "$fzf_calls" ]]
cat >"$tmp/expected-hook-dirs" <<EOF
clone $tmp/repos/second
init $tmp/here
init $tmp/repos with spaces
clone $tmp/clone-caller/relative repos
EOF
diff -u "$tmp/expected-hook-dirs" "$TEST_HOOK_DIRS"
if "$wt" init invalid --dir; then exit 1; fi
if "$wt" clone "$tmp/source" --unknown "$tmp/invalid"; then exit 1; fi
if "$wt" init invalid --dir -invalid; then exit 1; fi
if "$wt" clone "$tmp/source" --dir "$tmp/invalid" extra; then exit 1; fi
[[ "$(wc -l <"$FZF_LOG")" == "$fzf_calls" ]]

local_path="$(cd "$repo" && "$wt" feature/local | tail -n 1)"
[[ "$local_path" == "$repo/feature/local" ]]
[[ "$(git -C "$local_path" branch --show-current)" == feature/local ]]
[[ "$(cd "$repo" && "$wt" feature/local)" == "$local_path" ]]

git -C "$tmp/source" branch feature/remote
remote_path="$(cd "$repo" && "$wt" feature/remote | tail -n 1)"
[[ "$remote_path" == "$repo/feature/remote" ]]
[[ "$(git -C "$remote_path" config --get branch.feature/remote.remote)" == origin ]]
[[ "$(git -C "$remote_path" config --get branch.feature/remote.merge)" == refs/heads/feature/remote ]]
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com

touch "$local_path/dirty"
if (cd "$repo" && "$wt" rm feature/local); then
  exit 1
fi
[[ -d "$local_path" ]]
git -C "$repo" show-ref --verify --quiet refs/heads/feature/local
(cd "$repo" && "$wt" rm feature/local --force)
[[ ! -e "$local_path" ]]
if git -C "$repo" show-ref --verify --quiet refs/heads/feature/local; then exit 1; fi

unmerged_path="$(cd "$repo" && "$wt" feature/unmerged | tail -n 1)"
printf 'unmerged\n' >"$unmerged_path/unmerged"
git -C "$unmerged_path" add unmerged
git -C "$unmerged_path" commit -m unmerged >/dev/null
if (cd "$repo" && "$wt" rm feature/unmerged); then
  exit 1
fi
[[ -d "$unmerged_path" ]]
git -C "$repo" show-ref --verify --quiet refs/heads/feature/unmerged
(cd "$repo" && "$wt" rm feature/unmerged --force)
[[ ! -e "$unmerged_path" ]]
if git -C "$repo" show-ref --verify --quiet refs/heads/feature/unmerged; then exit 1; fi

main_path="$(cd "$repo" && "$wt" main | tail -n 1)"
if (cd "$repo" && "$wt" rm main); then
  exit 1
fi
[[ -d "$main_path" ]]
git -C "$repo" show-ref --verify --quiet refs/heads/main

(cd "$repo" && "$wt" rm feature/remote)
[[ ! -e "$remote_path" ]]
if git -C "$repo" show-ref --verify --quiet refs/heads/feature/remote; then exit 1; fi

cat >"$tmp/expected-hooks" <<EOF
post-init  $tmp/here/local.git
post-init  $tmp/repos with spaces/spaced.git
pre-add feature/local $repo/feature/local
post-add feature/local $repo/feature/local
pre-add feature/remote $repo/feature/remote
post-add feature/remote $repo/feature/remote
pre-rm feature/local $repo/feature/local
post-rm feature/local $repo/feature/local
pre-add feature/unmerged $repo/feature/unmerged
post-add feature/unmerged $repo/feature/unmerged
pre-rm feature/unmerged $repo/feature/unmerged
post-rm feature/unmerged $repo/feature/unmerged
pre-add main $repo/main
post-add main $repo/main
pre-rm feature/remote $repo/feature/remote
post-rm feature/remote $repo/feature/remote
EOF
diff -u "$tmp/expected-hooks" "$TEST_HOOK_LOG"

# Bash completion offers commands, branches, and only linked branches for removal.
# shellcheck source=completions/wt.bash
source "$(dirname "$wt")/completions/wt.bash"
COMP_WORDS=(wt r)
COMP_CWORD=1
_wt
printf '%s\n' "${COMPREPLY[@]}" | grep -qx rm
COMP_WORDS=(wt init name --dir "$tmp/repos w")
COMP_CWORD=4
_wt
printf '%s\n' "${COMPREPLY[@]}" | grep -qx "$tmp/repos with spaces"
(
  cd "$repo"
  COMP_WORDS=(wt feature/r)
  COMP_CWORD=1
  _wt
  printf '%s\n' "${COMPREPLY[@]}" | grep -qx feature/remote
  COMP_WORDS=(wt rm '')
  COMP_CWORD=2
  _wt
  printf '%s\n' "${COMPREPLY[@]}" | grep -qx main
  if printf '%s\n' "${COMPREPLY[@]}" | grep -qx feature/remote; then exit 1; fi
)
