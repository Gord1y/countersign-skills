#!/bin/sh
set -eu
set -f

root=$(cd "$(dirname "$0")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/test-hooks.XXXXXX")
trap 'rm -rf "$work"' EXIT
work=$(cd "$work" && pwd -P)
failures=0
hook_home=

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE HARNESS_HOOK_POLICIES
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com

newline='
'
tab=$(printf '\t')
tilde='~'
hook_bin=$root/bin/harness-hook

fail() {
  echo "test-hooks: $1" >&2
  failures=$((failures + 1))
}

payload() {
  jq -nc --arg provider "$1" --arg hook "$2" --arg name "$3" --arg cwd "$4" \
    --arg command "$5" --arg path "$6" --argjson active "$7" '
    {session_id: "s1", cwd: $cwd, hook_event_name: $hook}
    + (if $provider == "codex" then {turn_id: "t1", model: "m", transcript_path: null} else {} end)
    + (if $hook == "PreToolUse" then
        {tool_name: $name, tool_input:
          (if $name == "Bash" or $name == "apply_patch" then {command: $command}
           elif $name == "NotebookEdit" then {notebook_path: $path}
           else {file_path: $path} end)}
      else {stop_hook_active: $active} end)
    + (if $hook == "SubagentStop" and $provider == "claude" then {agent_id: "a1"} else {} end)'
}

active_flag() {
  if [ "$1" = active ]; then
    echo true
  else
    echo false
  fi
}

