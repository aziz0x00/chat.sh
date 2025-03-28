#!/bin/bash

source .id

model="@cf/meta/llama-3.2-11b-vision-instruct"

system_prompt=$(
    cat <<EOF
Respond to all questions with strict honesty and precision.
Provide answers that are short and highly concise, technical, and error-free.
Ensure responses are to the point, free of extraneous details, and limited to the most relevant information.
Double-check for accuracy before replying.
I use arch btw, keep that in mind.
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
if [ -p /dev/stdin ]; then # got pipe
    input=$(mktemp)
    cat - >$input
    if [[ $(file -b --mime-type "$input") =~ image ]]; then
        image=$(xxd -p -c 1 $input |
            awk '{ printf "%d,", strtonum("0x" $1) }' |
            sed 's/,$//; s/^/[/; s/$/]/')
    else
        user_prompt="$user_prompt"$'\n\n```n\n'"$(cat $input)"$'\n\n```\n\n'
    fi
    rm $input
fi

body=$(echo "$user_prompt" | jq -n \
    --arg system_content "$system_prompt" \
    --rawfile user_content /dev/stdin \
    '{
        "messages": [
            {"role": "system", "content": $system_content},
            {"role": "user", "content": $user_content}
        ],
        "stream": true,
        "max_tokens": '$max_tokens'
    }')
[ ! -z "$image" ] && body=$(echo $body |
    jq --slurpfile im <(echo $image) '.image = $im[0]')

shopt -s lastpipe
trap '[ -z "$user_prompt" ] && exit' INT # for interruption

while true; do
    response='""'
    total_tokens=

    exec 3> >(python mdcat.py 2>/dev/null)
    mdcat_pid=$!

    curl -N https://api.cloudflare.com/client/v4/accounts/$account_id/ai/run/$model \
        -H "Authorization: Bearer $auth" \
        --json @<(echo "$body") -s | while IFS= read -r line; do

        [ -z "$line" ] && continue

        chunk=$(echo "$line" | sed -e 's/^data: //')
        [[ $(jq .usage <<<"$chunk") != null ]] && # will proceed [DONE]
            total_tokens=$(jq -r .usage.total_tokens <<<"$chunk") &&
            break
        response=$(jq \
            --argjson r "$response" \
            --argjson c "$chunk" -n '$r + $c.response')

        jq .response -j <<<"$chunk"
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
