TOOL_DEF='{
  "name": "ToolName",
  "description": "What this tool does",
  "parameters": {
    "type": "object",
    "properties": {
      "param": {"type": "string", "description": "..."}
    },
    "required": ["param"]
  }
}'

# PreToolName: Validate parameters, check preconditions
# Returns: {fmt: "...", preview: "...", nextArgs: [...]}
# On error: echo "message" and return 1
function PreToolName {
  local parameters=$(jq '.param = (.param // "default")' <<<"$1")

  # Add validation logic here

  jq -n --arg preview "$preview" '{
       fmt: (.param|tojson),
       preview: $preview,
       nextArgs: [.param]
     }' <<<"$parameters"
}

# ToolName: Execute the tool with args from PreToolName
# Writes result to stdout
function ToolName {
  local param=$1
  # Your logic here
}