provider_json() {
  provider=$1 event=$2 tool=$3 input=$4 cwd=$5
  case $event in
    pre_tool)
      case $tool in
        shell)
          if [ -z "$input" ]; then
            fail "a shell row has no command"
            return 1
          fi
          payload "$provider" PreToolUse Bash "$cwd" "$input" "" false
          ;;
        edit)
          if [ -z "$input" ]; then
            fail "an edit row has no path"
            return 1
          fi
          if [ "$provider" = codex ]; then
            patch="*** Begin Patch"
            verb="Add File"
            for edit_path in $input; do
              patch="$patch$newline*** $verb: $edit_path$newline+text"
              verb="Update File"
            done
            patch="$patch$newline*** End Patch"
            payload codex PreToolUse apply_patch "$cwd" "$patch" "" false
          else
            for edit_path in $input; do
              case $edit_path in
                /*) ;;
                *) edit_path=$cwd/$edit_path ;;
              esac
              payload claude PreToolUse Edit "$cwd" "" "$edit_path" false
            done
          fi
          ;;
        *)
          fail "unknown tool '$tool' for a pre_tool row"
          return 1
          ;;
      esac
      ;;
    stop | subagent_stop)
      case $input in
        active | -) ;;
        *)
          fail "a stop row's input is '$input', not active or -"
          return 1
          ;;
      esac
      if [ "$event" = stop ]; then
        payload "$provider" Stop "" "$cwd" "" "" "$(active_flag "$input")"
      else
        payload "$provider" SubagentStop "" "$cwd" "" "" "$(active_flag "$input")"
      fi
      ;;
    *)
      fail "unknown event '$event'"
      return 1
      ;;
  esac
}

run_hook() {
  hook_status=0
  hook_out=$(
    if [ -n "$hook_home" ]; then
      HOME=$hook_home
      XDG_CONFIG_HOME=$hook_home/.config
      export HOME XDG_CONFIG_HOME
    fi
    printf '%s' "$3" | HARNESS_HOOK_POLICIES=$2 "$hook_bin" "$1" 2>"$work/stderr"
  ) || hook_status=$?
  hook_err=$(cat "$work/stderr")
}

verdict() {
  if [ "$hook_status" -ne 0 ]; then
    echo bad
    return
  fi
  if [ -z "$hook_out" ]; then
    echo allow
    return
  fi
  if [ "$1" = stop ]; then
    filter='.decision == "block" and (.reason | length > 0)'
  else
    filter='.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | length > 0)'
  fi
  if printf '%s' "$hook_out" | jq -e "$filter" >/dev/null 2>&1; then
    echo deny
  else
    echo bad
  fi
}

decide() {
  provider=$1 event=$2 policies=$3 payloads=$4
  case $event in
    pre_tool) kind=pre_tool ;;
    *) kind=stop ;;
  esac
  result=allow
  printf '%s\n' "$payloads" >"$work/payloads"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    run_hook "$provider" "$policies" "$line"
    one=$(verdict "$kind")
    if [ "$one" = bad ]; then
      result=bad
    elif [ "$one" = deny ] && [ "$result" != bad ]; then
      result=deny
    fi
  done <"$work/payloads"
  echo "$result"
}

run_fixture() {
  fixture_name=$(basename "$1" .tsv)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    shape=$(printf '%s' "$line" | awk -F'\t' '{ ok = (NF == 6); for (i = 1; i <= NF; i++) if ($i == "") ok = 0; print ok ? "ok" : "bad" }')
    if [ "$shape" != ok ]; then
      fail "$fixture_name: a row does not have exactly six non-empty tab-separated fields: $line"
      continue
    fi
    printf '%s\n' "$line" >"$work/row"
    IFS=$tab read -r case_name event tool input setup expect <"$work/row"
    [ "$case_name" != case ] || continue
    case $expect in
      allow | deny) ;;
      *)
        fail "$case_name: expect is '$expect', not allow or deny"
        continue
        ;;
    esac
    dir=$work/rows/$case_name
    row_home=$work/homes/$case_name
    if [ -e "$dir" ]; then
      fail "$case_name: the case name is used twice"
      continue
    fi
    mkdir -p "$dir" "$row_home"
    git init -q "$dir"
    row_cwd=$dir
    case $setup in
      -) ;;
      block-stop) : >"$dir/block-stop" ;;
      *)
        script=$3/$fixture_name.sh
        if [ ! -f "$script" ]; then
          fail "$case_name: unknown setup state '$setup' and no $script"
          continue
        fi
        printed=$(cd "$dir" && sh "$script" "$setup" "$dir" "$row_home") || {
          fail "$case_name: $script failed for the state '$setup'"
          continue
        }
        printed=${printed%%"$newline"*}
        case $printed in
          '') ;;
          /*) row_cwd=$printed ;;
          *) row_cwd=$dir/$printed ;;
        esac
        if [ ! -d "$row_cwd" ]; then
          fail "$case_name: the cwd $row_cwd does not exist"
          continue
        fi
        ;;
    esac
    row_input=$input
    if [ "$tool" = edit ]; then
      row_input=
      for word in $input; do
        case $word in
          "$tilde/"*) word=$row_home/${word#"$tilde/"} ;;
        esac
        row_input="$row_input $word"
      done
    fi
    hook_home=$row_home
    for provider in claude codex; do
      payloads=$(provider_json "$provider" "$event" "$tool" "$row_input" "$row_cwd") || {
        fail "$case_name via $provider: the row is not valid"
        continue
      }
      if [ -z "$payloads" ]; then
        fail "$case_name via $provider: the row built no payload"
        continue
      fi
      got=$(decide "$provider" "$event" "$2" "$payloads")
      [ "$got" = "$expect" ] || fail "$case_name via $provider: expected $expect, got $got"
    done
    hook_home=
  done <"$1"
}

expect_verdict() {
  [ "$3" = "$2" ] || fail "$1: expected $2, got $3"
}

row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$@"
}

mkdir -p "$work/policies/frame" "$work/policies/broken" "$work/policies/both" "$work/policies/dump" "$work/policies/empty" "$work/policies/ext" "$work/frame-fixtures" "$work/no-fixtures"
cat >"$work/policies/frame/frame.sh" <<'POLICY'
#!/bin/sh
event=$(cat)
kind=$(printf '%s' "$event" | jq -r '.event')
cwd=$(printf '%s' "$event" | jq -r '.cwd')
if [ "$kind" = stop ] && [ -e "$cwd/block-stop" ]; then
  echo "the frame test policy blocks this stop"
  exit 10
fi
if printf '%s' "$event" | jq -e '(.command | contains("deny-me")) or any(.paths[]; contains("/denied/"))' >/dev/null; then
  echo "the frame test policy denies this call"
  exit 10
fi
exit 0
POLICY
printf '#!/bin/sh\nexit 3\n' >"$work/policies/broken/broken.sh"
printf '#!/bin/sh\nexit 3\n' >"$work/policies/both/10-broken.sh"
cp "$work/policies/frame/frame.sh" "$work/policies/both/20-frame.sh"
printf '#!/bin/sh\ncat >"$HARNESS_TEST_DUMP"\n' >"$work/policies/dump/dump.sh"

cat >"$work/policies/ext/ext.sh" <<'POLICY'
#!/bin/sh
event=$(cat)
cwd=$(printf '%s' "$event" | jq -r '.cwd')
case $cwd in
  */sub)
    if [ -e "$HOME/marker" ]; then
      echo "the ext test policy denies a call from the sub directory"
      exit 10
    fi
    ;;
