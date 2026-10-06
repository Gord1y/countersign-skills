#!/bin/sh
set -eu
unset XDG_CONFIG_HOME

root=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$root/lib.sh"
home=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
copyhome=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
fake=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
updhome=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$home" "$copyhome" "$fake" "$updhome"' EXIT

fail() {
  echo "test.sh: $1" >&2
  exit 1
}

sh -n "$root/install.sh"
sh -n "$root/update.sh"
sh -n "$root/uninstall.sh"
sh -n "$root/lib.sh"
for script in "$root"/bin/* "$root"/skills/*/scripts/*; do
  [ "$(head -n 1 "$script")" = "#!/bin/sh" ] || continue
  sh -n "$script"
done

mkdir -p "$home/.codex" "$home/.claude/skills/orchestrate"
echo old >"$home/.claude/skills/orchestrate/SKILL.md"
echo '{"hooks": {"Stop": []}, "theme": "light", "permissions": {"allow": ["Read(//kept)"], "ask": ["Bash(kept-ask *)"]}}' >"$home/.claude/settings.json"

HOME=$home CLAUDE_CONFIG_DIR= "$root/install.sh" >/dev/null

[ "$(readlink "$home/.claude/skills/orchestrate")" = "$root/skills/orchestrate" ] || fail "orchestrate is not linked for Claude Code"
for agent in "$root"/agents/*.md; do
  name=$(basename "$agent" .md)
  [ "$(readlink "$home/.claude/agents/$name.md")" = "$agent" ] || fail "$name.md is not linked for Claude Code"
  frontmatter=$(sed -n '2,/^---$/p' "$agent")
  echo "$frontmatter" | grep -q '^model: ' || fail "agents/$name.md does not set a model"
  if echo "$frontmatter" | grep -q '^skills: *[^ ]'; then
    fail "agents/$name.md lists its skills inline; write them as a YAML list so this test can check them"
  fi
  for skill in $(echo "$frontmatter" | awk '/^skills:/ { on = 1; next } on && /^  - / { sub(/^  - /, ""); print; next } { on = 0 }'); do
    [ -f "$root/skills/$skill/SKILL.md" ] || fail "agents/$name.md preloads $skill, which skills/ does not have"
    if grep -q '^disable-model-invocation: true' "$root/skills/$skill/SKILL.md"; then
      fail "agents/$name.md preloads $skill, which sets disable-model-invocation and so can't be preloaded"
    fi
  done
done
[ -L "$home/.agents/skills/context-transfer" ] || fail "context-transfer is not linked for Codex"
[ ! -e "$home/.agents/skills/orchestrate" ] || fail "orchestrate was linked for Codex, which skills.tsv excludes"
[ ! -e "$home/.gemini" ] || fail "an Antigravity folder was created although Antigravity is not installed"
ls "$home"/.config/countersign/skills/backups/*/claude/orchestrate/SKILL.md >/dev/null 2>&1 || fail "the existing orchestrate folder was not backed up"
grep -q "@$root/rules/code.md" "$home/.claude/CLAUDE.md" || fail "CLAUDE.md was not written from claude/CLAUDE.template.md"
[ "$(readlink "$home/.local/bin/statusline")" = "$root/bin/statusline" ] || fail "statusline is not linked into ~/.local/bin"
settings_json="$home/.claude/settings.json"
jq -e '.hooks.Stop == [] and .theme == "light" and .worktree.baseRef == "head" and .sandbox.enabled == true and (.permissions.allow | index("Read(//kept)") != null) and (.permissions.allow | index("mcp__context7") != null) and (.permissions.ask | index("Bash(kept-ask *)") != null) and (.permissions.ask == ["Bash(kept-ask *)"]) and (.permissions.deny | index("Read(~/.ssh/**)") != null) and (.sandbox.filesystem.denyRead | index("~/.ssh") != null)' "$settings_json" >/dev/null || fail "settings.json was not merged from settings/claude.json"
jq -e '(.permissions.deny | index("Read(**/.env)") != null) and ([.permissions.deny[] | select(test("^Read\\((\\*\\*/)?\\.env(\\.\\*)?\\)$"))] == ["Read(**/.env)"]) and ([.sandbox.filesystem.allowRead[]? | select(contains(".env"))] == [])' "$settings_json" >/dev/null || fail "settings.json must deny .env at any depth by name, never .env.* (it hides .env.example) or root-only rules, and needs no .env allowRead"
jq -e --slurpfile shipped "$root/claude/settings.json" '($shipped[0].sandbox.filesystem.allowWrite | length) > 0 and ($shipped[0].sandbox.filesystem.allowWrite - .sandbox.filesystem.allowWrite) == []' "$settings_json" >/dev/null || fail "settings.json lost a sandbox.filesystem.allowWrite path that claude/settings.json lists"
jq -e '.skillListingBudgetFraction >= 0.02' "$settings_json" >/dev/null || fail "settings.json must raise skillListingBudgetFraction to 0.02, or a 200K window drops skill descriptions"
ls "$home"/.config/countersign/skills/backups/*/claude-settings/settings.json >/dev/null 2>&1 || fail "the existing settings.json was not backed up"
jq -e --arg installed "Read(/$home/.claude/skills/**)" --arg shipped "Read(/$root/skills/**)" --arg real "Read(/$(cd "$root" && pwd -P)/skills/**)" '.permissions.allow | (index($installed) != null) and (index($shipped) != null) and (index($real) != null)' "$settings_json" >/dev/null || fail "settings.json does not allow reading the installed skills and the folders their links point to"
if user_tmp=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null); then
  jq -e --arg t "${user_tmp%/}" '.sandbox.filesystem.allowWrite | index($t) != null' "$settings_json" >/dev/null || fail "settings.json does not let the sandbox write the macOS user temp folder"
fi
grep -q '^## Code$' "$home/.codex/AGENTS.md" || fail "AGENTS.md does not expand the code rule"
grep -q '^## Planning and orchestration$' "$home/.codex/AGENTS.md" && fail "AGENTS.md took the orchestration rule, which rules.tsv keeps for Claude Code"
grep -q '^@' "$home/.codex/AGENTS.md" && fail "AGENTS.md kept an unexpanded import"
cut -f1 "$root/rules.tsv" | while read -r rule; do
  [ -f "$root/rules/$rule.md" ] || fail "rules.tsv lists $rule but rules/$rule.md is missing"
done
for file in "$root"/rules/*.md; do
  grep -q "^$(basename "$file" .md)$(printf '\t')" "$root/rules.tsv" || fail "rules.tsv does not list $(basename "$file")"
done
local_line='If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.'
for skill in "$root"/skills/*/; do
  name=$(basename "$skill")
  grep -q "^$name$(printf '\t')" "$root/skills.tsv" || fail "skills.tsv does not list skills/$name"
  [ "$(tail -n 1 "$skill/SKILL.md")" = "$local_line" ] || fail "skills/$name/SKILL.md does not end with the local.md line"
  [ "$(awk '/^description:/ { print; exit }' "$skill/SKILL.md" | tr -d '\n' | wc -c)" -le 200 ] || fail "skills/$name/SKILL.md has a description line over 200 bytes"
  [ "$(awk '/^name:/ { sub(/^name: */, ""); gsub(/"/, ""); print; exit }' "$skill/SKILL.md")" = "$name" ] || fail "skills/$name/SKILL.md has a frontmatter name that differs from its folder"
  skill_frontmatter=$(sed -n '2,/^---$/p' "$skill/SKILL.md")
  echo "$skill_frontmatter" | grep -E '^[a-z_-]+: [^"]' | grep -qE ': .*(: | #)' && fail "skills/$name/SKILL.md has an unquoted frontmatter value with ': ' or ' #', which strict YAML parsers such as Codex's and skills.sh's reject; wrap it in double quotes"
  if ! echo "$skill_frontmatter" | grep -q '^disable-model-invocation: true'; then
    echo "$skill_frontmatter" | grep -q '^when_to_use: ' || fail "skills/$name/SKILL.md is model-invocable but has no when_to_use"
  fi
