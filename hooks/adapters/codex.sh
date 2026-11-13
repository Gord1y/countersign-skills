#!/bin/sh
set -eu

jq -c '
  def base: {
    provider: "codex",
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
  def lines: split("\n") | map(rtrimstr("\r"));
  def patch_marker: "^\\s*\\*\\*\\* (Add File|Update File|Delete File|Move to): \\s*";
  def patch_paths:
    lines
    | map(select(test(patch_marker)) | sub(patch_marker; "") | sub("\\s+$"; ""))
    | map(select(. != ""));
  def has_patch: lines | any(contains("*** Begin Patch"));
  def command_text:
    if type == "array" then map(tostring) | join(" ")
    elif type == "string" then .
    else "" end;
  (.tool_name // "") as $name
  | ((try .tool_input.command catch null) | command_text) as $text
  | if .hook_event_name == "PreToolUse" then
      base | .event = "pre_tool" | .tool_name = $name
      | if $name == "Bash" then
          .tool = "shell" | .command = $text
          | if ($text | has_patch) then .paths = ($text | patch_paths) else . end
        elif $name == "apply_patch" then
          .tool = "edit" | .paths = ($text | patch_paths)
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