esac
if printf '%s' "$event" | jq -e --arg zone "$HOME/zone/file" 'any(.paths[]; . == $zone)' >/dev/null; then
  echo "the ext test policy denies the home zone"
  exit 10
fi
exit 0
POLICY
cat >"$work/frame-fixtures/ext.sh" <<'SETUP'
#!/bin/sh
case $1 in
  nested)
    mkdir -p "$2/sub"
    : >"$3/marker"
    echo sub
    ;;
  *) exit 1 ;;
esac
SETUP

{
  row case event tool input setup expect
  row shell-denied pre_tool shell 'echo deny-me' - deny
  row shell-allowed pre_tool shell 'echo fine' - allow
  row edit-allowed pre_tool edit src/a.txt - allow
  row edit-denied pre_tool edit denied/a.txt - deny
  row patch-one-of-two-denied pre_tool edit 'src/a.txt denied/b.txt' - deny
  row dotdot-lands-outside-denied pre_tool edit 'denied/../src/ok.txt' - allow
  row stop-blocked stop - - block-stop deny
  row subagent-stop-blocked subagent_stop - - block-stop deny
  row stop-active-allowed stop - active block-stop allow
  row stop-allowed stop - - - allow
} >"$work/frame.tsv"
run_fixture "$work/frame.tsv" "$work/policies/frame" "$work/no-fixtures"

{
  row case event tool input setup expect
  row ext-state-cwd-and-home pre_tool shell 'echo hi' nested deny
  row ext-plain pre_tool shell 'echo hi' - allow
  row ext-home-path pre_tool edit "$tilde/zone/file" - deny
  row ext-home-other pre_tool edit "$tilde/other/file" - allow
} >"$work/ext.tsv"
run_fixture "$work/ext.tsv" "$work/policies/ext" "$work/frame-fixtures"

frame_cwd=$work/frame-cases
mkdir -p "$frame_cwd"
for provider in claude codex; do
  denied=$(provider_json "$provider" pre_tool shell 'echo deny-me' "$frame_cwd")

  run_hook "$provider" "$work/policies/frame" 'not json'
  expect_verdict "$provider malformed stdin" allow "$(verdict pre_tool)"
  run_hook "$provider" "$work/policies/frame" ''
  expect_verdict "$provider empty stdin" allow "$(verdict pre_tool)"

  run_hook "$provider" "$work/no-such-dir" "$denied"
  expect_verdict "$provider missing policy dir" allow "$(verdict pre_tool)"

  run_hook "$provider" "$work/policies/empty" "$denied"
  expect_verdict "$provider empty policy dir" allow "$(verdict pre_tool)"

  run_hook "$provider" "$work/policies/broken" "$denied"
  expect_verdict "$provider erroring policy" allow "$(verdict pre_tool)"
  [ "$hook_err" = "harness-hook: broken.sh exited 3, allowed" ] || fail "$provider erroring policy: stderr was '$hook_err'"

  run_hook "$provider" "$work/policies/both" "$denied"
  expect_verdict "$provider erroring policy before a denying one" deny "$(verdict pre_tool)"

  run_hook bogus "$work/policies/frame" "$denied"
  expect_verdict "bogus provider" allow "$(verdict pre_tool)"

  relative=$(payload "$provider" PreToolUse Bash relative/dir 'echo deny-me' "" false)
  run_hook "$provider" "$work/policies/frame" "$relative"
  expect_verdict "$provider relative cwd" allow "$(verdict pre_tool)"