done
grep -qi 'never start' "$root/skills/qa-tester/SKILL.md" || fail "skills/qa-tester/SKILL.md lost its never-start rule"
invocable=""
for skill in "$root"/skills/*/; do
  name=$(basename "$skill")
  sed -n '2,/^---$/p' "$skill/SKILL.md" | grep -q '^disable-model-invocation: true' && continue
  invocable="$invocable $name"
  pattern="(?:[\\w-]+:)?$name\""
  for kind in fires quiet; do
    case_dir="$root/evals/$name-$kind"
    [ -f "$case_dir/prompt.md" ] || fail "evals/$name-$kind/prompt.md is missing for the model-invocable skill $name"
  done
  fires_grader="$root/evals/$name-fires/graders/skill-fired.md"
  quiet_grader="$root/evals/$name-quiet/graders/skill-quiet.md"
  [ -f "$fires_grader" ] || fail "evals/$name-fires/graders/skill-fired.md is missing for the skill $name"
  [ -f "$quiet_grader" ] || fail "evals/$name-quiet/graders/skill-quiet.md is missing for the skill $name"
  grep -qF "$pattern" "$fires_grader" || fail "the fires grader of $name does not match the skill name $name"
  grep -q 'max: 0' "$fires_grader" && fail "the fires grader of $name caps the Skill calls at zero"
  grep -qF "$pattern" "$quiet_grader" || fail "the quiet grader of $name does not match the skill name $name"
  grep -q 'max: 0' "$quiet_grader" || fail "the quiet grader of $name does not cap the Skill calls at zero"
done
for case_dir in "$root"/evals/*/; do
  case_name=$(basename "$case_dir")
  [ "$case_name" = results ] && continue
  skill_name=${case_name%-fires}
  [ "$skill_name" = "$case_name" ] && skill_name=${case_name%-quiet}
  case " $invocable " in
    *" $skill_name "*) [ "$skill_name" != "$case_name" ] || fail "evals/$case_name is not named after a skill with -fires or -quiet" ;;
    *) fail "evals/$case_name does not belong to an existing model-invocable skill" ;;
  esac
