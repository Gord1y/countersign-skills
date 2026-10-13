# gh

`bin/gh` wraps the real `gh`. It reads the owner of the repo's `origin` remote, looks the owner up
in a map, and runs `gh` with that account's token in `GH_TOKEN` for that one call. It never runs
`gh auth switch`, so parallel sessions on different accounts don't break each other.

`install.sh` links it into `~/.local/bin`. Put that folder before the real `gh` on `PATH`. The
wrapper finds the real `gh` by walking `PATH` and skipping itself.

## The map

`${XDG_CONFIG_HOME:-$HOME/.config}/countersign/profile/gh-accounts.tsv`, usually a file in your
profile repo. One line per owner, `owner<TAB>account`. Empty lines are skipped. The owner match
ignores case.

```
Gord1y	Gord1y
freedomseeker-ai	danylo-freedomseeker
```

The account must be signed in to `gh` (`gh auth login`). The token comes from
`gh auth token -u <account>`.

## Pass-through

`gh` runs unchanged, with the environment as it is, when any of these holds:

- `GH_TOKEN` is set and not empty.
- The first argument is `auth`.
- The map file is missing.
- The current directory is not in a git work tree.
- `git remote get-url origin` fails.
- The origin host is not `github.com`.
- The owner is not in the map.

`-h` and `--help` are `gh`'s own.

## When an account has no token

The wrapper never falls back to the active account. It prints this to stderr and exits 1:

```
gh: no token for account <account>, mapped from <owner> in <map path>; run gh where it can read its keyring, or sign the account in with: gh auth login
```

If no `gh` besides the wrapper is on `PATH`, it prints `gh: no gh found on PATH besides this wrapper`
and exits 127.

## Limits

- Inside a sandbox that blocks the keychain, `gh` has no token either way, and the wrapper prints
  the error above for a signed-in account. Run `gh` where it runs today.
- Only `origin` counts. `-R owner/repo`, `--repo` and GitHub Enterprise hosts are not read.

## Test

`scripts/test-gh.sh` runs the wrapper against a stub `gh` and a scratch home.
