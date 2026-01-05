# 🪄 chat.sh

tiny terminal LLM agent, written with simplicity and composability in mind.

## Usage

```bash
cmd1 | chat whats this
```

```bash
chat "what's a cyclic endomorphism"
```

```bash
chat
```

(TODO: add GIFs to illustrate the usage)

#### Available Tools

| Tool | Description |
|------|-------------|
| `Read` | Read file contents |
| `Write` | Write/create files |
| `Glob` | Find files by pattern |
| `Bash` | Execute shell commands |
| `Grep` | Search file contents |
| `Edit` | Replace strings in files |

All tools require your permission before execution.

#### Slash Commands

- `/state`, `/s`    opens the _state_ which is the json sent to the api in an editor, to inspect it or edit it
- `/continue`, `/c` sends the current _state_ to the API directly
- `/logs`, `/l`     displays logs, which are either outputs of executed tools or reasoning tokens
- `/model`, `/m`    change used model

## Get Started

### 1. Install dependencies

```bash
# macOS
brew install jq gum bash
pip3 install rich markdown-it-py

# Linux (Debian/Ubuntu)
apt install jq curl
# Install gum: https://github.com/charmbracelet/gum#installation
pip3 install rich markdown-it-py
```

### 2. Get API key

Get a free API key from [Groq Console](https://console.groq.com)

### 3. Setup

```bash
git clone https://github.com/aziz0x00/chat.sh.git
cd chat.sh
cp .id.example .id
# Edit .id and add your GROQ_API_KEY
```

### 4. Run

```bash
./chat.sh "hello"
```

Or create an alias:
```bash
alias chat='/path/to/chat.sh'
```

## Add Capabilities

You can add tools to chat.sh with tool files in the `tools/` directory.

A tool `Foo.sh` file should be in the following format:

```bash
TOOL_DEF='{
  "name": "Foo",
  "description": "tool description",
  "parameters": {
    --- parameter spec ---
  }
}'

function Foo {
  param1=$(jq .param1 <<< $1)

  confirm_tool "ToolName(param1='$param1')" || return 1

  # do stuff and write result to stdout
}
```

Check available tools for reference.

For now you can put your system prompt in `system_prompt.md` (the current one needs improvements).

## TODO

- make it more useful (add skill, context compression, ...)
- shorter and smaller code base
- improve code simplicity and readability
- add other providers later