done
"$root/scripts/catalog.sh" --check >/dev/null || fail "catalog.json is out of date; run scripts/catalog.sh"
jq -e \
  --argjson skills "$(wc -l <"$root/skills.tsv" | tr -d ' ')" \
  --argjson rules "$(wc -l <"$root/rules.tsv" | tr -d ' ')" \
  --argjson agents "$(ls -1 "$root"/agents/*.md | wc -l | tr -d ' ')" \
  '(.skills | length) == $skills and (.rules | length) == $rules and (.agents | length) == $agents
    and (.skills[] | select(.name == "memory-review") | .invocation) == "manual"
    and (.skills[] | select(.name == "orchestrate") | .invocation == "model" and .whenToUse != null)
    and (.agents[] | select(.name == "builder") | .model) == "sonnet"' "$root/catalog.json" >/dev/null || fail "catalog.json does not match the skills, rules and agents in the repo"
git -C "$root" check-ignore -q skills/orchestrate/local.md || fail "a skill's local.md is not gitignored"

ln -s "$root/skills/removed-skill" "$home/.claude/skills/removed-skill"
ln -s "$fake/elsewhere" "$home/.claude/skills/foreign-link"
second=$(HOME=$home CLAUDE_CONFIG_DIR= "$root/install.sh")
[ ! -L "$home/.claude/skills/removed-skill" ] || fail "a link to a skill that no longer exists was kept"
[ -L "$home/.claude/skills/foreign-link" ] || fail "a dangling link from outside this repo was removed"
echo "$second" | grep -q '^moved' && fail "a second run moved something"
echo "$second" | grep -q "^ok      $home/.claude/CLAUDE.md" || fail "a second run rewrote an unchanged CLAUDE.md"
echo "$second" | grep -q "^ok      $home/.codex/AGENTS.md" || fail "a second run rewrote an unchanged AGENTS.md"
echo "$second" | grep -q "^ok      $settings_json" || fail "a second run rewrote an unchanged settings.json"
jq '.worktree.baseRef = "changed"' "$settings_json" >"$settings_json.tmp" && mv "$settings_json.tmp" "$settings_json"
HOME=$home CLAUDE_CONFIG_DIR= "$root/install.sh" --no-settings >/dev/null
[ "$(jq -r .worktree.baseRef "$settings_json")" = changed ] || fail "--no-settings changed settings.json"

echo edited >"$home/.codex/AGENTS.md"
out=$(HOME=$home CLAUDE_CONFIG_DIR= "$root/install.sh")
echo "$out" | grep -q "^moved   $home/.codex/AGENTS.md" || fail "a changed AGENTS.md was not backed up"
grep -q '^## Code$' "$home/.codex/AGENTS.md" || fail "a changed AGENTS.md was not regenerated"

echo edited >"$home/.claude/CLAUDE.md"
out=$(HOME=$home CLAUDE_CONFIG_DIR= "$root/install.sh")
echo "$out" | grep -q "^moved   $home/.claude/CLAUDE.md" || fail "a changed CLAUDE.md was not backed up"
grep -q "@$root/rules/code.md" "$home/.claude/CLAUDE.md" || fail "a changed CLAUDE.md was not rewritten from claude/CLAUDE.template.md"

out=$(HOME=$home CLAUDE_CONFIG_DIR= "$root/install.sh" --skills human-voice-writing)
echo "$out" | grep -q orchestrate && fail "--skills did not filter"

HOME=$copyhome CLAUDE_CONFIG_DIR= "$root/install.sh" --copy >/dev/null
copied="$copyhome/.claude/skills/orchestrate"
[ -d "$copied" ] && [ ! -L "$copied" ] && cmp -s "$copied/SKILL.md" "$root/skills/orchestrate/SKILL.md" || fail "--copy did not copy orchestrate"
orchestrate_version=$(awk -F "$(printf '\t')" '$1 == "orchestrate" { print $2 }' "$root/skills.tsv")
grep -qF "$(printf 'claude\torchestrate\t%s\tSKILL.md\t%s' "$orchestrate_version" "$(sha256_of "$root/skills/orchestrate/SKILL.md")")" "$copyhome/.config/countersign/skills/manifest.tsv" || fail "the manifest does not record orchestrate's SKILL.md"
cmp -s "$copyhome/.config/countersign/skills/base/claude/orchestrate/SKILL.md" "$root/skills/orchestrate/SKILL.md" || fail "the shipped orchestrate was not kept as the base"

