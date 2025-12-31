# 🪄 chat.sh

tiny terminal LLM agent, written with simplicity and composability in mind.

## Usage

```bash
cmd1 | chat whats this
```

```bash
chat "what's an cyclic endomorphism"
```

```bash
chat
```

(TODO: add GIFs to illustrate the usage)

#### Available Tools

It can read, write, execute command on system at your permission

#### Slash Commands

- `/state`, `/s`    opens the _state_ which is the json sent to the api in an editor, to inspect it or edit it
- `/continue`, `/c` sends the current _state_ to the API directly
- `/logs`, `/l`     displays logs, which are either outputs of executed tools or reasoning tokens
- `/model`, `/m`    change used model

## Get Started

Make sure to have [jq](https://github.com/jqlang/jq) and [gum](https://github.com/charmbracelet/gum) installed

Clone the repo, save it somewhere and alias `chat.sh` to a command name of your preference

```bash
alias j='/path/to/chat.sh'
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

Check available tools for reference

For now you can put your system prompt in `system_prompt.md` (the current one needs improvements)..

## TODO

- make it more useful (add skill, context compression, ...)
- shorter and smaller code base
- improve code simplicity and readability
- add other providers later
