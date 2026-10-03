# catalog.json

`catalog.json` lists the skills, rules and agents in a folder laid out like this repo, so a loader
can show them without parsing Markdown. Countersign reads it from a pinned GitHub release of this
repo, and from additions (other folders with the same layout, such as a private profile repo).

The file is generated and committed. Do not edit it by hand.

## Schema

```json
{
  "schemaVersion": 1,
  "skills": [
    { "name": "orchestrate", "version": "2.3.1", "agents": ["claude"],
      "description": "...", "whenToUse": "...", "invocation": "model", "path": "skills/orchestrate" }
  ],
  "rules": [
    { "name": "responses", "title": "Responses", "agents": ["claude", "codex", "antigravity"],
      "path": "rules/responses.md" }
  ],
  "agents": [
    { "name": "builder", "description": "...", "model": "sonnet", "path": "agents/builder.md" }
  ]
}
```

| Field | Type | Source | Null when |
| --- | --- | --- | --- |
| `schemaVersion` | number | fixed, currently `1` | never |
| `skills[].name` | string | first column of `skills.tsv` | never |
| `skills[].version` | string | second column of `skills.tsv` | never |
| `skills[].agents` | string array | third column of `skills.tsv`, split at commas | never |
| `skills[].description` | string | `description` in the `SKILL.md` frontmatter | never, the generator stops without it |
| `skills[].whenToUse` | string or null | `when_to_use` in the frontmatter | the key is absent |
| `skills[].invocation` | `"model"` or `"manual"` | `"manual"` when the frontmatter sets `disable-model-invocation: true`, else `"model"` | never |
| `skills[].path` | string | `skills/<name>`, relative to the folder | never |
| `rules[].name` | string | first column of `rules.tsv` | never |
| `rules[].title` | string | the first `## ` heading of the rule file, without the `## ` | never, the generator stops without it |
| `rules[].agents` | string array | second column of `rules.tsv`, split at commas | never |
| `rules[].path` | string | `rules/<name>.md`, relative to the folder | never |
| `agents[].name` | string | the file name without `.md` | never |
| `agents[].description` | string | `description` in the agent's frontmatter | never, the generator stops without it |
| `agents[].model` | string or null | `model` in the frontmatter | the key is absent |
| `agents[].path` | string | `agents/<name>.md`, relative to the folder | never |

A missing `skills.tsv`, `rules.tsv` or `agents/` gives an empty list.

## Ordering

- `skills` follow the order of `skills.tsv`.
- `rules` follow the order of `rules.tsv`.
- `agents` are sorted by file name.
- Keys inside each object appear in the order of the schema above.
- The file is pretty-printed by `jq` with a two-space indent and ends with one newline.

## Frontmatter subset

The generator reads the lines between the first two `---` lines of a file. It supports only what
the files in this repo use:

- One `key: value` per line. A line is split at the first `: `, so values may contain `:`, `;`,
  `'` and ` - `.
- A plain value, or a value wrapped in one pair of double quotes. The pair is stripped and nothing
  else is unescaped.

It stops with exit code 1 and `catalog.sh: <file>:<line>: <what is wrong>` on a block scalar
(`>` or `|`), a single-quoted value, a missing `description`, or a skill folder that `skills.tsv`
lists without a `SKILL.md`. For a missing key the line is the closing `---`.

## Regenerating

```sh
scripts/catalog.sh
scripts/catalog.sh <folder>
```

The first form writes `catalog.json` at the root of this repo. The second does the same for an
addition. Each prints `wrote   <path>` or, when nothing changed, `ok      <path>`.

`scripts/catalog.sh --check [<folder>]` writes nothing. It exits 1 with
`catalog.sh: <path> is out of date; run scripts/catalog.sh <folder>` when the file is missing or
differs from what the generator would write.

`./test.sh` runs the check, so it fails while `catalog.json` is stale and CI enforces it. Run
`scripts/catalog.sh` and commit the result with any change to a skill, rule or agent listing.

## Releases

Each GitHub release attaches `catalog.json` next to `countersign-skills-<v>.tar.gz` and its
`.sha256`. A loader that pins a release reads the catalog of that exact tree.

## Versioning

`schemaVersion` goes up only when a field changes meaning or goes away. Adding a field does not
bump it, so a loader ignores keys it does not know.