echo edited >>"$copied/SKILL.md"
third=$(HOME=$copyhome CLAUDE_CONFIG_DIR= "$root/install.sh" --copy)
echo "$third" | grep -q '^moved' && fail "a second --copy run replaced an edited copy"
[ "$(tail -n 1 "$copied/SKILL.md")" = edited ] || fail "a second --copy run replaced an edited copy"

HOME=$copyhome CLAUDE_CONFIG_DIR= "$root/install.sh" --skills orchestrate >/dev/null
[ -L "$copied" ] || fail "link mode did not take orchestrate back from the copy"
grep -q "^claude$(printf '\t')orchestrate$(printf '\t')" "$copyhome/.config/countersign/skills/manifest.tsv" && fail "link mode did not take orchestrate back from the copy"

for item in install.sh update.sh lib.sh skills.tsv rules.tsv skills rules agents bin claude; do
  cp -R "$root/$item" "$fake/"
done
movehome=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
mkdir -p "$movehome/.codex"
HOME=$movehome CLAUDE_CONFIG_DIR= "$root/install.sh" >/dev/null
HOME=$movehome CLAUDE_CONFIG_DIR= "$fake/install.sh" >/dev/null
[ ! -e "$movehome/.config/countersign/skills/originals/CLAUDE.md" ] && [ ! -e "$movehome/.config/countersign/skills/originals/AGENTS.md" ] || fail "installing from a moved copy of the repo kept the generated CLAUDE.md or AGENTS.md as the user's originals"
rm -rf "$movehome"

former=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
formerhome=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
for item in install.sh lib.sh skills.tsv rules.tsv skills rules agents bin claude; do
  cp -R "$root/$item" "$former/"
done
mkdir -p "$former/skills/retired-skill" "$formerhome/reinstall" "$formerhome/uninstall"
printf -- '---\nname: retired-skill\n---\n' >"$former/skills/retired-skill/SKILL.md"
printf 'retired-skill\t1.0.0\tclaude\n' >>"$former/skills.tsv"
printf '#!/bin/sh\n' >"$former/bin/retired-tool"
HOME=$formerhome/reinstall CLAUDE_CONFIG_DIR= "$former/install.sh" >/dev/null
HOME=$formerhome/uninstall CLAUDE_CONFIG_DIR= "$former/install.sh" >/dev/null
rm -rf "$former"
HOME=$formerhome/reinstall CLAUDE_CONFIG_DIR= "$root/install.sh" >/dev/null
[ ! -L "$formerhome/reinstall/.claude/skills/retired-skill" ] && [ ! -L "$formerhome/reinstall/.local/bin/retired-tool" ] || fail "install.sh kept a dangling link into the folder an earlier run installed from"
jq -e --arg moved "$(basename "$former")/skills" --arg current "Read(/$root/skills/**)" '.permissions.allow | (map(select(contains($moved))) == []) and (index($current) != null)' "$formerhome/reinstall/.claude/settings.json" >/dev/null || fail "install.sh kept the Read rule for the folder an earlier run installed from"
HOME=$formerhome/uninstall CLAUDE_CONFIG_DIR= "$root/uninstall.sh" >/dev/null
[ -z "$(find "$formerhome/uninstall" -type l)" ] || fail "uninstall.sh left a link into the folder an earlier install used"
rm -rf "$formerhome"
HOME=$updhome CLAUDE_CONFIG_DIR= "$fake/install.sh" --copy >/dev/null

prepend_line() {
  { echo "new first line"; cat "$1"; } >"$1.tmp"
  mv "$1.tmp" "$1"
}
replace_second_to_last() {
  lines=$(wc -l <"$1")
  { head -n $((lines - 2)) "$1"; echo "$2"; tail -n 1 "$1"; } >"$1.tmp"
  mv "$1.tmp" "$1"
}
prepend_line "$fake/skills/context-transfer/SKILL.md"
prepend_line "$fake/skills/orchestrate/SKILL.md"
replace_second_to_last "$fake/skills/memory-review/SKILL.md" "shipped change"
shipped() {
  awk -F "$tab" -v name="$1" '$1 == name { print $2 }' "$root/skills.tsv"
}
awk -F "$tab" -v OFS="$tab" '{ $2 = "99.0.0"; print }' "$fake/skills.tsv" >"$fake/skills.tsv.tmp"
mv "$fake/skills.tsv.tmp" "$fake/skills.tsv"

