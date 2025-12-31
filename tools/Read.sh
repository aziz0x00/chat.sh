TOOL_DEF='{
    "name": "Read",
    "description": "Read the contents of a file from the local filesystem.",
    "parameters": {
      "type": "object",
      "properties": {
        "path": {
          "type": "string",
          "description": "Absolute or relative path to the file to read."
        },
        "offset": {
          "type": "integer",
          "minimum": 0,
          "description": "The line number to start reading from (0-based)"
        },
        "limit": {
          "type": "integer",
          "default": 2000,
          "description": "The number of lines to read"
        }
      },
      "required": ["path"]
    }
}'

function Read {
  path=$(jq -r .path <<<"$1")
  offset=$(jq -r .offset <<<"$1")
  limit=$(jq -r .limit <<<"$1")

  offset=$([[ "$offset" == "null" || -z "$offset" ]] && echo "0" || echo "$offset")
  limit=$([[ "$limit" == "null" || -z "$limit" ]] && echo "2000" || echo "$limit")

  confirm_tool "Read(path="$path", offset=$offset, limit=$limit)" || return 1

  if [[ ! -f "$path" ]]; then
    echo "Error: File '$path' does not exist."
    return 1
  fi

  tail -n +"$((offset + 1))" "$path" | head -n "$limit" 2>&1
}
