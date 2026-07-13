#!/usr/bin/env bash
set -euo pipefail

wt="$(cd "$(dirname "$0")" && pwd)/wt"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
mkdir -p "$tmp/bin" "$XDG_CONFIG_HOME/wt"
cat >"$tmp/bin/fzf" <<'EOF'
#!/usr/bin/env bash
grep -Fx "$FZF_CHOICE"
EOF
chmod +x "$tmp/bin/fzf"
export PATH="$tmp/bin:$PATH"

git config --file "$XDG_CONFIG_HOME/wt/config" --add wt.reposDir "$tmp/repos/first"
git config --file "$XDG_CONFIG_HOME/wt/config" --add wt.reposDir "$tmp/repos/second"
git init --initial-branch=main "$tmp/source" >/dev/null
git -C "$tmp/source" config user.name test
git -C "$tmp/source" config user.email test@example.com
touch "$tmp/source/file"
git -C "$tmp/source" add file
git -C "$tmp/source" commit -m initial >/dev/null
FZF_CHOICE="$tmp/repos/second" "$wt" clone "$tmp/source"
[[ "$(git -C "$tmp/repos/second/source.git" rev-parse --is-bare-repository)" == true ]]
[[ "$(git -C "$tmp/repos/second/source.git" remote get-url origin)" == "$tmp/source" ]]

mkdir "$tmp/here"
(cd "$tmp/here" && FZF_CHOICE=here "$wt" init local)
[[ "$(git -C "$tmp/here/local.git" rev-parse --is-bare-repository)" == true ]]
