MODELS=(moonshotai/kimi-k2-instruct-0905 openai/gpt-oss-120b openai/gpt-oss-20b qwen/qwen3-32b meta-llama/llama-4-maverick-17b-128e-instruct)

max_tokens=4096

echo -ne '{
    "model": "'$model'",
    "max_completion_tokens": '$max_tokens',
    "temperature": 0.6, "top_p": 1,
    "messages": [], "tools": [],
    "stream": true
}' >$STATE_FILE

function switch_model {
  model=$1
  # provider builtin tools for openai
  oai_builtin='[{ "type": "browser_search" }, { "type": "code_interpreter" }]'

  jq_inplace '.model = "'"$model"'" | .tools -= '"$oai_builtin"' | del(.reasoning_effort)'

  case "$model" in
  openai/*)
    jq_inplace '.tools += '"$oai_builtin"' | .reasoning_effort = "medium"'
    ;;
  esac
}

function activate_tools {
  for tool in "${TOOLS[@]}"; do
    jq_inplace --argjson tool "$tool" \
      '.tools += [{"type": "function", "function": $tool}]'
  done
}

function __append_message {
  role=$1
  rest=$2
  jq_inplace --arg role "$role" --argjson rest "$rest" '.messages += [{"role": $role} + $rest]'
}

function add_system_prompt {
  content=$1
  __append_message "system" "$(jq -n --arg c "$content" '{content: $c}')"
}

function set-attachments { echo "Binary attachments are not supported by the provider."; }

shopt -s lastpipe # because curl | while

function api_completion {
  prompt=$1
  [[ ! -z "$prompt" ]] && # this can be empty during tool calls
    __append_message "user" "$(jq -n --arg c "$prompt" '{content: $c}')"

  response=""
  curl "https://api.groq.com/openai/v1/chat/completions" \
    -H "Authorization: Bearer ${GROQ_API_KEY}" \
    --json @$STATE_FILE -s | while IFS= read -r line; do

    # echo "$line" >>$LOGS_FILE

    [ -z "$line" ] && continue

    grep -Eq '^data: ' <<<"$line" || {
      echo "$line" >>$LOGS_FILE
      continue
    }

    chunk=$(echo "$line" | sed -e 's/^data: //')

    [[ $(jq .usage <<<"$chunk") != null ]] && # will precede [DONE]
      total_tokens=$(jq -r .usage.total_tokens <<<"$chunk") &&
      break

    delta=$(jq '.choices[0].delta' <<<"$chunk")

    if [[ $(jq '.tool_calls' <<<"$delta") != null ]]; then
      tool=$(jq '.tool_calls[0]' <<<"$delta")
      __append_message "assistant" "$(jq '{tool_calls}' <<<"$delta")"

      funcname=$(jq -r ".function.name" <<<"$tool")
      arguments=$(jq -r ".function.arguments" <<<"$tool")

      resp=
      tool_call "$funcname" "$arguments" "resp"
      status_code=$?

      rest=$(jq --arg resp "$resp" '{tool_call_id: .id, name: .function.name, content: $resp}' <<<"$tool")
      __append_message "tool" "$rest"
      [[ "$status_code" -ne 0 ]] && return

      api_completion
      return
    fi

    [[ $(jq '.reasoning' <<<"$delta") != null ]] && {
      jq '.reasoning' -r -j <<<"$delta" >>$LOGS_FILE
      continue
    }

    [[ $(jq '.content' <<<"$delta") != null ]] && {
      jq '.content' -r -j <<<"$delta" >&4

      response="$response$(jq '.content' -r -j <<<"$delta")"
    }
  done

  __append_message "assistant" "$(jq -n --arg c "$response" '{content: $c}')"
}
