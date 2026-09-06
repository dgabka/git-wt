_wt_git_dir() {
  git rev-parse --path-format=absolute --git-common-dir 2>/dev/null
}

_wt_branches() {
  local git_dir ref
  git_dir="$(_wt_git_dir)" || return
  while IFS= read -r ref; do
    case "$ref" in
      refs/heads/*) printf '%s\n' "${ref#refs/heads/}" ;;
      refs/remotes/origin/HEAD) ;;
      refs/remotes/origin/*) printf '%s\n' "${ref#refs/remotes/origin/}" ;;
    esac
  done < <(git --git-dir="$git_dir" for-each-ref --format='%(refname)' refs/heads refs/remotes/origin) | sort -u
}

_wt_linked_branches() {
  local git_dir
  git_dir="$(_wt_git_dir)" || return
  git --git-dir="$git_dir" worktree list --porcelain | awk '
    $1 == "branch" { sub("refs/heads/", "", $2); print $2 }
  '
}

_wt_complete() {
  local item
  while IFS= read -r item; do COMPREPLY+=("$item"); done < <(compgen "$@")
}

_wt() {
  local cur prev command
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]:-}"

  if (( COMP_CWORD == 1 )); then
    _wt_complete -W "init clone list rm $(_wt_branches)" -- "$cur"
    return
  fi

  command="${COMP_WORDS[1]}"
  case "$command" in
    init|clone)
      if [[ "$prev" == --dir ]]; then
        compopt -o filenames 2>/dev/null || true
        _wt_complete -d -- "$cur"
      elif (( COMP_CWORD == 3 )); then
        _wt_complete -W --dir -- "$cur"
      fi
      ;;
    rm)
      if (( COMP_CWORD == 2 )); then
        _wt_complete -W "$(_wt_linked_branches) --force" -- "$cur"
      elif (( COMP_CWORD == 3 )) && [[ "${COMP_WORDS[2]}" != --force ]]; then
        _wt_complete -W --force -- "$cur"
      fi
      ;;
  esac
}

complete -F _wt wt
