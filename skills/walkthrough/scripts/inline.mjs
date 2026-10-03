import { readFile, writeFile } from 'node:fs/promises'

const [src, shotsDir, out, ...rest] = process.argv.slice(2)

if (!src || !shotsDir || !out) {
  console.error(
    'usage: node inline.mjs <page.src.html> <shots-dir> <out.html> [forbidden-string ...]\n' +
      '  placeholders look like {{SHOT:name|alt text describing the image}}'
  )
  process.exit(1)
}

const FORBIDDEN = rest.length ? rest : ['localhost:', 'http://127.0.0.1']

const PLACEHOLDER = /\{\{SHOT:([a-z0-9-]+)\|([^}]+)\}\}/g

const escapeAttribute = value =>
  value.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')

let html = await readFile(src, 'utf8')

const matches = [...html.matchAll(PLACEHOLDER)]

if (matches.length === 0) {
  console.error('no {{SHOT:name|alt}} placeholders found — nothing to inline')
  process.exit(1)
}

for (const [token, name, alt] of matches) {
  if (alt.trim().length < 20) {
    throw new Error(
      `alt text for ${name} is too short to describe the image: "${alt}"`
    )
  }

  const bytes = await readFile(`${shotsDir}/${name}.png`)
  const tag = `<img alt="${escapeAttribute(alt.trim())}" src="data:image/png;base64,${bytes.toString('base64')}">`

  html = html.replaceAll(token, tag)
  console.log(`inlined ${name} (${Math.round(bytes.length / 1024)} KiB)`)
}

const leftover = html.match(/\{\{SHOT:[^}]*\}\}/g)
if (leftover) throw new Error(`unreplaced placeholders: ${leftover.join(', ')}`)

for (const forbidden of FORBIDDEN) {
  if (html.includes(forbidden)) throw new Error(`leaked string: ${forbidden}`)
}

await writeFile(out, html)
console.log(`\nwrote ${out} (${Math.round(html.length / 1024)} KiB)`)
