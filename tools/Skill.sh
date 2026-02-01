TOOL_DEF='{
  "name": "Skill",
  "description": "Load a skill to get detailed instructions for a specific task. Skills provide specialized knowledge and step-by-step guidance. Use this when a task matches an available skill'\''s description.\n",
  "parameters": {
    "type": "object",
    "properties": {
      "name": {
        "type": "string",
        "description": "The skill identifier from available_skills"
      }
    },
    "required": ["name"]
  }
}'

_SKILL_PATH=${SKILL_PATH:-~/.agent/skills}

function __onStartup {
  # Create skill directory on include
  mkdir -p $_SKILL_PATH

  # Build available skills description dynamically
  local skills_list='<available_skills>'
  for skill_dir in $_SKILL_PATH/*/; do
    if [[ -d "$skill_dir" && -f "${skill_dir}SKILL.md" ]]; then
      local skill_name=$(basename "$skill_dir")
      local skill_desc=$(head -5 "${skill_dir}SKILL.md" | grep -E '^description' | sed 's/^description: //')
      if [[ -n "$skill_name" && -n "$skill_desc" ]]; then
        skills_list+="
  <skill>
    <name>$skill_name</name>
    <description>$skill_desc</description>
  </skill>
"
      fi
    fi
  done
  skills_list+='</available_skills>'

  TOOL_DEF=$(jq --arg desc "$skills_list" '.description += $desc' <<<"$TOOL_DEF")
}
__onStartup

# @return json: {fmt: string, preview: string, nextArgs: [string]}
function PreSkill {
  local name=$(jq -r '.name // ""' <<<"$1")

  [[ ! -d "$_SKILL_PATH/$name" ]] && echo "Skill not found" && return 1

  jq '{
    fmt: (.name|tojson),
    preview: "",
    nextArgs: [.name]
  }' <<<"$1"
}

function Skill {
  local name=$1
  local path="$_SKILL_PATH/$name"

  echo "<skill_root_dir>$path</skill_root_dir>"
  cat "$path/SKILL.md"
}
