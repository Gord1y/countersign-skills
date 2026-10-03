import { createRequire } from 'node:module'
import { join } from 'node:path'

const requireFromRepo = createRequire(join(process.cwd(), 'package.json'))

const loadChromium = () => {
  for (const name of ['playwright', '@playwright/test']) {
    try {
      return requireFromRepo(name).chromium
    } catch (error) {
      if (error.code !== 'MODULE_NOT_FOUND') throw error
    }
  }
  console.error(
    `Playwright is not installed under ${process.cwd()}: run this from a repo that depends on playwright or @playwright/test`
  )
  process.exit(1)
}

export const chromium = loadChromium()