installed="$updhome/.claude/skills"
echo "my edit" >>"$installed/orchestrate/SKILL.md"
replace_second_to_last "$installed/memory-review/SKILL.md" "my change"
echo mine >"$installed/orchestrate/local.md"

out=$(HOME=$updhome CLAUDE_CONFIG_DIR= "$fake/update.sh") && status=0 || status=$?
[ "$status" -eq 1 ] || fail "update.sh did not exit 1 on a conflict"
echo "$out" | grep -qx "updated claude context-transfer $(shipped context-transfer) -> 99.0.0" && cmp -s "$installed/context-transfer/SKILL.md" "$fake/skills/context-transfer/SKILL.md" || fail "an untouched copy was not updated"
echo "$out" | grep -q "^merged  claude orchestrate $(shipped orchestrate) -> 99.0.0" \
  && [ "$(head -n 1 "$installed/orchestrate/SKILL.md")" = "new first line" ] \
  && [ "$(tail -n 1 "$installed/orchestrate/SKILL.md")" = "my edit" ] \
  && [ "$(tail -n 1 "$installed/orchestrate/SKILL.md.mine")" = "my edit" ] \
  && [ "$(head -n 1 "$installed/orchestrate/SKILL.md.mine")" != "new first line" ] || fail "an edited copy was not merged cleanly"
echo "$out" | grep -q "^conflict claude memory-review" && grep -q '^<<<<<<<' "$installed/memory-review/SKILL.md" && [ -f "$installed/memory-review/SKILL.md.mine" ] || fail "a conflicting edit was not marked"
[ "$(cat "$installed/orchestrate/local.md")" = mine ] || fail "update.sh touched local.md"
grep -qF "$(printf 'claude\torchestrate\t99.0.0\tSKILL.md\t%s' "$(sha256_of "$fake/skills/orchestrate/SKILL.md")")" "$updhome/.config/countersign/skills/manifest.tsv" || fail "the manifest was not moved to the new version"

cp -R "$installed/orchestrate" "$updhome/orchestrate-before"
second_update=$(HOME=$updhome CLAUDE_CONFIG_DIR= "$fake/update.sh") || true
echo "$second_update" | grep -qx "ok      claude context-transfer 99.0.0" || fail "a second update changed something"
[ "$(find "$installed/orchestrate" -type f | wc -l)" -eq "$(find "$updhome/orchestrate-before" -type f | wc -l)" ] || fail "a second update changed something"
for file in SKILL.md SKILL.md.mine local.md; do
  cmp -s "$installed/orchestrate/$file" "$updhome/orchestrate-before/$file" || fail "a second update changed something"
done

profhome=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
extra=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")" && pwd)
trap 'rm -rf "$home" "$copyhome" "$fake" "$updhome" "$profhome" "$extra"' EXIT
prof="$profhome/.config/countersign/profile"
state_dir="$profhome/.config/countersign/skills"
mkdir -p "$prof/bin" "$profhome/.claude" "$profhome/.codex"
printf 'Profile marker\n@{ROOT}/rules/code.md\n' >"$prof/CLAUDE.md"
echo '{"theme": "profile-theme", "permissions": {"allow": ["Read(//profile)"]}, "sandbox": {"filesystem": {"allowWrite": ["~/profile-cache"]}}, "autoMode": {"allow": ["profile rule"]}}' >"$prof/settings.json"
printf '#!/bin/sh\n' >"$prof/bin/profile-tool"
chmod +x "$prof/bin/profile-tool"
for run in 01 02 03 04 05 06 07; do
  mkdir -p "$state_dir/backups/20260101-0000$run"
