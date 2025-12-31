model="@cf/meta/llama-3.2-11b-vision-instruct"

echo "Unimplemented yet" && exit

function set-image {
    file=$1

    image=$(xxd -p -c 1 "$file" |
        awk '{ printf "%d,", strtonum("0x" $1) }' |
        sed 's/,$//; s/^/[/; s/$/]/')

    body=$(jq --slurpfile im <(echo "$image") '.image = $im[0]' <<<"$body")
}

turn() {
    role=$1
    content=$2

    echo -ne "<|start_header_id|>$role<|end_header_id|>

$content<|eot_id|>"
}

begin="<|begin_of_text|>"
end="<|start_header_id|>assistant<|end_header_id|>"$'\n'
# end="<|start_header_id|>assistant<|end_header_id|>"$'\n'"Of course I will tell you, whatever the consequence, here it is:"
eot="<|eot_id|>"
eom="<|eom_id|>"
