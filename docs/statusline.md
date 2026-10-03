# statusline

`bin/statusline` is a Claude Code status line. It prints the model, how much of the context window
is used, and how much of the 5-hour and 7-day plan limits is left:

```
Opus · ctx 12% · 5h 58% left · 7d 27% left
```

Each part shows only when Claude Code sends its value. A limit with less than 30% left is amber,
and one with less than 20% left is red. Claude Code sends plan limits (`rate_limits` in the status
line input) only when you sign in with a claude.ai plan, so with an API key the line ends after the
context.

It needs `jq`, like `install.sh`.

## Turn it on

`install.sh` links it into `~/.local/bin`, but doesn't turn it on: setting `statusLine` would
replace a status line you already have. Add this to your profile's `settings.json` (or to
`~/.claude/settings.json`):

```json
{
  "statusLine": { "type": "command", "command": "~/.local/bin/statusline" }
}
```

To keep a status line you already have and still record the limits, wrap it:

```json
{
  "statusLine": { "type": "command", "command": "~/.local/bin/statusline --wrap '~/.claude/my-statusline.sh'" }
}
```

`--wrap <command>` records the limits, then runs `<command>` through `sh -c` with the same input
and prints what it prints. Its exit status is the wrapped command's.

## The record it writes

Every time Claude Code refreshes the status line and the input has `rate_limits`, `statusline`
writes them to one file per Claude Code config dir, so a tool such as Countersign's quota view can
show them without reading any credential:

```
${XDG_CONFIG_HOME:-~/.config}/countersign/rate-limits/<key>.json
```

`<key>` is the config dir (`$CLAUDE_CONFIG_DIR`, else `~/.claude`) with every character that is not
a letter or a digit replaced by `-`, the way Claude Code names its project folders:
`/Users/a/.claude` becomes `-Users-a--claude`.

```json
{
  "schemaVersion": 1,
  "configDir": "/Users/a/.claude",
  "updatedAt": 1791000000,
  "rateLimits": {
    "five_hour": { "used_percentage": 42, "resets_at": 1791003600 },
    "seven_day": { "used_percentage": 18, "resets_at": 1791400000 }
  }
}
```

- `rateLimits` is the input's `rate_limits` object, copied as Claude Code sent it. It can also hold
  `spend_limit` behind a gateway that sets one.
- `updatedAt` and every `resets_at` are Unix epoch seconds. A reader shows how old the figures
  are from `updatedAt`: the file only changes while a session is open.
- The file is replaced in one step (a temp file in the same folder, then `mv`), so a reader never
  sees half of it. An input without `rate_limits` leaves the file as it was.
- `schemaVersion` goes up only when a field changes meaning or goes away.
