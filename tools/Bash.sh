TOOL_DEF='{
    "name": "Bash",
    "description": "Execute a Bash command in a shell environment.",
    "parameters": {
      "type": "object",
      "properties": {
        "command": {
          "type": "string",
          "description": "The Bash command to execute."
        },
        "timeout": {
          "type": "integer",
          "description": "Max execution time in seconds (default: 30)."
        }
      },
      "required": ["command"]
    }
}'

MAX_OUTPUT=30000

# portable timeout: gtimeout (macOS) or timeout (Linux)
_timeout() {
  if command -v gtimeout &>/dev/null; then gtimeout "$@"
  elif command -v timeout &>/dev/null; then timeout "$@"
  else shift; "$@"; fi
}

function Bash {
  command=$(jq -r .command <<<"$1")
  timeout_secs=$(jq -r '.timeout // 30' <<<"$1")

  confirm_tool "Bash(command='$command')" || return 1

  output=$(_timeout "$timeout_secs" bash -c "$command" 2>&1)
  exit_code=$?

  # truncate large output
  if [[ ${#output} -gt $MAX_OUTPUT ]]; then
    output="${output:0:$MAX_OUTPUT}"$'\n'"... (truncated)"
  fi

  case $exit_code in
    0)   echo "$output" ;;
    124) echo "Error: Timed out after ${timeout_secs}s"$'\n'"$output" ;;
    *)   echo "Error: Exit code $exit_code"$'\n'"$output" ;;
  esac
}
