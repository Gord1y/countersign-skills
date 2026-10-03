# Rules for each translator

Read this first. It applies to every locale file you write.

## Translation rules

- Preserve every `{placeholder}` verbatim. Renaming one breaks the page at render.
- Honour the glossary's never-translate list and its per-language rules (declension of names,
  brand and partner names, standards, plan names). The skill lists no terms; the glossary is the
  only source.
- Translate descriptive labels even when they are capitalised like a product name. The test is
  narrow: is this a name someone owns, or a description of what the thing does? A feature label
  such as "Billing Contacts" describes what the thing does and gets translated; only the owned
  name stays. Build the phrase from the locale's own row in the glossary.
- Option labels and enum names shown to users are translated; keys and values sent to the API are
  not. Translating a label cannot break validation, because the schema enforces the real value. Keep
  a label consistent with the same concept elsewhere in the app: a status shown as `In progress` in
  the picker must read the same in a table filter. When a validation message spells options out in
  prose, use the same wording as that field's dropdown labels, so the message names the options
  the user just saw. Product names inside an option still stay.
- Reuse the terminology and register already present in the target file and the glossary's
  per-locale terms table. Do not coin a synonym for an established term.
- A message keeps the source's sentence shape and placeholders. Success and error toasts follow a
  fixed English shape: `X created successfully` and `Failed to create X` keep one consistent shape
  per locale across all of them, rather than each message being translated independently.
- Follow the locale's row in the glossary's typography and register table: apostrophes, quote
  marks, diacritics, formal or informal address. Filling a locale in from its neighbour (the wrong
  letters for a Nordic language, a cedilla where Romanian uses a comma-below) is the usual tell,
  and nothing in CI detects it.
- Follow the glossary's dash rule and the punctuation check: no em dash `—` or horizontal bar `―`,
  and no en dash `–` as prose punctuation, unless the glossary names a locale exception. Rewrite the
  clause with a colon, comma or full stop instead of swapping the glyph, and do not fall back to a
  plain hyphen `-`. An en dash is correct only between digits, as a range (`2024–2025`).
- ICU plural categories are per-language, and only the argument name is fixed. Polish and
  Ukrainian need `few`/`many`; **Romanian has three forms** (`one`, `few`, `other`) and must use
  all three.
- Never write the literal word `TODO`, and never leave English text in a non-English locale; both
  fail the checks.
- Never use the English value as a placeholder. An untranslated value byte-identical to English is
  exactly what the identical-value check fails on.

## JSON formatting

2-space indent, no trailing commas, double-quoted keys and values, one trailing newline, and key
order identical to the English file.
