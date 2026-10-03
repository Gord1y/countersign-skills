# Customer walkthrough of a release

Read this before building a customer walkthrough (`SKILL.md` section 3).

## Repo facts for customer walkthroughs

| Fact | Example |
| --- | --- |
| The module a shot list re-exports its `setup`, `signIn`, `hideCss` and `locale` from | `scripts/walkthrough/setup.mjs`: the QA account's sign-in, the consent cookie, the devtools buttons to hide |

## Two outputs, never mixed

The page is for the customer; the chat message is for the user. The page holds product behaviour,
screenshots and workarounds for issues a customer will hit. The chat holds environment problems,
tooling failures, claims you could not establish, shots you could not get and defects found. A
sentence explaining why the page is imperfect belongs in chat, always.

## Pick what to show

Read `release-notes` output for the release first (`releases/release-<version>.md`), then the
release and feature PR bodies, and the diff only to settle a specific question. Keep only
reader-facing changes and cut the rest however large: CI, lint rules, tests, dependency bumps,
refactors, translation mechanics, observability. The notes are written by hand and can be wrong:
treat each item as a lead to verify, not a fact to repeat.

Group by where in the product the change lives. Weight by how much the reader has to learn, not by
how much code changed: a new capability gets a shot sequence, a changed screen gets one shot of the
after state, a fix gets a sentence. Fix the shot budget before capturing.

Check every "before" against the previous released version (the release branch's base, for example
`origin/main`). A feature new in this release has no "before"; describe what it does, never what it
no longer does wrong.

## Capture

Prove the running app is this release before capturing: check the ref, then probe something unique
to the release, such as a route that should now exist or a control that should be gone. Capture each
screenshot in the states the release notes name, the way `qa-tester`'s reference file for that
surface does: the Playwright MCP for web, the simulator for mobile, the snapshot command for a
native app.

- Screenshots are the deliverable here, so this inverts `qa-tester`'s preference for text reads. Its
  advice still holds between shots: poll the page text until the state has settled, then capture.
- One viewport for every shot (1440 by 900 reads well), one theme (light, unless the release is
  about dark mode) and one locale, unless the change is the translation itself.
- Dismiss consent banners, hide dev-only chrome, and do not shoot while a connection-error banner
  shows: it means a request failed.
- Screenshots of real people or client data never go in the page. Stage records with obviously
  fictional names and `.example` addresses first. Read the full text of any assistant reply in a
  shot before capturing it.
- If pixels already contain something private, order of preference: re-stage, crop, redact by
  destroying pixels (never a blur or an overlay), then drop the shot.
- Some changes are invisible in a picture (metadata, headers, sitemaps). Show the artefact itself,
  copied from a real request, in a monospace block.
- A shot from an earlier run is a claim about the past. Reuse one only after naming its screen and
  checking every later commit that touched it; if any did, retake it.
- Capture into `.playwright-mcp/` in the browser, never the repo root. Copy each shot the page
  uses into `releases/<version>/shots/`, and read every one back to confirm the change is visible
  in it.

## Evidence for every behavioural sentence

Nothing describing behaviour goes on the page until it has evidence: a flow you drove in the running
app (including the persisted state; a toast alone proves only that a request was accepted), a
request whose status, headers and body you read, or a condition in the code you can quote. Rewrite a
sentence down to what you established rather than dropping the change. Distrust "always", "never",
"only" and "every", capability denials, and any rule you saw work once. Keep the mapping from
sentence to evidence for the hand-off.

## The page

Self-contained, so it survives being emailed: images as base64 `data:` URIs or files next to the
page, no CDNs, no webfont links, system font stacks, light and dark both through CSS custom
properties redefined under `prefers-color-scheme`, and wide content in its own `overflow-x: auto`
container so the body never scrolls sideways. Copy the brand look from Repo facts.

Structure: a masthead naming the release and what changed in one sentence; one section per product
area; a `<figure>` per screenshot on a recessed mat with its `<figcaption>` below the image; known
issues a customer will hit as a callout, with the workaround; a short closing line.

- Prose sets up the change, the shot follows, the caption says what to notice in that frame in the
  product's own words. Never a caption that explains why a shot is imperfect. A shot you cannot
  caption is cut.
- Shots of one screen under different conditions go in one grid row of equal-width figures.
- A table row that did not change is cut; put the constant in a sentence.
- Plain customer language. Never mention branches, commits, servers, builds, caches, ports, repos,
  deploys or the framework, nor any word from the Repo facts banned list. Before writing the file,
  assert that none reached the page. `repo_banned` is the list from the "Words banned from
  customer-facing text" Repo fact:

```python
banned = ["dev server", "localhost", "branch", "commit", "staging", "deploy", "cache",
          "bundle", "component", "endpoint", "PR "] + repo_banned
hits = [w for w in banned if w.lower() in html.lower()]
assert not hits, f"internal language leaked into the page: {hits}"
```

## The scripts

This skill ships three scripts in `scripts/`, run from the top of the repo being walked through, so
they use that repo's `playwright` or `@playwright/test`. None starts a server. Chromium does not
start inside the Bash sandbox, so these run with it off. `<scratchpad>` is the session's scratchpad
folder, written out literally.

```bash
WRITEUPS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/writeups"
OUT="$WRITEUPS/releases/<version>"
SCRATCH="<scratchpad>"
node "${CLAUDE_SKILL_DIR}/scripts/capture.mjs" "$SCRATCH/shots.mjs" "$OUT/shots" <base-url>
node "${CLAUDE_SKILL_DIR}/scripts/inline.mjs" "$SCRATCH/page.src.html" "$OUT/shots" "$OUT/walkthrough.html"
node "${CLAUDE_SKILL_DIR}/scripts/verify.mjs" "$OUT/walkthrough.html" "$SCRATCH/verify.png"
```

- `capture.mjs` shoots each entry of a shot list written per release in the scratchpad, never in
  the repo. It default-exports `{ name: async (page, { visit, clipAround, BASE }) => ({ clip }) }`
  and may also export `setup(context, helpers)` (cookies such as a consent choice),
  `signIn(page, helpers)`, `hideCss` (development chrome to hide) and `locale`. The viewport is
  1440 by 900 at 2x, light theme. When the repo keeps those exports in a module, the shot list
  re-exports them from it.
- `inline.mjs` replaces each `{{SHOT:name|alt text}}` placeholder with that shot as a `data:` URI.
  It fails on alt text under 20 characters, a placeholder left over, or a leaked string
  (`localhost:` and `http://127.0.0.1` unless others are passed).
- `verify.mjs` opens the finished page and fails on a broken image, a missing alt, sideways
  scroll, a page error or a console error, then screenshots it.

## Check before handing over

Open the file on its own and confirm every image renders and has alt text, nothing scrolls
sideways, the browser console shows no error, and the banned-word guard passes: `verify.mjs`
checks all but the guard.

## Hand off

In chat, tell the user:

- Where the file is.
- How each behavioural claim was established, leading with the ones where checking changed what you
  were going to write, and anything cut because its "before" never shipped.
- Shots you could not get, and exactly what you need to get them.
- Anything redacted or dropped for privacy, and demo records left behind and how to find them.
- Defects and environment problems you hit: the material kept out of the page.
