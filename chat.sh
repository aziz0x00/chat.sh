#!/bin/bash

source .id
source ./models/llama3.2-vision-instruct.sh

system_prompt=$(cat system_prompt.txt)
max_tokens=512

user_prompt=$@
prompt_user() {
    while [ -z "$user_prompt" ]; do
        echo -ne "\033[0;33m↯\033[00m"
        read -r -e -p " " user_prompt </dev/tty
        [ $? -ne 0 ] && exit # ^D
    done
}
prompt_user
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
prompt="$begin$(turn system "$system_prompt")$(turn user "$user_prompt")$end"

body='{
    "prompt": "",
    "raw": true,
    "stream": true,
    "max_tokens": '"$max_tokens"'
}'
[ ! -z "$image" ] &&
    body=$(jq --slurpfile im <(echo "$image") '.image = $im[0]' <<<"$body")

shopt -s lastpipe
trap '[ -z "$user_prompt" ] && exit' INT # for interruption

while true; do
    response=
    total_tokens=
    is_tool_call=

    exec 3> >(python mdcat.py 2>/dev/null)
    mdcat_pid=$!

    body=$(jq --arg prompt "$prompt" '.prompt += $prompt' <<<"$body")
    # echo "$body" | jq -r '.prompt'
    curl -N https://api.cloudflare.com/client/v4/accounts/$account_id/ai/run/$model \
        -H "Authorization: Bearer $auth" \
        --json @<(echo "$body") -s | while IFS= read -r line; do

        [ -z "$line" ] && continue
        chunk=$(echo "$line" | sed -e 's/^data: //')

        [[ $(jq .usage <<<"$chunk") != null ]] && # will proceed [DONE]
            total_tokens=$(jq -r .usage.total_tokens <<<"$chunk") &&
            break

        token=$(
            jq .response -r -j <<<"$chunk"
            echo .
        )
        token=${token%.} # bash :(

        response="$response$token"

        if [[ "$token" == "<|python_tag|>" ]]; then
            is_tool_call=1
            echo '```python'
            continue
        fi

        echo -ne "$token"
    done >&3

    exec 3>&-
    wait $mdcat_pid 2>/dev/null

    if [[ $is_tool_call ]]; then
        read -r -e -p "Run ? (y/n) " yn </dev/tty
        if [[ "$yn" == "y" ]]; then
            output=$(python <(echo "$response" | cut -c15- -z | tr -d '\0') 2>&1)
            echo COMMAND OUT: "$output" | less
            prompt="$response$eom$(turn ipython "$output")$end"
            continue
        fi
    fi

    [ ! -z "$total_tokens" ] && echo -e "\033[38;5;244m$total_tokens tokens\033[0m"

    user_prompt=''
    prompt_user
    prompt="$response$eot$(turn user "$user_prompt")$end"
done
