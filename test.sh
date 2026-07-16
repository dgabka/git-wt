#!/usr/bin/env bash
set -euo pipefail

wt="$(cd "$(dirname "$0")" && pwd)/wt"
tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export TEST_HOOK_LOG="$tmp/hooks.log"
mkdir -p "$tmp/bin" "$XDG_CONFIG_HOME/wt"
cat >"$tmp/bin/fzf" <<'EOF'
#!/usr/bin/env bash
grep -Fx "$FZF_CHOICE"
EOF
chmod +x "$tmp/bin/fzf"
export PATH="$tmp/bin:$PATH"

git config --file "$XDG_CONFIG_HOME/wt/config" --add wt.reposDir "$tmp/repos/first"
git config --file "$XDG_CONFIG_HOME/wt/config" --add wt.reposDir "$tmp/repos/second"
cat >"$tmp/hooks" <<'EOF'
log_hook() {
  printf '%s %s %s\n' "$1" "$WT_BRANCH" "$WT_WORKTREE_PATH" >>"$TEST_HOOK_LOG"
}
wt_post_init() { log_hook post-init; }
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

local_path="$(cd "$repo" && "$wt" feature/local | tail -n 1)"
[[ "$local_path" == "$repo/feature/local" ]]
[[ "$(git -C "$local_path" branch --show-current)" == feature/local ]]
[[ "$(cd "$repo" && "$wt" feature/local)" == "$local_path" ]]

git -C "$tmp/source" branch feature/remote
remote_path="$(cd "$repo" && "$wt" feature/remote | tail -n 1)"
[[ "$remote_path" == "$repo/feature/remote" ]]
[[ "$(git -C "$remote_path" config --get branch.feature/remote.remote)" == origin ]]
[[ "$(git -C "$remote_path" config --get branch.feature/remote.merge)" == refs/heads/feature/remote ]]

touch "$local_path/dirty"
if (cd "$repo" && "$wt" rm feature/local); then
  exit 1
fi
[[ -d "$local_path" ]]
git -C "$repo" show-ref --verify --quiet refs/heads/feature/local
(cd "$repo" && "$wt" rm feature/local --force)
[[ ! -e "$local_path" ]]
! git -C "$repo" show-ref --verify --quiet refs/heads/feature/local

cat >"$tmp/expected-hooks" <<EOF
post-init  $tmp/here/local.git
pre-add feature/local $repo/feature/local
post-add feature/local $repo/feature/local
pre-add feature/remote $repo/feature/remote
post-add feature/remote $repo/feature/remote
pre-rm feature/local $repo/feature/local
post-rm feature/local $repo/feature/local
EOF
diff -u "$tmp/expected-hooks" "$TEST_HOOK_LOG"
