TOOL_DEF='{
    "name": "Edit",
    "description": "Replace exact string in a file. String must be unique unless replace_all is true.",
    "parameters": {
      "type": "object",
      "properties": {
        "path": {
          "type": "string",
          "description": "Path to the file to edit."
        },
        "old_string": {
          "type": "string",
          "description": "Exact string to find (must be unique)."
        },
        "new_string": {
          "type": "string",
          "description": "Replacement string."
        },
        "replace_all": {
          "type": "boolean",
          "description": "Replace all occurrences (default: false)."
        }
      },
      "required": ["path", "old_string", "new_string"]
    }
}'

function Edit {
  local path=$(jq -r .path <<<"$1")
  local old_string=$(jq -r .old_string <<<"$1")
  local new_string=$(jq -r .new_string <<<"$1")
  local replace_all=$(jq -r '.replace_all // false' <<<"$1")

  # pre-flight checks
  [[ ! -f "$path" ]] && { echo "Error: File not found: $path"; return 1; }
  [[ ! -r "$path" ]] && { echo "Error: Cannot read: $path"; return 1; }
  [[ ! -w "$path" ]] && { echo "Error: Cannot write: $path"; return 1; }

  # check binary
  file "$path" | grep -qE 'executable|binary|data' && { echo "Error: Binary file"; return 1; }

  confirm_tool "Edit(path='$path')" || return 1

  # count matches using perl (handles special chars)
  export OLD_STRING="$old_string"
  local count
  count=$(perl -0777 -ne 'print scalar(() = /\Q$ENV{OLD_STRING}\E/g)' "$path" 2>/dev/null) || count=0

  [[ "$count" -eq 0 ]] && { echo "Error: String not found in file."; return 1; }
  [[ "$count" -gt 1 && "$replace_all" != "true" ]] && {
    echo "Error: Found $count matches. Provide more context or use replace_all."
    return 1
  }

  # atomic edit: write to temp, then rename
  local tmp="${path}.tmp.$$"
  cp -p "$path" "$tmp"

  export NEW_STRING="$new_string"
  if [[ "$replace_all" == "true" ]]; then
    perl -i -0777 -pe 's/\Q$ENV{OLD_STRING}\E/$ENV{NEW_STRING}/g' "$tmp"
  else
    perl -i -0777 -pe 's/\Q$ENV{OLD_STRING}\E/$ENV{NEW_STRING}/' "$tmp"
  fi

  # validate: not empty (unless source was empty)
  if [[ -s "$path" && ! -s "$tmp" ]]; then
    rm -f "$tmp"
    echo "Error: Edit would create empty file."
    return 1
  fi

  mv "$tmp" "$path"
  echo "Edited $path ($count replacement(s))"
}
