# Trigger evals

The suite in `evals/` checks that Claude picks a skill on natural phrasing, and only then. It runs
with `claude plugin eval`, which treats this repo as a plugin (`.claude-plugin/plugin.json`).

## What it checks

Each of the 14 model-invocable skills has two cases:

- `evals/<skill>-fires`: a request a user would type that the skill is for. The grader passes when
  the model calls the `Skill` tool for that skill.
- `evals/<skill>-quiet`: a nearby request that shares words with the skill's domain but is not its
  job. The grader passes when the model never calls the `Skill` tool for that skill.

The two skills with `disable-model-invocation: true` get no cases, because the model never picks
them.

The suite checks triggers only. Whether a skill then does its job well is a different question,
and an `llm` grader for it would be slower, costlier and noisier. A description that never fires,
or fires on everything, is the failure this suite exists to catch.

Each run is an isolated `claude -p` child with a temporary home and an empty working directory. No
user skills, settings, `CLAUDE.md` or memory load, only the plugin under test. So every prompt
stands alone and carries inline whatever it needs.

A case that needs files or git history seeds its workspace with a `scaffold.sh` in its folder,
named in its `case.yaml` as `context.scaffold_script`. `walkthrough-fires` builds a repo whose last
commit is a finished change, with QA evidence in a gitignored `writeups/`: in an empty folder the
skill had nothing to walk through and fired in only one or two runs of three. `release-notes-fires`
builds a repo on `release-2.3.0` with the open note its request names: in an empty folder the model
spent its turns looking for that note and fired in two runs of three. The scripts run as
you, outside the sandbox, so `claude plugin eval` runs them only with `--scaffold`, which the
script passes because every case here is this repo's own. `scripts/lint.sh` checks them.

`./test.sh` checks the layout without any model call: both case directories exist for every
model-invocable skill, the graders match the skill name, the quiet grader caps the calls at zero,
and no case directory belongs to a skill that does not exist.

## Running it

```sh
scripts/evals.sh
scripts/evals.sh --case 'orchestrate-*'
scripts/evals.sh --runs 3
scripts/evals.sh --case 'how-*' --runs 3
```

The script runs
`claude plugin eval . --ablation none --runs 1 --no-publish --max-cost-usd 6 --scaffold` from the
repo root. Options you pass come last and override those defaults. `--case` takes one glob: a
second `--case` replaces the first, so run two skills as two commands. It exits 2 when `claude` is
not on PATH. `claude plugin eval` exits 0 when every case passes, 1 when a case is below the
threshold or errors, and 2 when the cost ceiling is hit.

The first run on a machine must be yours, in a terminal: `claude plugin eval` asks once to trust
this folder, since the cases' scaffold scripts run as you. Until then a run with no terminal, an
agent's included, exits 1 with "not a trusted plugin directory". The script never passes
`--trust-plugin`, so trusting the folder stays a person's call.

Results land in `evals/results/<timestamp>/`, which is gitignored.

`claude plugin validate .` checks the manifest and the `SKILL.md` frontmatter without a model call.

## Cost

One pass is 28 short runs, 14 skills times two cases. Each is a model call billed to your plan or
API account. Measured on 2026-10-03 with Claude Code 2.1.278 and the session's default model, 23
runs cost 4.33 USD, about 0.19 USD each, so a full pass is about 5.3 USD. `--max-cost-usd 6` leaves
room for that and stops a pass that costs more than expected. The ceiling is checked before each
run starts, so with `-j <n>` the runs already in flight can take a pass past it. `--runs 3`
triples the cost and smooths the variance of a single sample; `--case` keeps a check to the skill
you changed.

## Why `--ablation none`

The default `with-without` ablation runs every case twice, with and without the plugin, and does not
score `tool_used: Skill` graders. It reports them only. `--ablation none` runs one arm with the
plugin and scores the graders, which is the whole point here, and halves the cost.

## Why it is not in CI

Every run is a paid model call, and CI would need an API-key secret in a public repo. The suite is
a local check run by whoever changes a description.

## When to run it

- Before changing a skill's `description` or `when_to_use`, to get a baseline, and again after.
- Before a release.

## When a case fails

Rephrase the skill's `description` or `when_to_use`, then run the case again with `--runs 3`.
Never edit the case to make it pass: the case is the user's phrasing, and the description is what
has to meet it. Change a case only when it no longer describes a real request, and say why in the
commit.
