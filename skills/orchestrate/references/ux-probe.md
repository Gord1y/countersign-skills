# UX probe in a release

The UX probe is a separate T3 Code thread in its own T3 project, working in a folder outside every
repo that `probe-init` set up. It sees the product only through a browser on the local stack. It is
blind on purpose: it judges what a user meets, and knowledge of the code would bias it. The
codebase session never sends it a path, a code or component name, a diff, a commit or a click
path. It talks to the probe only through `brief.md` and `verdicts.md`, and it writes both with the
Write tool.

## Launch

1. Find the probe's T3 project with `t3_project_list`: the one whose folder is the Repo fact. None:
   `skip: no probe project`, and tell the user to create it (`docs/ux-probe.md`, Setup).
2. `t3_thread_launch` with that `projectId` and the prompt
   `Run the UX probe on brief.md. End with the PROBE line.`
3. `t3_thread_wait` on the returned thread until it ends, then read its last message with
   `t3_thread_read`.
4. Never start, stop or restart the stack for the probe.
5. `PROBE BLOCKED: <reason>`: record it, skip triage, and give the user the reason as an action.
   The release goes on without the probe's verdicts.

## Triage

Read only the newest `## Run` section of `candidates.md`. Give each candidate one verdict:

- `confirmed`: the code shows the behaviour is unintended, or `qa-tester` reproduces it on the
  local stack.
- `by design`: the code, a decision record or the release note shows it is intended.
- `duplicate`: an earlier candidate or a known issue covers it. Name the earlier id.
- `not reproducible`: neither the code nor a reproduction shows it.

Judge against the code and the repo's docs. Reproduce with `qa-tester` only when the code does not
settle it.

## Confirmed candidates become slices

Each confirmed candidate becomes one `bug-fix` slice, appended to the run's plan. New slices need
the user's approval (`references/planning.md`): ask for all of them in one question, and recommend
building a `blocker` candidate's slice before the release PR. Then build them on the normal path.

## Verdicts go back in user terms

Append to `verdicts.md` in the probe folder one block per candidate: `## <id>: <verdict>`, then one
sentence a user would understand ("Intended: only owners can archive members."). A duplicate names
the earlier id. Never a path, a code or component name, a commit, a selector or a click path.

Check the new blocks with `brief-lint` before writing them: put them in a scratch file and run
`${CLAUDE_SKILL_DIR}/../release-brief/scripts/brief-lint <file> --base-url <base URL>` plus one
`--allow <word>` per word in release-brief's Repo facts. Rewrite until it exits 0, then append.

**Under Codex** the lint is `~/.agents/skills/release-brief/scripts/brief-lint`, with the same
arguments.

When a confirmed candidate's fix lands, append `## <id>: fixed` and one sentence on what a user
should now see.

## Close the probe run

Write the full SHA of `HEAD` to `last-ref` in the probe folder, so the next brief starts from here.
The closing summary lists each candidate id with its verdict.
