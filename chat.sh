#!/bin/bash

source .id

model="@cf/meta/llama-3.2-11b-vision-instruct"

system_prompt=$(
    cat <<EOF
Respond to all questions with strict honesty and precision.
Provide answers that are short and highly concise, technical, and error-free.
Ensure responses are to the point, free of extraneous details, and limited to the most relevant information.
Double-check for accuracy before replying.
Format code to make sure lines are less than 80
EOF
)
max_tokens=512

user_prompt=$@
prompt_user() {
    while [ -z "$user_prompt" ]; do
        echo -ne "\033[0;33m↯\033[00m"
        read -r -e -p " " user_prompt </dev/tty
        [ $? -ne 0 ] && exit # ^D
    done
}
[ -z "$user_prompt" ] && prompt_user
if [ -p /dev/stdin ]; then
    user_prompt="$user_prompt"$'\n\n------------\n\n'"$(cat -)"$'\n\n------------'
fi

body=$(jq -n \
    --arg system_content "$system_prompt" \
    --arg user_content "$user_prompt" \
    '{
        "messages": [
            {"role": "system", "content": $system_content},
            {"role": "user", "content": $user_content}
        ],
        "stream": true,
        "max_tokens": '$max_tokens'
    }')

shopt -s lastpipe
trap '[ -z "$user_prompt" ] && exit' INT # for interruption

while true; do
    response='""'
    total_tokens=

    exec 3> >(python mdcat.py 2>/dev/null)
    mdcat_pid=$!

    curl -N https://api.cloudflare.com/client/v4/accounts/$account_id/ai/run/$model \
        -H "Authorization: Bearer $auth" \
        --json "$body" -s | while IFS= read -r line; do

        [ -z "$line" -o "$line" = "data: [DONE]" ] && continue

        chunk=$(echo "$line" | sed -e 's/^data: //')
        echo $chunk | jq .response -j
        if [ ! -z "$(jq -r .usage <<<"$chunk")" ]; then
            total_tokens=$(jq -r .usage.total_tokens <<<"$chunk")
        fi

        response=$(echo $chunk |
            jq --argjson r "$response" '$r + .response' 2>/dev/null)
    done >&3

    exec 3>&-
    wait $mdcat_pid 2>/dev/null

    [ ! -z "$total_tokens" ] && echo -e "\033[38;5;244m$total_tokens tokens\033[0m"

    user_prompt=''
    prompt_user
    body=$(echo $body | jq \
        --argjson response "$response" \
        --arg user_prompt "$user_prompt" \
        '.messages += [
            { "role": "assistant", "content": $response },
            { "role": "user", "content": $user_prompt}
         ]')
    # echo $body | jq # debug
done
