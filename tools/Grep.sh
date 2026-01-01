TOOL_DEF='{
    "name": "Grep",
    "description": "Search for pattern in files. Uses ripgrep if available, falls back to grep.",
    "parameters": {
      "type": "object",
      "properties": {
        "pattern": {
          "type": "string",
          "description": "Regex pattern to search for."
        },
        "path": {
          "type": "string",
          "description": "File or directory to search (default: .)."
        },
        "include": {
          "type": "string",
          "description": "File glob filter (e.g., \"*.js\")."
        },
        "files_only": {
          "type": "boolean",
          "description": "Return only file paths, not content (default: false)."
        }
      },
      "required": ["pattern"]
    }
}'

MAX_RESULTS=100
MAX_OUTPUT=30000

# portable timeout
_timeout() {
  if command -v gtimeout &>/dev/null; then gtimeout "$@"
  elif command -v timeout &>/dev/null; then timeout "$@"
  else shift; "$@"; fi
}

function Grep {
  local pattern=$(jq -r .pattern <<<"$1")
  local path=$(jq -r '.path // "."' <<<"$1")
  local include=$(jq -r '.include // ""' <<<"$1")
  local files_only=$(jq -r '.files_only // false' <<<"$1")

  # resolve to absolute path
  path=$(realpath "$path" 2>/dev/null) || { echo "Error: Invalid path"; return 1; }

  confirm_tool "Grep(pattern='$pattern', path='$path')" || return 1

  local result exit_code

  if command -v rg &>/dev/null; then
    # ripgrep: faster, respects .gitignore
    local opts=(--color never --line-number --with-filename --max-columns 500)
    [[ "$files_only" == "true" ]] && opts+=(--files-with-matches)
    [[ -n "$include" ]] && opts+=(--glob "$include")
    opts+=(--max-count $MAX_RESULTS)

    result=$(_timeout 30 rg "${opts[@]}" -- "$pattern" "$path" 2>/dev/null)
    exit_code=$?
  else
    # fallback to grep
    local opts="-rn --color=never"
    [[ "$files_only" == "true" ]] && opts="$opts -l"
    [[ -n "$include" ]] && opts="$opts --include=$include"
    opts="$opts --exclude-dir={.git,node_modules,__pycache__}"

    result=$(_timeout 30 grep $opts "$pattern" "$path" 2>/dev/null | head -n $MAX_RESULTS)
    exit_code=$?
  fi

  # exit code 1 = no matches (not an error)
  [[ $exit_code -eq 1 ]] && { echo "No matches found."; return 0; }
  [[ $exit_code -ne 0 ]] && { echo "Error: Search failed (code $exit_code)"; return 1; }

  # truncate large output
  if [[ ${#result} -gt $MAX_OUTPUT ]]; then
    result="${result:0:$MAX_OUTPUT}"$'\n'"... (truncated)"
  fi

  [[ -z "$result" ]] && echo "No matches found." || echo "$result"
}