done

mkdir -p "$work/jqfail" "$work/emptybin"
printf '#!/bin/sh\n[ "${1:-}" = -n ] && exit 2\nexec "%s" "$@"\n' "$(command -v jq)" >"$work/jqfail/jq"
chmod 755 "$work/jqfail/jq"
for provider in claude codex; do
  denied=$(provider_json "$provider" pre_tool shell 'echo deny-me' "$frame_cwd")

  printer_status=0
  printer_out=$(printf '%s' "$denied" | PATH="$work/jqfail:$PATH" HARNESS_HOOK_POLICIES=$work/policies/frame "$hook_bin" "$provider" 2>/dev/null) || printer_status=$?
  { [ "$printer_status" -eq 0 ] && [ -z "$printer_out" ]; } || fail "$provider: a failing deny printer exited $printer_status with '$printer_out'"

  nojq_status=0
  nojq_out=$(printf '%s' "$denied" | PATH="$work/emptybin" "$hook_bin" "$provider" 2>"$work/stderr") || nojq_status=$?
  { [ "$nojq_status" -eq 0 ] && [ -z "$nojq_out" ]; } || fail "$provider: a missing jq exited $nojq_status with '$nojq_out'"
  [ "$(cat "$work/stderr")" = "harness-hook: jq not found, walls off" ] || fail "$provider: a missing jq printed '$(cat "$work/stderr")'"
done

mkdir -p "$work/link"
ln -s "$root/bin/harness-hook" "$work/link/b"
ln -s b "$work/link/a"
for provider in claude codex; do
  hook_bin=$work/link/a
  run_hook "$provider" "$work/policies/frame" "$(provider_json "$provider" pre_tool shell 'echo deny-me' "$frame_cwd")"
  expect_verdict "$provider through a relative symlink chain" deny "$(verdict pre_tool)"
  hook_bin=$root/bin/harness-hook
done

neutral() {
  jq -nc --arg provider "$1" --arg event "$2" --arg tool "$3" --arg tool_name "$4" \
    --arg command "$5" --argjson paths "$6" --arg cwd "$7" --argjson subagent "$8" '
    {provider: $provider, event: $event, tool: $tool, tool_name: $tool_name, command: $command,
     paths: ($paths | unique), cwd: $cwd, session_id: "s1", subagent: $subagent, stop_hook_active: false}'
}

assert_event() {
  rm -f "$work/dump.json"
  run_hook "$2" "$work/policies/dump" "$3"
  if [ ! -s "$work/dump.json" ]; then
    fail "$1: the policy received nothing"
  elif ! jq -e --argjson want "$4" '. == $want' "$work/dump.json" >/dev/null; then
    fail "$1: the policy received $(cat "$work/dump.json"), wanted $4"
  fi
}

schema_cwd=$work/schema/proj
mkdir -p "$schema_cwd"
export HARNESS_TEST_DUMP="$work/dump.json"

assert_event "claude Edit" claude \
  "$(provider_json claude pre_tool edit x.txt "$schema_cwd")" \
  "$(neutral claude pre_tool edit Edit '' "[\"$schema_cwd/x.txt\"]" "$schema_cwd" false)"

for claude_tool in Write MultiEdit; do
  assert_event "claude $claude_tool" claude \
    "$(payload claude PreToolUse "$claude_tool" "$schema_cwd" '' "$schema_cwd/w.txt" false)" \
    "$(neutral claude pre_tool edit "$claude_tool" '' "[\"$schema_cwd/w.txt\"]" "$schema_cwd" false)"
done

