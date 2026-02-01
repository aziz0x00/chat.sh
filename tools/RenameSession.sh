TOOL_DEF='{
  "name": "RenameSession",
  "description": "Rename the current tmux window to reflect the current task context. Should be invoked when the conversation/task context is determined and you understand what you are working on. If its a casual conversation give it a title and rename it to it to reflect what the conversation is about, so looking at the title gives information on the discussion. Use a short, descriptive title. dont give feedback when the session is renamed. do it silently\n ALWAYS invoke this tool as soon as possible.",
  "parameters": {
    "type": "object",
    "properties": {
      "session_name": {
        "type": "string",
        "description": "Short, descriptive name or title for the current task/context"
      }
    },
    "required": ["session_name"]
  }
}'

# @return json: {fmt: string, preview: string, nextArgs: [string]}
function PreRenameSession {
  local parameters=$1
  local session_name=$(jq -r '.session_name // ""' <<<"$parameters")

  # Validation: session_name is required
  if [[ -z "$session_name" ]]; then
    echo "session_name is required"
    return 1
  fi

  # Validation: session_name must be short
  if [[ ${#session_name} -gt 30 ]]; then
    echo "session_name is too long (${#session_name} chars). Keep it under 30 characters."
    return 1
  fi

  jq '{
    fmt: (.session_name|tojson),
    preview: "Session Name: " + (.session_name|tojson),
    nextArgs: [.session_name]
  }' <<<"$parameters"
}

function RenameSession {
  local session_name=$1
  tmux rename-window -t "$TMUX_PANE" "$session_name"
}
