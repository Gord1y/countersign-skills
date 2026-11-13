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
acme	acme-bot
```

The account must be signed in to `gh` (`gh auth login`). The token comes from
`gh auth token -u <account>`.

## Pass-through

`gh` runs unchanged, with the environment as it is, when any of these holds:

- `GH_TOKEN` is set and not empty.
- The first argument is `auth`, except `auth git-credential`, which gets the mapped token.
- The map file is missing and no app row applies.
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

## git push and fetch

`gh auth setup-git` makes `gh` git's credential helper for GitHub, under the real `gh`'s absolute
path, so git skips the wrapper and gets the active account's token. Point the helper at the
wrapper instead, keeping the empty line that comes before it:

```sh
for host in github.com gist.github.com; do
  git config --global --replace-all "credential.https://$host.helper" '!~/.local/bin/gh auth git-credential' '^!'
done
```

git runs the helper in the repo, so it gets the token of the account mapped to `origin`'s owner.
Running `gh auth setup-git` again puts the real `gh` back.

## Agent sessions and a GitHub App

In a Claude Code or Codex session (`CLAUDECODE` or `CODEX_THREAD_ID` set), an owner listed in the
profile's `agent-gh-apps.tsv` gets a 1h installation token of that GitHub App instead of the
account token. `bin/agent-gh-token` signs the app's JWT, asks GitHub for an installation token
scoped to origin's repo, and runs the real `gh` with it as `GH_TOKEN`. Git's credential helper is
this wrapper, so pushes use the app too.

Agents therefore push and open PRs as the app. The app has no administration permission and no
bypass, so GitHub refuses its pushes to protected branches. Your own terminal sets neither
variable and keeps your account.

`${XDG_CONFIG_HOME:-$HOME/.config}/countersign/profile/agent-gh-apps.tsv`, one line per owner,
`owner<TAB>app id<TAB>private key path`. A leading `~/` in the path is allowed.

```
acme	123	~/.config/agent-keys/acme.pem
```

- The key stays outside every git work tree. `agent-gh-token` refuses a key inside a repo.
- `agent-gh-token` needs `openssl`, `curl` and `jq`.
- Where the app is not installed on the repo, `gh` fails in agent sessions. Install the app on
  every repo agents work in.
- A preset `GH_TOKEN` and `gh auth` (except `auth git-credential`) stay untouched.
- If `agent-gh-token` is not on `PATH`, the wrapper exits 1 and tells you to run `install.sh`.

## Limits

- Inside a sandbox that blocks the keychain, `gh` has no token either way, and the wrapper prints
  the error above for a signed-in account. Run `gh` where it runs today.
- Only `origin` counts. `-R owner/repo`, `--repo` and GitHub Enterprise hosts are not read, and a
  `git clone` outside a repo gets the active account.

## Test

`scripts/test-gh.sh` runs the wrapper against a stub `gh` and a scratch home.
`scripts/test-agent-gh-token.sh` runs `bin/agent-gh-token` against a stub `curl`.
