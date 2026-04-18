#!/usr/bin/env zsh
# claude-mergerc
# Merge Claude Code settings fragments with interactive diff/apply.
# https://github.com/bezhermoso/claude-mergerc

claude-mergerc() {
  emulate -L zsh
  setopt local_options err_exit no_unset pipe_fail

  local fragments_dir="${CLAUDE_MERGERC_FRAGMENTS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude/fragments}"
  local output="${CLAUDE_MERGERC_OUTPUT:-$HOME/.claude/settings.json}"
  local staging="${TMPDIR:-/tmp}/claude-mergerc-staging.$$.json"

  if ! command -v jq &>/dev/null; then
    echo "error: jq is required but not found in PATH" >&2
    return 1
  fi

  if [[ ! -d "$fragments_dir" ]]; then
    echo "error: fragments dir not found: $fragments_dir" >&2
    echo "       set CLAUDE_MERGERC_FRAGMENTS_DIR to override the default." >&2
    return 1
  fi

  local fragment_count
  fragment_count=$(find "$fragments_dir" -name '*.json' | wc -l | tr -d ' ')
  if (( fragment_count == 0 )); then
    echo "error: no .json fragments in $fragments_dir" >&2
    return 1
  fi

  echo "Merging $fragment_count fragments from $fragments_dir..."

  find "$fragments_dir" -name '*.json' | sort | \
    xargs jq -s '
      def deep_merge(a; b):
        a as $a | b as $b |
        if ($a | type) == "object" and ($b | type) == "object" then
          ($a | keys) + ($b | keys) | unique | map(
            . as $k |
            if ($a | has($k)) and ($b | has($k)) then
              {($k): deep_merge($a[$k]; $b[$k])}
            elif ($b | has($k)) then {($k): $b[$k]}
            else {($k): $a[$k]}
            end
          ) | add // {}
        elif ($a | type) == "array" and ($b | type) == "array" then
          $a + $b | unique
        else $b
        end;
      reduce .[] as $item ({}; deep_merge(.; $item))
    ' > "$staging"

  if [[ ! -f "$output" ]]; then
    echo "No existing settings.json found. Will create new."
    echo ""
    jq '.' "$staging"
    echo ""
    read -q "reply?Create $output? [y/n] " || { echo "\nAborted."; rm -f "$staging"; return 0 }
    echo ""
    mkdir -p "$(dirname "$output")"
    cp "$staging" "$output"
    rm -f "$staging"
    echo "Created $output"
    return 0
  fi

  local existing_normalized merged_normalized
  existing_normalized=$(jq -S '.' "$output")
  merged_normalized=$(jq -S '.' "$staging")

  if [[ "$existing_normalized" == "$merged_normalized" ]]; then
    echo "No changes. Settings are already in sync."
    rm -f "$staging"
    return 0
  fi

  echo "Differences found:\n"

  if command -v delta &>/dev/null; then
    delta <(jq -S '.' "$output") <(jq -S '.' "$staging") --pager=never || true
  elif command -v colordiff &>/dev/null; then
    colordiff <(jq -S '.' "$output") <(jq -S '.' "$staging") || true
  else
    diff --color=auto -u <(jq -S '.' "$output") <(jq -S '.' "$staging") || true
  fi

  echo ""
  echo "  [a] Apply merged config (overwrites current)"
  echo "  [b] Backup current, then apply"
  echo "  [e] Open both in \$EDITOR (manual merge)"
  echo "  [q] Quit, no changes"
  echo ""
  local choice
  read -k 1 "choice?Choose [a/b/e/q]: "
  echo ""

  case "$choice" in
    a)
      cp "$staging" "$output"
      echo "Applied merged config to $output"
      ;;
    b)
      local backup="${output}.bak.$(date +%Y%m%d%H%M%S)"
      cp "$output" "$backup"
      cp "$staging" "$output"
      echo "Backup → $backup"
      echo "Applied merged config to $output"
      ;;
    e)
      local merge_tmp="${TMPDIR:-/tmp}/claude-mergerc-manual.$$.json"
      cp "$output" "$merge_tmp"
      ${EDITOR:-vim} -d "$merge_tmp" "$staging"
      if jq empty "$merge_tmp" 2>/dev/null; then
        read -q "reply?Apply manually merged result? [y/n] " || { echo "\nAborted."; rm -f "$staging" "$merge_tmp"; return 0 }
        echo ""
        cp "$merge_tmp" "$output"
        echo "Applied manually merged config."
      else
        echo "error: result is not valid JSON. Aborting." >&2
        rm -f "$staging" "$merge_tmp"
        return 1
      fi
      rm -f "$merge_tmp"
      ;;
    q|*)
      echo "No changes made."
      ;;
  esac

  rm -f "$staging"
}
