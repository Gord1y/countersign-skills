import { mkdir } from 'node:fs/promises'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

import { chromium } from './playwright.mjs'

const [shotsFile, outDir, base] = process.argv.slice(2)

if (!shotsFile || !outDir || !base) {
  console.error(
    'usage: node capture.mjs <shots-file.mjs> <out-dir> <base-url>\n' +
      '  the shots file default-exports { name: async (page, helpers) => ({ clip }) }\n' +
      '  and may export setup(context, helpers), signIn(page, helpers), hideCss and locale'
  )
  process.exit(1)
}

const VIEWPORT = { width: 1440, height: 900 }

const run = async () => {
  const shotList = await import(pathToFileURL(resolve(shotsFile)).href)
  const hideCss = shotList.hideCss ?? ''
  await mkdir(outDir, { recursive: true })

  const browser = await chromium.launch()
  const context = await browser.newContext({
    viewport: VIEWPORT,
    deviceScaleFactor: 2,
    colorScheme: 'light',
    locale: shotList.locale ?? 'en-US'
  })

  if (hideCss) {
    await context.addInitScript(css => {
      const apply = () => {
        const style = document.createElement('style')
        style.textContent = css
        document.head?.appendChild(style)
      }
      if (document.head) apply()
      else document.addEventListener('DOMContentLoaded', apply)
    }, hideCss)
  }

  const page = await context.newPage()

  const helpers = {
    BASE: base,
    visit: async path => {
      await page.goto(`${base}${path}`, { waitUntil: 'networkidle' })
      await page.waitForTimeout(500)
    },
    clipAround: async (locator, pad = 24) => {
      await locator.scrollIntoViewIfNeeded()
      await page.waitForTimeout(600)
      const box = await locator.boundingBox()
      if (!box) return undefined
      const y = Math.max(0, box.y - pad)
      const x = Math.max(0, box.x - pad)
      return {
        x,
        y,
        width: Math.min(VIEWPORT.width - x, box.width + pad * 2),
        height: Math.min(VIEWPORT.height - y, box.height + pad * 2)
      }
    }
  }

  if (shotList.setup) await shotList.setup(context, helpers)
  if (shotList.signIn) {
    await shotList.signIn(page, helpers)
    console.log(`SIGNED IN  on ${base}`)
  }

  let failed = 0

  for (const [name, prepare] of Object.entries(shotList.default)) {
    try {
      const { clip } = (await prepare(page, helpers)) ?? {}
      if (hideCss) await page.addStyleTag({ content: hideCss }).catch(() => {})
      await page.waitForTimeout(250)
      await page.screenshot({ path: `${outDir}/${name}.png`, clip })
      console.log(`SHOT  ${name} ${clip ? JSON.stringify(clip) : 'viewport'}`)
    } catch (error) {
      failed += 1
      console.error(`FAIL  ${name}: ${error.message}`)
    }
  }

  await browser.close()
  if (failed) process.exit(1)
}

run().catch(error => {
  console.error(error)
  process.exit(1)
})
