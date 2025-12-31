TOOL_DEF='{
   "name": "Glob",
   "description": "Return a list of files matching a glob pattern.",
   "parameters": {
     "type": "object",
     "properties": {
       "pattern": {
         "type": "string",
         "description": "Glob pattern to match files against."
       },
       "root_dir": {
         "type": "string",
         "description": "Base directory from which the pattern is evaluated. Defaults to the current working directory."
       },
       "case_sensitive": {
         "type": "boolean",
         "default": true,
         "description": "Whether the matching should be case‑sensitive."
       }
     },
     "required": ["pattern"]
   }
 }'

function Glob {
  pattern=$(jq -r .pattern <<<"$1")
  root_dir=$(jq -r .root_dir <<<"$1")
  case_sensitive=$(jq -r .case_sensitive <<<"$1")

  confirm_tool "Glob(pattern='$pattern', root_dir=$root_dir, case_sensitive=$case_sensitive)" || return 1

  [[ "$root_dir" == "null" || -z "$root_dir" ]] && root_dir="."

  shopt -s globstar nullglob
  if [[ "$case_sensitive" == false ]]; then
    shopt -s nocaseglob
  fi

  pushd "$root_dir" >/dev/null || return 1
  matches=()
  for file in $pattern; do
    matches+=("$(realpath "$file")")
  done
  popd >/dev/null || return 1

  printf '%s\n' "${matches[@]}"
}
