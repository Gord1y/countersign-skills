# Images

The README's icon (`docs/images/icon.png`, 256 px) and hero (`docs/images/hero.png`, 1792 by 1286),
and the 1280 by 640 social preview that GitHub takes in Settings, General, Social preview, are drawn
by `docs/images/render.swift`. The PNGs are committed as they are. The social preview is not: GitHub
keeps the uploaded copy.

## The look

They share Countersign's look, so the two repos read as one family:

- The icon is Countersign's: the same charcoal tile, the cream nib `#F4EFE8` and the amber signature
  `#E6B04A`, drawn with the geometry of Countersign's icon renderer (in the Countersign repo,
  `git show 22faef2^:scripts/icon/render-icon.swift`). Countersign's faint first signature is
  replaced by a fan of three skill cards, the pages the nib countersigns.
- The hero and the social preview use Countersign's plum-to-amber backdrop and its panel colors.

At 32 px and below the icon is close to Countersign's own, since the nib and the amber stroke carry
both. That was the choice: a family match over a mark that tells them apart at small sizes.

## The hero's output

The hero shows real `install.sh` output, from a scratch home where Codex and Antigravity are
installed, with the home folder written as `~`. The 41 links between the first four and the four
`wrote` lines are folded into one line. When a release changes that output, such as a new skill,
update `firstLinks`, `hiddenLinks` and `lastWrites` in `render.swift` and redraw.

## Redrawing

macOS only: the renderer uses CoreGraphics and the SF Mono files inside Terminal.app.

```sh
dir="$(mktemp -d "${TMPDIR:-/tmp}/render.XXXXXX")"
swiftc -O -o "$dir/render" docs/images/render.swift
"$dir/render" icon 256 docs/images/icon.png
"$dir/render" hero docs/images/hero.png
"$dir/render" social writeups/releases/<version>/social-preview.jpg
```

Then upload the social preview in the repo's Settings.
