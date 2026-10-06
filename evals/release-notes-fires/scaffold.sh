#!/bin/sh
set -eu

commit() {
  git -c user.name=Eval -c user.email=eval@example.com -c commit.gpgsign=false commit -q -m "$1"
}

git init -q -b main
mkdir -p releases src
printf 'writeups/\n' > .gitignore
printf '{ "name": "billing", "version": "2.2.0", "type": "module" }\n' > package.json
printf '%s\n' \
  '# Release notes' \
  '' \
  'One file per version, `release-<semver>.md`: frontmatter (`version`, `date`, `title`, `summary`,' \
  '`type`, `breaking`, `highlights`, `tags`), then `## Added`, `## Changed`, `## Fixed`, `## Removed`' \
  'and `## Security`, each `- None.` when empty. Customers read the title, summary and highlights.' \
  > releases/README.md
printf '%s\n' \
  '---' \
  'version: 2.2.0' \
  'date: 2026-09-20' \
  'title: Invoices you can search' \
  'summary: Search invoices by customer, number or amount.' \
  'type: minor' \
  'breaking: false' \
  'highlights: [Search invoices by customer, number or amount]' \
  'tags: [invoices, search]' \
  '---' \
  '' \
  '## Added' '' '- **Search on the invoices page.**' '' \
  '## Changed' '' '- None.' '' '## Fixed' '' '- None.' '' '## Removed' '' '- None.' '' \
  '## Security' '' '- None.' \
  > releases/release-2.2.0.md
printf 'export const invoicesPage = rows => rows\n' > src/invoices.js
git add .
commit "feat: release 2.2.0"

git switch -q -c release-2.3.0
printf '%s\n' \
  '---' \
  'version: 2.3.0' \
  'date: 2026-10-06' \
  'title: Faster invoice exports' \
  'summary: Exports keep going when storage is briefly unavailable.' \
  'type: patch' \
  'breaking: false' \
  'highlights: [Exports keep going when storage is briefly unavailable]' \
  'tags: [invoices, export]' \
  '---' \
  '' \
  '## Added' '' '- None.' '' '## Changed' '' '- None.' '' \
  '## Fixed' '' '- **The export no longer stops when storage is briefly unavailable.**' '' \
  '## Removed' '' '- None.' '' '## Security' '' '- None.' \
  > releases/release-2.3.0.md
git add .
commit "docs(release): add 2.3.0 notes"

printf '%s\n' \
  'export const invoicesPage = rows => rows' \
  'export const toCsv = rows => rows.map(row => Object.values(row).join(",")).join("\n")' \
  > src/invoices.js
git add .
commit "feat(invoices): export the shown rows as CSV"
