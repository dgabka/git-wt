#!/usr/bin/env bash
set -euo pipefail

wt="$(cd "$(dirname "$0")" && pwd)/wt"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"

git init --initial-branch=main "$tmp/source" >/dev/null
git -C "$tmp/source" config user.name test
git -C "$tmp/source" config user.email test@example.com
touch "$tmp/source/file"
git -C "$tmp/source" add file
git -C "$tmp/source" commit -m initial >/dev/null
"$wt" clone "$tmp/source"
[[ "$(git -C "$HOME/repos/source.git" rev-parse --is-bare-repository)" == true ]]
[[ "$(git -C "$HOME/repos/source.git" remote get-url origin)" == "$tmp/source" ]]

"$wt" init local
[[ "$(git -C "$HOME/repos/local.git" rev-parse --is-bare-repository)" == true ]]