done
mkdir -p "$extra/skills/extra-skill" "$extra/rules" "$extra/agents"
printf -- '---\nname: extra-skill\ndescription: x\n---\n' >"$extra/skills/extra-skill/SKILL.md"
printf 'extra-skill\t1.0.0\tclaude\n' >"$extra/skills.tsv"
printf '## Extra rule\n' >"$extra/rules/extra-rule.md"
printf 'extra-rule\tclaude,codex\n' >"$extra/rules.tsv"
printf -- '---\nname: extra-agent\ndescription: y\n---\n' >"$extra/agents/extra-agent.md"
"$root/scripts/catalog.sh" "$extra" >/dev/null
jq -e '. == {"schemaVersion":1,"skills":[{"name":"extra-skill","version":"1.0.0","agents":["claude"],"description":"x","whenToUse":null,"invocation":"model","path":"skills/extra-skill"}],"rules":[{"name":"extra-rule","title":"Extra rule","agents":["claude","codex"],"path":"rules/extra-rule.md"}],"agents":[{"name":"extra-agent","description":"y","model":null,"path":"agents/extra-agent.md"}]}' "$extra/catalog.json" >/dev/null || fail "catalog.sh did not write the expected catalog for an addition"
echo '{}' >"$extra/catalog.json"
"$root/scripts/catalog.sh" --check "$extra" >/dev/null 2>&1 && fail "catalog.sh --check passed on a stale catalog"
HOME=$profhome CLAUDE_CONFIG_DIR= "$root/install.sh" --addition "$extra" >/dev/null
[ "$(ls -1 "$state_dir/backups" | wc -l)" -eq 5 ] && [ ! -e "$state_dir/backups/20260101-000001" ] || fail "the backups were not pruned to the newest 5"
grep -qx 'Profile marker' "$profhome/.claude/CLAUDE.md" && grep -qx "@$root/rules/code.md" "$profhome/.claude/CLAUDE.md" || fail "CLAUDE.md was not written from the profile"
grep -qx "@$extra/rules/extra-rule.md" "$profhome/.claude/CLAUDE.md" || fail "the addition's rule was not imported into CLAUDE.md"
grep -qx '## Extra rule' "$profhome/.codex/AGENTS.md" || fail "AGENTS.md did not expand the addition's rule"
jq -e '.theme == "profile-theme" and (.permissions.allow | index("Read(//profile)") != null) and (.permissions.allow | index("mcp__context7") != null)' "$profhome/.claude/settings.json" >/dev/null || fail "the profile's settings were not layered over the repo's"
jq -e --slurpfile shipped "$root/claude/settings.json" '(.sandbox.filesystem.allowWrite | index("~/profile-cache") != null) and ($shipped[0].sandbox.filesystem.allowWrite - .sandbox.filesystem.allowWrite) == [] and (.autoMode.allow | index("profile rule") != null) and ($shipped[0].autoMode.allow - .autoMode.allow) == []' "$profhome/.claude/settings.json" >/dev/null || fail "a profile list hid the repo's entries instead of joining them"
jq -e --arg addition "Read(/$extra/skills/**)" '.permissions.allow | index($addition) != null' "$profhome/.claude/settings.json" >/dev/null || fail "settings.json does not allow reading the addition's skills"
jq -e '.theme == "profile-theme" and (.permissions.allow | index("Read(//profile)") != null)' "$state_dir/settings-layer.json" >/dev/null || fail "the merged settings layer was not recorded"
[ "$(readlink "$profhome/.local/bin/profile-tool")" = "$prof/bin/profile-tool" ] || fail "the profile's bin was not linked"
[ "$(readlink "$profhome/.claude/skills/extra-skill")" = "$extra/skills/extra-skill" ] || fail "the addition's skill was not linked"
[ "$(readlink "$profhome/.claude/agents/extra-agent.md")" = "$extra/agents/extra-agent.md" ] || fail "the addition's agent was not linked"
grep -qxF "$extra" "$state_dir/additions.tsv" || fail "the addition was not recorded"
out=$(HOME=$profhome CLAUDE_CONFIG_DIR= "$root/install.sh")
echo "$out" | grep -q "^ok      $profhome/.claude/skills/extra-skill" || fail "a recorded addition was not installed again"
profsettings="$profhome/.claude/settings.json"
jq '.permissions.allow += ["Read(//saved-later)"] | .sandbox.excludedCommands += ["saved-later *"]' "$profsettings" >"$profsettings.tmp" && mv "$profsettings.tmp" "$profsettings"
echo '{"theme": "profile-theme", "permissions": {"allow": ["Read(//profile-moved)"]}, "sandbox": {"filesystem": {"allowWrite": ["~/profile-moved-cache"]}}}' >"$prof/settings.json"
HOME=$profhome CLAUDE_CONFIG_DIR= "$root/install.sh" >/dev/null
jq -e '(.permissions.allow | index("Read(//profile)") == null) and (.permissions.allow | index("Read(//profile-moved)") != null) and (.permissions.allow | index("Read(//saved-later)") != null) and (.permissions.allow | index("mcp__context7") != null) and .theme == "profile-theme"' "$profsettings" >/dev/null || fail "install.sh kept a rule the previous run merged and this one doesn't, or dropped one saved since"
jq -e '(.sandbox.filesystem.allowWrite | index("~/profile-cache") == null) and (.sandbox.filesystem.allowWrite | index("~/profile-moved-cache") != null) and (.sandbox.filesystem.allowWrite | index("~/.npm") != null) and (.sandbox.excludedCommands | index("saved-later *") != null) and (.sandbox.excludedCommands | index("gh *") != null) and (.autoMode.allow | index("profile rule") == null)' "$profsettings" >/dev/null || fail "install.sh kept a sandbox or auto-mode entry the previous run merged and this one doesn't, or dropped one saved since"
mkdir -p "$extra/skills/how-it-works"
printf -- '---\nname: how-it-works\n---\n' >"$extra/skills/how-it-works/SKILL.md"
printf 'how-it-works\t1.0.0\tclaude\n' >>"$extra/skills.tsv"
HOME=$profhome CLAUDE_CONFIG_DIR= "$root/install.sh" >/dev/null 2>&1 && fail "an addition's skill that clashes with this repo's was installed"

