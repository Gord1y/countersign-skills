# Web UI

Pages driven in a real browser through the Playwright MCP.

## Repo facts for this surface

| Fact | Example |
| --- | --- |
| How the Playwright MCP server is configured (headed or headless, which browser) | a `playwright` entry in `.mcp.json`, headless, installed Chrome |
| The locales, if the app has any | `en` by default, `de` and `fr` under `/de/` and `/fr/` |

## Tools

The browser tools: navigate, snapshot, click, type, file upload, screenshot, console messages,
network requests (`mcp__playwright__browser_*` under Claude Code; `browser_navigate`,
`browser_snapshot` and so on under Codex). When they are missing, the server is not configured or
has not loaded into this session: report it.

Headed versus headless is the server's configuration. Never edit it; if the user wants to watch,
the report says which setting to switch and that the session needs a restart.

## The loop in a browser

1. **Snapshot** with `browser_snapshot` (the accessibility tree). It is the source of truth for
   element refs; prefer it over screenshots for finding things to click or type into.
2. **Act** with `browser_click`, `browser_type`, `browser_select_option`, or `browser_file_upload`
   for a file input, using refs from the snapshot.
3. **Wait** with `browser_wait_for` on the expected text, or re-snapshot.
4. **Assert** the outcome is present: a toast, a row, an inline error, a URL change.
5. **Capture** with `browser_take_screenshot` at the decisive moment. For an error case also pull
   `browser_console_messages` and `browser_network_requests`, and note the failing request's
   status code and response body.

Rules:
- **Check console and network on every meaningful action.** A green UI with a 500 in the network
  log is a FAIL. A Content-Security-Policy violation in the console is a FAIL even if the page
  looks right.
- **Dismiss a cookie-consent banner first, if there is one.** On a fresh context it can gate the
  first interaction and change what loads afterwards. Note which state you tested in.
- **Sign in** the way Repo facts say, wait for a post-sign-in signal (a URL change or a landmark
  such as a sidebar), re-snapshot, and confirm the console is clean. A redirect loop back to
  sign-in means the session cookie is not being set: check the sign-in request in
  `browser_network_requests`.

## Layout and sizing changes

DOM-only test environments such as jsdom compute no layout, so a green unit suite is no evidence
that a positioning, sizing or breakpoint change works. Check it in the browser, at each breakpoint
it touches (`browser_resize`), and measure rather than eyeball, with `browser_evaluate`:
- **Page overflow:** `document.documentElement.scrollHeight - innerHeight`, and `scrollWidth -
  innerWidth` for horizontal scroll that shouldn't be there.
- **Containment:** the element's `getBoundingClientRect()` sits inside its intended container's.
- **Overlap:** `document.elementFromPoint()` at the element's centre returns the element or one of
  its descendants, not a fixed or sticky element on top of it.

Development overlays, such as a framework's devtools button or error overlay, sit on top of the
page: close them, or leave them out of hit tests. Sign in with a saved browser storage state when
the repo's e2e setup writes one. Throwaway measuring scripts go under `$SCRATCH`, never the repo
root, where linters pick them up.

## Loading and transitions

For a change that touches data loading, a skeleton, a route transition or an optimistic update:
- **Slow the network** for the case: Playwright `page.route` with a delay, or CDP
  `Network.emulateNetworkConditions`. Capture the loading state and the loaded state at the same
  viewport.
- **Skeleton matches layout:** compare the bounding boxes of the main regions in both states
  with a tolerance.
- **Layout shift:** the sum of `layout-shift` entries from a `PerformanceObserver` stays under 0.1.
- **No flash:** the empty state never shows between skeleton and data, and no second skeleton of a
  different size replaces the first.

```js
async (page) => {
  await page.addInitScript(() => {
    window.shift = 0;
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) if (!entry.hadRecentInput) window.shift += entry.value;
    }).observe({ type: 'layout-shift', buffered: true });
  });
  await page.route('**/api/**', async (route) => {
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await route.continue();
  });
  await page.goto('http://localhost:3000/<route>');
  const skeleton = await page.locator('<skeleton region>').boundingBox();
  await page.locator('<loaded region>').waitFor();
  const loaded = await page.locator('<loaded region>').boundingBox();
  return { skeleton, loaded, shift: await page.evaluate(() => window.shift) };
}
```

## Evidence

The Playwright MCP writes under `.playwright-mcp/` (gitignored). Always pass an explicit path,
`.playwright-mcp/qa-<run>/NN-<case>.png`; a bare filename resolves to the working directory and
pollutes the tree. Copy each screenshot a case cites into `$QA` under the same name, and read it
back to confirm it shows what the case claims. For a FAIL, save the console errors and the failing
request (method, URL, status, response snippet) as `NN-<case>.log`.

Shots a person reads are sharp and cropped to the point:

- **2x.** The MCP browser renders at device scale 1, which blurs on a retina screen. Before the
  first evidence shot, switch the page to 2x once; it holds until the browser closes:

```js
async (page) => {
  const cdp = await page.context().newCDPSession(page)
  await cdp.send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 2, mobile: false })
}
```

- **Crop.** When the "look for" is a small part of the screen (a menu, a tooltip, a badge, a
  field), shoot that region: `locator.screenshot()` on its container, or a `clip` with about 16 px
  of padding. Shoot the whole viewport only when the layout is the point.

## Cases worth covering

- **Smoke:** the Repo facts smoke pages. If the app has locales, spot-check one non-default locale:
  it confirms locale routing and that no raw message key (`Namespace.key`) leaks into the page, and
  catches almost every i18n regression a sweep would.
- **Load, render and happy path:** no console errors or failed requests, landmarks present, the
  main action completes and persists after a reload.
- **Forms:** required-field validation fires, a valid submit shows success and updates the page, an
  invalid submit shows field errors and does not submit.
- **Tables:** search, filter, sort and pagination change the rows, and row actions open the right
  detail.
- **File upload:** a valid file is accepted; a wrong type or oversized one is rejected readably.
- **Permissions, empty and error states:** where reachable and in scope.
- **Metadata:** when SEO was the point, check `<title>` and the canonical and social tags.

## Teardown

Close the browser context (`browser_close`) unless the caller asked to leave it open. Once its
files are in `$QA`, delete `.playwright-mcp/qa-<run>/`, everything else this run wrote under
`.playwright-mcp/`, and any stray screenshot in the working directory.