assert_event "claude NotebookEdit" claude \
  "$(payload claude PreToolUse NotebookEdit "$schema_cwd" '' "$schema_cwd/n.ipynb" false)" \
  "$(neutral claude pre_tool edit NotebookEdit '' "[\"$schema_cwd/n.ipynb\"]" "$schema_cwd" false)"

assert_event "claude Read maps to other" claude \
  "$(payload claude PreToolUse Read "$schema_cwd" '' "$schema_cwd/r.txt" false)" \
  "$(neutral claude pre_tool other Read '' '[]' "$schema_cwd" false)"

assert_event "codex view_image maps to other" codex \
  "$(payload codex PreToolUse view_image "$schema_cwd" '' "$schema_cwd/i.png" false)" \
  "$(neutral codex pre_tool other view_image '' '[]' "$schema_cwd" false)"

patch="*** Begin Patch${newline}*** Update File: a.txt${newline}*** Move to: ../out/b.txt${newline}*** End Patch"
assert_event "codex apply_patch" codex \
  "$(payload codex PreToolUse apply_patch "$schema_cwd" "$patch" "" false)" \
  "$(neutral codex pre_tool edit apply_patch '' "[\"$schema_cwd/a.txt\", \"$work/schema/out/b.txt\"]" "$schema_cwd" false)"

delete_patch="*** Begin Patch${newline}*** Delete File: old.txt${newline}*** End Patch"
assert_event "codex Delete File" codex \
  "$(payload codex PreToolUse apply_patch "$schema_cwd" "$delete_patch" "" false)" \
  "$(neutral codex pre_tool edit apply_patch '' "[\"$schema_cwd/old.txt\"]" "$schema_cwd" false)"

cr=$(printf '\r')
crlf_patch="*** Begin Patch$cr${newline}*** Add File: c.txt$cr${newline}+x$cr${newline}*** End Patch$cr${newline}"
assert_event "codex CRLF patch" codex \
  "$(payload codex PreToolUse apply_patch "$schema_cwd" "$crlf_patch" "" false)" \
  "$(neutral codex pre_tool edit apply_patch '' "[\"$schema_cwd/c.txt\"]" "$schema_cwd" false)"

array_payload=$(jq -nc --arg cwd "$schema_cwd" '{session_id: "s1", cwd: $cwd, hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: ["git", "status"]}}')
assert_event "codex Bash array command" codex "$array_payload" \
  "$(neutral codex pre_tool shell Bash 'git status' '[]' "$schema_cwd" false)"

heredoc="apply_patch <<'EOF'${newline}*** Begin Patch${newline}*** Add File: x.txt${newline}+hi${newline}*** End Patch${newline}EOF"
assert_event "codex Bash heredoc patch" codex \
  "$(payload codex PreToolUse Bash "$schema_cwd" "$heredoc" "" false)" \
  "$(neutral codex pre_tool shell Bash "$heredoc" "[\"$schema_cwd/x.txt\"]" "$schema_cwd" false)"

quoted="apply_patch '*** Begin Patch${newline}*** Add File: q.txt${newline}+hi${newline}*** End Patch'"
assert_event "codex Bash quoted patch" codex \
  "$(payload codex PreToolUse Bash "$schema_cwd" "$quoted" "" false)" \
  "$(neutral codex pre_tool shell Bash "$quoted" "[\"$schema_cwd/q.txt\"]" "$schema_cwd" false)"

indented="apply_patch <<EOF${newline}  *** Begin Patch${newline}  *** Update File:   y.txt${newline}  *** End Patch${newline}EOF"
assert_event "codex Bash indented patch" codex \
  "$(payload codex PreToolUse Bash "$schema_cwd" "$indented" "" false)" \
  "$(neutral codex pre_tool shell Bash "$indented" "[\"$schema_cwd/y.txt\"]" "$schema_cwd" false)"

assert_event "claude Stop" claude \
  "$(provider_json claude stop - - "$schema_cwd")" \
  "$(neutral claude stop none '' '' '[]' "$schema_cwd" false)"

assert_event "claude SubagentStop" claude \
  "$(provider_json claude subagent_stop - - "$schema_cwd")" \
  "$(neutral claude stop none '' '' '[]' "$schema_cwd" true)"

