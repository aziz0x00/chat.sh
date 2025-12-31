model="/v1beta/models/gemini-3-flash-preview"

echo "Unimplemented yet" && exit

body='{
  "contents": [
    {
      "parts": [{"text": "%s"}]
    }
  ],
  "tools": [{"googleSearch": {}}]
}'

function set-system-prompt {
  system_prompt=$1
  # TODO
}

function __append_message {
  echo APPENDING: $1 >&2
  echo VAL $2 >&2
  role=$1
  rest=$2
  body=$(
    jq --arg role "$role" --argjson rest "$rest" \
      '.messages += [{"role": $role, "parts": $rest}]' <<<"$body"
  )
}

function api-completion {
  prompt="$1"

  curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
    -H "x-goog-api-key: $GOOGLE_API_KEY" \
    --json @<(echo "$body")
}