unhome=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$home" "$copyhome" "$fake" "$updhome" "$profhome" "$extra" "$unhome"' EXIT
mkdir -p "$unhome/.claude/skills" "$unhome/.codex"
echo 'my own instructions' >"$unhome/.claude/CLAUDE.md"
echo '{"theme": "light", "worktree": {"baseRef": "mine"}, "permissions": {"allow": ["Read(//mine)"]}, "hooks": {"Stop": []}}' >"$unhome/.claude/settings.json"
ln -s "$fake/elsewhere" "$unhome/.claude/skills/foreign-link"
HOME=$unhome CLAUDE_CONFIG_DIR= "$root/install.sh" >/dev/null
unsettings="$unhome/.claude/settings.json"
jq '.model = "added-later" | .permissions.defaultMode = "changed-later"' "$unsettings" >"$unsettings.tmp" && mv "$unsettings.tmp" "$unsettings"
HOME=$unhome CLAUDE_CONFIG_DIR= "$root/uninstall.sh" >/dev/null
[ ! -e "$unhome/.claude/skills/orchestrate" ] && [ ! -L "$unhome/.claude/skills/orchestrate" ] || fail "uninstall.sh left a skill link"
[ ! -L "$unhome/.claude/agents/builder.md" ] && [ ! -L "$unhome/.local/bin/statusline" ] || fail "uninstall.sh left an agent or bin link"
[ -L "$unhome/.claude/skills/foreign-link" ] || fail "uninstall.sh removed a link it did not make"
[ "$(cat "$unhome/.claude/CLAUDE.md")" = 'my own instructions' ] || fail "uninstall.sh did not put back the original CLAUDE.md"
[ ! -e "$unhome/.codex/AGENTS.md" ] || fail "uninstall.sh left a generated AGENTS.md"
jq -e '.theme == "light" and .worktree.baseRef == "mine" and .permissions.allow == ["Read(//mine)"] and .hooks.Stop == [] and .model == "added-later" and .permissions.defaultMode == "changed-later" and (has("sandbox") | not) and (.permissions | has("deny") | not)' "$unsettings" >/dev/null || fail "uninstall.sh did not remove exactly the merged settings"
ls "$unhome"/.config/countersign/skills/backups/*/claude-settings/settings.json >/dev/null 2>&1 || fail "uninstall.sh did not back up settings.json first"
copies_before=$(awk -F "$tab" '!seen[$1 FS $2]++' "$copyhome/.config/countersign/skills/manifest.tsv" | wc -l)
HOME=$copyhome CLAUDE_CONFIG_DIR= "$root/uninstall.sh" >/dev/null
[ "$copies_before" -gt 0 ] && [ ! -e "$copyhome/.claude/skills/context-transfer" ] && ls "$copyhome"/.config/countersign/skills/backups/*/claude/context-transfer/SKILL.md >/dev/null 2>&1 || fail "uninstall.sh did not move a copy to the backup folder"
[ ! -e "$copyhome/.config/countersign/skills/manifest.tsv" ] || fail "uninstall.sh left the copies' manifest"
[ ! -e "$copyhome/.claude/settings.json" ] || fail "uninstall.sh left an empty settings.json that the install had created"

land=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$home" "$copyhome" "$fake" "$updhome" "$profhome" "$extra" "$unhome" "$land"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
git init -q "$land/main"
printf 'one\n' >"$land/main/kept.txt"
printf 'two\n' >"$land/main/edited.txt"
printf 'three\n' >"$land/main/deleted.txt"
git -C "$land/main" add -A
git -C "$land/main" commit -q -m init
git -C "$land/main" worktree add -q --detach "$land/unit" HEAD
printf 'two, edited\n' >"$land/unit/edited.txt"
rm "$land/unit/deleted.txt"
mkdir "$land/unit/new"
printf 'four\n' >"$land/unit/new/added.txt"
(cd "$land/main" && "$root/skills/orchestrate/scripts/land-worktree" "$land/unit") >/dev/null || fail "land-worktree refused a clean worktree"
[ "$(cat "$land/main/edited.txt")" = "two, edited" ] && [ ! -e "$land/main/deleted.txt" ] && [ "$(cat "$land/main/new/added.txt")" = four ] || fail "land-worktree did not copy the worktree's changes"
[ "$(git -C "$land/main" diff --cached --name-only | tr '\n' ' ')" = "deleted.txt edited.txt new/added.txt " ] || fail "land-worktree did not stage exactly the worktree's changes"
git -C "$land/main" commit -q -m landed
git -C "$land/main" worktree add -q --detach "$land/stale" HEAD
printf 'one, from the unit\n' >"$land/stale/kept.txt"
printf 'one, on the branch\n' >"$land/main/kept.txt"
git -C "$land/main" commit -q -am moved
(cd "$land/main" && "$root/skills/orchestrate/scripts/land-worktree" "$land/stale") >/dev/null 2>&1 && fail "land-worktree copied over a file changed on the branch"
[ "$(cat "$land/main/kept.txt")" = "one, on the branch" ] || fail "land-worktree changed a file it refused to land"
git -C "$land/main" worktree add -q --detach "$land/committed" HEAD
printf 'five\n' >"$land/committed/other.txt"
git -C "$land/committed" add -A
git -C "$land/committed" commit -q -m unit
(cd "$land/main" && "$root/skills/orchestrate/scripts/land-worktree" "$land/committed") >/dev/null 2>&1 && fail "land-worktree landed a worktree that holds commits"
[ ! -e "$land/main/other.txt" ] || fail "land-worktree landed a worktree that holds commits"