assert_event "codex Stop" codex \
  "$(provider_json codex stop - - "$schema_cwd")" \
  "$(neutral codex stop none '' '' '[]' "$schema_cwd" false)"

assert_event "codex SubagentStop" codex \
  "$(provider_json codex subagent_stop - - "$schema_cwd")" \
  "$(neutral codex stop none '' '' '[]' "$schema_cwd" true)"

for provider in claude codex; do
  rm -f "$work/dump.json"
  run_hook "$provider" "$work/policies/dump" "$(payload "$provider" PreToolUse Bash relative/dir 'echo hi' "" false)"
  { [ ! -e "$work/dump.json" ] && [ "$(verdict pre_tool)" = allow ]; } || fail "$provider: an event with a relative cwd reached a policy"
done
unset HARNESS_TEST_DUMP

settings=$root/claude/settings.json
expected_matcher='Bash|Edit|Write|MultiEdit|NotebookEdit'
[ "$(jq -r '.hooks.PreToolUse[0].matcher' "$settings")" = "$expected_matcher" ] || fail "claude/settings.json PreToolUse matcher is not $expected_matcher"
pre_command=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$settings")
stop_command=$(jq -r '.hooks.Stop[0].hooks[0].command' "$settings")
subagent_command=$(jq -r '.hooks.SubagentStop[0].hooks[0].command' "$settings")
[ "$stop_command" = "$subagent_command" ] && [ "$pre_command" = "$stop_command" ] || fail "claude/settings.json hook commands differ"

wired_home=$work/wired-home
mkdir -p "$wired_home/.local/bin" "$work/nohome"
ln -s "$root/bin/harness-hook" "$wired_home/.local/bin/harness-hook"
block_dir=$work/wiring-stop
mkdir -p "$block_dir"
: >"$block_dir/block-stop"
pre_payload=$(provider_json claude pre_tool shell 'echo deny-me' "$frame_cwd")
stop_payload=$(provider_json claude stop - - "$block_dir")

wired_status=0
wired_out=$(printf '%s' "$pre_payload" | HOME=$work/nohome sh -c "$pre_command" 2>&1) || wired_status=$?
{ [ "$wired_status" -eq 0 ] && [ -z "$wired_out" ]; } || fail "the PreToolUse command did not fail open without harness-hook: $wired_status $wired_out"
wired_status=0
wired_out=$(printf '%s' "$stop_payload" | HOME=$work/nohome sh -c "$stop_command" 2>&1) || wired_status=$?
{ [ "$wired_status" -eq 0 ] && [ -z "$wired_out" ]; } || fail "the Stop command did not fail open without harness-hook: $wired_status $wired_out"

hook_status=0
hook_out=$(printf '%s' "$pre_payload" | HOME=$wired_home HARNESS_HOOK_POLICIES=$work/policies/frame sh -c "$pre_command" 2>/dev/null) || hook_status=$?
expect_verdict "the installed PreToolUse command" deny "$(verdict pre_tool)"
hook_status=0
hook_out=$(printf '%s' "$stop_payload" | HOME=$wired_home HARNESS_HOOK_POLICIES=$work/policies/frame sh -c "$stop_command" 2>/dev/null) || hook_status=$?
expect_verdict "the installed Stop command" deny "$(verdict stop)"

set +f
set -- "$root"/hooks/fixtures/*.tsv
set -f
for fixture in "$@"; do
  [ -f "$fixture" ] || continue
  name=$(basename "$fixture" .tsv)
  if [ ! -f "$root/hooks/policy/$name.sh" ]; then
    fail "hooks/fixtures/$name.tsv has no hooks/policy/$name.sh"
    continue
  fi
  mkdir -p "$work/real/$name"
  cp "$root/hooks/policy/$name.sh" "$work/real/$name/$name.sh"
  run_fixture "$fixture" "$work/real/$name" "$root/hooks/fixtures"
done

if [ "$failures" -gt 0 ]; then
  exit 1
fi
echo "test-hooks: ok"
