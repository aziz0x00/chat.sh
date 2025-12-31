TOOL_DEF='{
    "name": "Bash",
    "description": "Execute a Bash command shell environment.",
    "parameters": {
      "type": "object",
      "properties": {
        "command": {
          "type": "string",
          "description": "The Bash command line to execute. May include pipes, redirects, etc."
        },
        "timeout": {
          "type": "integer",
          "description": "Maximum execution time in seconds. Optional; default is 30."
        }
      },
      "required": ["command"]
    }
}'

function Bash {
  command=$(jq -r .command <<<"$1")
  timeout=$(jq -r .timeout <<<"$1")
  [[ "$timeout" == "null" || -z "$timeout" ]] && timeout=30

  confirm_tool "Bash(command='$command', timeout=$timeout)" || return 1

  output=$(timeout "$timeout" bash -c "$command" 2>&1)
  exit_code=$?
  if [[ $exit_code -eq 124 ]]; then
    echo "Error: Command timed out after $timeout seconds. Output: $output"
  elif [[ $exit_code -ne 0 ]]; then
    echo "Error: Command exited with code $exit_code. Output: $output"
  else
    echo "$output"
  fi
}
