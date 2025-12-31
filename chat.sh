#!/bin/bash

_DIR=$(dirname "${BASH_SOURCE[0]}")

STATE_FILE=$(mktemp -u).json
LOGS_FILE=$(mktemp)
T=$STATE_FILE.0 # because can't do `cmd < f > f`

source "$_DIR"/.id
source "$_DIR"/providers/groq.sh

switch_model ${MODELS[0]}

set_system_prompt "$(cat "$_DIR"/system_prompt.md)"

TOOLS=()
for tool in Read Glob Write Bash; do
    source "$_DIR"/tools/${tool}.sh
    TOOLS+=("${TOOL_DEF}")
done && activate_tools

function prompt_user {
    user_prompt=""
    while [ -z "$user_prompt" ]; do
        user_prompt=$(gum input --cursor.foreground="#e5c07b" --header="$model" \
            --prompt=" ↯ " --prompt.foreground="#e5c07b" </dev/tty)
        [ $? -ne 0 ] && exit # ^D
        echo -e "\n \033[0;33m↯\033[00m $user_prompt"
    done

    case "$user_prompt" in
    /state    | /s) ${EDITOR:vim} $STATE_FILE ;;
    /continue | /c) kill $SIG_PLAY $mdcat_pid && api_completion ;; # useful after manual modification by /s
    /logs     | /l) less $LOGS_FILE ;;
    /model    | /m) switch_model $(echo ${MODELS[@]} |
        gum choose --input-delimiter=" " --cursor.foreground="#e5c07b") ;;
    *) return ;;

    esac
    prompt_user
}

function confirm_tool { # called from within tool functions
    function_invocation=$1
    echo -e "\n> $function_invocation" >&4
    kill $SIG_STOP $mdcat_pid
    sleep .1 # sometimes it goes fast
    gum confirm "Approve tool?" --selected.background="#e5c07b" --selected.foreground="#000" </dev/tty
    status_code=$?
    printf "\e[3;2m  %s\e[0m\n\n" $([[ "$status_code" -eq 0 ]] && echo "Accepted" || echo "Rejected") >/dev/tty
    kill $SIG_PLAY $mdcat_pid
    return $status_code
}

function tool_call {
    funcname=$1
    arguments=$2

    for tool in "${TOOLS[@]}"; do
        [[ "$funcname" != $(jq -r .name <<<"$tool") ]] && continue
        echo ">>> $funcname($arguments)" >>$LOGS_FILE
        "$funcname" "$arguments" | tee -a $LOGS_FILE
        echo "<<<" >>$LOGS_FILE
        break
    done
}

function __consume_pipe {
    input=$(mktemp)
    cat - >$input
    if [[ $(file -b --mime-type "$input") =~ image ]]; then
        set-attachments "$input"
    else
        user_prompt=$user_prompt$'\n\n---n\n'"$(cat $input)"
    fi
    rm $input
}

user_prompt=$@
[[ -z "$@" ]] && prompt_user
[[ -p /dev/stdin ]] && __consume_pipe # should be after prompt_user

# setup mdcat process for pretty-printing
exec 4> >(python "$_DIR"/mdcat.py 2>/dev/null)
mdcat_pid=$!
SIG_STOP=-SIGUSR1
SIG_PLAY=-SIGUSR2

trap "rm -f $LOGS_FILE; rm -f $STATE_FILE; kill $mdcat_pid 2>/dev/null" EXIT
trap '[ -z "$user_prompt" ] && exit' INT # exit on ^C if no prompt

while true; do # main loop
    api_completion "$user_prompt"

    kill $SIG_STOP $mdcat_pid && sleep .1
    [[ ! -z "$total_tokens" ]] && echo -e "\e[38;5;244m$total_tokens tokens\e[0m"
    prompt_user

    kill $SIG_PLAY $mdcat_pid
done
