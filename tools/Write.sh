TOOL_DEF='{
    "name": "Write",
    "description": "Write data to a file on the local filesystem, optionally creating or overwriting it.",
    "parameters": {
      "type": "object",
      "properties": {
        "path": {
          "type": "string",
          "description": "Absolute or relative path to the target file."
        },
        "content": {
          "type": "string",
          "description": "Text content to write to the file."
        },
        "mode": {
          "type": "string",
          "enum": ["w", "a"],
          "default": "w",
          "description": "`w` to overwrite, `a` to append."
        }
      },
      "required": ["path", "content"]
    }
}'

function Write {
  path=$(jq -r .path <<<"$1")
  content=$(jq -r .content <<<"$1")
  mode=$(jq -r .mode <<<"$1")

  confirm_tool "Write(path='$path', mode='$mode')" || return 1

  if [[ "$mode" == "a" ]]; then
    [[ ! -f "$path" ]] && touch "$path" 2>&1
    echo -n "$content" >>"$path"
  else
    echo -n "$content" >"$path"
  fi

  if [[ $? -eq 0 ]]; then
    echo "Successfully wrote to '$path'."
  fi
}
