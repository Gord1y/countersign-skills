---
description: A change that adds user-facing message keys should load the i18n-translate skill.
tags: [i18n-translate, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
I just added three new strings to `locales/en.json` for the checkout screen ("Pay now", "Your card was declined", "Order confirmed"). The repo also has `de.json`, `fr.json`, `es.json` and `uk.json`, and a `pnpm i18n:check` script that fails when a key is missing. Get the other locales up to date before I push.
