import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

import { chromium } from './playwright.mjs'

const [pagePath, shotPath] = process.argv.slice(2)

if (!pagePath || !shotPath) {
  console.error('usage: node verify.mjs <page.html> <screenshot.png>')
  process.exit(1)
}

const file = pathToFileURL(resolve(pagePath)).href

const browser = await chromium.launch()

try {
  const page = await browser.newPage({ viewport: { width: 1000, height: 900 } })

  const errors = []
  page.on('pageerror', e => errors.push(String(e)))
  page.on('console', m => m.type() === 'error' && errors.push(m.text()))

  await page.goto(file, { waitUntil: 'networkidle' })

  const report = await page.evaluate(() => {
    const imgs = [...document.images]
    return {
      images: imgs.length,
      broken: imgs.filter(i => !i.complete || i.naturalWidth === 0).length,
      missingAlt: imgs.filter(i => !i.alt?.trim()).length,
      figures: document.querySelectorAll('figure').length,
      captions: document.querySelectorAll('figcaption').length,
      title: document.title,
      overflow: document.documentElement.scrollWidth > window.innerWidth
    }
  })

  await page.screenshot({ path: resolve(shotPath), fullPage: false })

  console.log(JSON.stringify({ ...report, errors }, null, 2))
  if (report.broken || report.missingAlt || report.overflow || errors.length)
    process.exitCode = 1
} finally {
  await browser.close()
}
