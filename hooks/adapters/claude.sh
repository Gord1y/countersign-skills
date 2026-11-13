#!/bin/sh
set -eu

jq -c '
  def base: {
    provider: "claude",
    event: "",
    tool: "none",
    tool_name: "",
    command: "",
    paths: [],
    cwd: (.cwd // ""),
    session_id: (.session_id // ""),
    subagent: false,
    stop_hook_active: (.stop_hook_active == true)
  };
  (.tool_name // "") as $name
  | (if (.tool_input | type) == "object" then .tool_input else {} end) as $input
  | if .hook_event_name == "PreToolUse" then
      base | .event = "pre_tool" | .tool_name = $name
      | if $name == "Bash" then
          .tool = "shell" | .command = ($input.command // "")
        elif ($name | IN("Edit", "Write", "MultiEdit", "NotebookEdit")) then
          .tool = "edit" | .paths = [($input.file_path // $input.notebook_path // empty)]
        else
          .tool = "other"
        end
    elif .hook_event_name == "Stop" then
      base | .event = "stop"
    elif .hook_event_name == "SubagentStop" then
      base | .event = "stop" | .subagent = true
    else
      empty
    end'