slhome=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$home" "$copyhome" "$fake" "$updhome" "$profhome" "$extra" "$unhome" "$land" "$slhome"' EXIT
status_input='{"model": {"display_name": "Opus"}, "context_window": {"used_percentage": 12.7}, "rate_limits": {"five_hour": {"used_percentage": 41.6, "resets_at": 1791003600}, "seven_day": {"used_percentage": 72.5, "resets_at": 1791400000}}}'
out=$(echo "$status_input" | HOME=$slhome CLAUDE_CONFIG_DIR=/x/.claude-work "$root/bin/statusline")
[ "$out" = "$(printf 'Opus · ctx 12%% · 5h 58%% left · 7d \033[33m27%% left\033[0m')" ] || fail "statusline did not print the model, the context used and the limits left"
recorded="$slhome/.config/countersign/rate-limits/-x--claude-work.json"
jq -e '.schemaVersion == 1 and .configDir == "/x/.claude-work" and (.updatedAt | type) == "number" and .rateLimits.five_hour.used_percentage == 41.6 and .rateLimits.seven_day.resets_at == 1791400000' "$recorded" >/dev/null || fail "statusline did not record rate_limits for its config dir"
[ "$(ls -A "$slhome/.config/countersign/rate-limits")" = "-x--claude-work.json" ] || fail "statusline left a temp file next to the record"
out=$(echo '{"rate_limits": {"five_hour": {"used_percentage": 90}}}' | HOME=$slhome CLAUDE_CONFIG_DIR= "$root/bin/statusline")
[ "$out" = "$(printf '5h \033[31m10%% left\033[0m')" ] || fail "statusline did not show a nearly spent limit in red"
[ -f "$slhome/.config/countersign/rate-limits/$(printf '%s' "$slhome/.claude" | tr -c 'A-Za-z0-9' '-').json" ] || fail "statusline did not default the config dir to ~/.claude"
rm -rf "$slhome/.config"
out=$(echo '{"model": {"display_name": "Opus"}}' | HOME=$slhome CLAUDE_CONFIG_DIR= "$root/bin/statusline")
[ "$out" = Opus ] && [ ! -e "$slhome/.config" ] || fail "statusline wrote a record although the input had no rate_limits"
out=$(echo "$status_input" | HOME=$slhome CLAUDE_CONFIG_DIR=/x/.other "$root/bin/statusline" --wrap 'jq -r .model.display_name; echo wrapped')
[ "$out" = "$(printf 'Opus\nwrapped')" ] || fail "statusline --wrap did not print the wrapped command's output"
[ -f "$slhome/.config/countersign/rate-limits/-x--other.json" ] || fail "statusline --wrap did not record rate_limits"

badcat=$(mktemp -d "${TMPDIR:-/tmp}/countersign-skills.XXXXXX")
trap 'rm -rf "$home" "$copyhome" "$fake" "$updhome" "$profhome" "$extra" "$unhome" "$land" "$slhome" "$badcat"' EXIT
mkdir -p "$badcat/skills/bad"
printf 'bad\t1.0.0\tclaude\n' >"$badcat/skills.tsv"
printf -- '---\nname: bad\ndescription: >\n  folded\n---\n' >"$badcat/skills/bad/SKILL.md"
if badcat_err=$("$root/scripts/catalog.sh" "$badcat" 2>&1 >/dev/null); then
  fail "catalog.sh accepted a block scalar description"
fi
echo "$badcat_err" | grep -q 'skills/bad/SKILL.md:3' || fail "catalog.sh did not name the line of an unreadable value"

echo "test.sh: ok"
