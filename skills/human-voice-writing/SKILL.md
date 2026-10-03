---
name: "human-voice-writing"
description: "Draft or revise longer text the user sends or publishes as their own, so it reads human, not AI-generated."
when_to_use: "Use for messages, emails, posts and articles the user will send or publish under their name."
---

# Human-voice writing

Goal: text that sounds like a specific person wrote it for a specific reader, not like a model filling a template.

Based on the StoryScope study (Russell et al., COLM 2026, 61k stories, human vs. Claude/GPT/Gemini/DeepSeek/Kimi). Its key lesson: AI text is recognizable less by word choice than by the **choices underneath** — what it explains, how it orders things, how tidy it is, how vague it stays. Polishing words alone does not fix it (edited AI stories were still detected at ~94%). So work on structure first, wording second.

The study measured fiction. Rules marked (F) come straight from its findings; the rest are adaptations of the same patterns to non-fiction writing.

## Workflow

1. **Pin down the situation before writing.** Who is the reader, what do they already know, what should they do or feel after, how would the user say this out loud? If the user has shared writing samples or a style profile, match that voice above everything in this skill.
2. **Pick a shape on purpose** (see "Structure"). Don't default to intro → three points → summary.
3. **Draft.**
4. **Revise with the checklist** at the bottom. Fix structure issues before wording issues.
5. **Don't overcorrect.** These are tendencies, not laws. Humans also sometimes write linear, tidy text. Aim for variety and fit, not for inverting every rule.

## 1. Stop over-explaining (F)

AI states the meaning 77% of the time; humans 52%. AI ends arcs with the lesson spelled out.

- Say the main point once, clearly. Don't restate it in the last paragraph.
- Cut "lesson" endings: "Ultimately, this reminds us that…", "In the end, what matters is…", "This highlights the importance of…".
- Let a concrete example carry the point instead of explaining the example afterwards.
- In messages: end when the content ends. No moral, no summary of what you just said.
- Philosophy only where it serves the purpose. AI drifts into abstract reflection (59% vs 34% in dialogue).

## 2. Be specific and real (F)

Humans name real works, authors, places, brands ~2× more often; AI prefers vague allusions.

- Prefer the named thing: the actual book, tool, city, number, date, person, past event.
- Use the user's own experience, context and details whenever available — ask for them if a text would be generic without them.
- **Never invent** facts, quotes, sources, statistics or anecdotes to seem specific. If a detail is unknown, leave it out or ask.

## 3. Allow messiness and mixed views (F)

AI plots are tidy: one causal chain, no side threads, protagonist fixes everything, ending = acceptance. Humans leave loose ends, morally mixed characters (59% vs 38%), unresolved endings.

Non-fiction equivalents:
- Include a real tension, trade-off or counterpoint and don't fully dissolve it.
- It's fine to say "I'm not sure", "I changed my mind on this", "this part I still don't like".
- A short aside or side-note that relates to the theme from a different angle is human; a perfectly sealed argument is not.
- Don't end every text on a reconciled, upbeat note.

## 4. Vary order and structure (F)

Humans use time jumps, flashbacks, and delay reveals; AI goes first clue → grand reveal.

- Open with the most interesting thing: the result, the question, a moment, a blunt statement — not background.
- Consider a shape where a later point changes how the reader sees an earlier one.
- Don't reuse the same skeleton for every text. Paragraph lengths should vary; a one-line paragraph is fine.
- Emails/messages: often the ask or news goes first, context after.

## 5. Emotions and atmosphere (F)

AI shows emotion through the body 81% of the time (tight chest, breath caught) vs 38% human; humans simply name the feeling 29% vs 8%. AI over-uses sensory detail (especially smell) and settings that mirror moods.

- Name feelings plainly sometimes: "I was annoyed", "honestly this scared me".
- Cut decorative sensory filler and weather-matches-mood description unless it does real work.
- Don't describe a person by their appearance first; introduce them through what they do or say.

## 6. Talk to the reader (F)

Humans address the reader directly and break the fourth wall far more (28% vs 7%). AI "writes as though no one is watching."

- Use "you", ask the reader a real question, acknowledge what they might be thinking — where the genre allows it.

## 7. Let the energy move

Claude in particular keeps a flat, calm, uniform voice with little escalation. Let the tone rise where the content matters: a strong opinion, a short punchy sentence, some humor, an admitted frustration. Uniform politeness reads as machine.

## 8. Surface tells (fix after structure)

Easy to spot and easy to remove:
- Words: delve, tapestry, testament, realm, navigate (figuratively), foster, leverage, robust, seamless, pivotal, intricate, multifaceted, landscape, journey, embark, elevate, crucial, vibrant, underscore, resonate.
- Em-dashes used as the default punctuation; replace most with commas, periods, parentheses.
- Triplets everywhere ("clear, concise, and compelling").
- "It's not X, it's Y" / "not just X but Y" constructions.
- Openers: "Great question", "In today's fast-paced world", "Let's dive in", "I hope this email finds you well" (unless the user actually writes that way).
- Closers: "In conclusion", "Overall", "I hope this helps", "Feel free to reach out".
- Every sentence the same length and rhythm. Mix short and long.
- Headers, bold and bullet lists in text that a person would write as plain paragraphs (messages, personal essays, posts).
- Hedging stacks: "may potentially help to somewhat…".

## By text type

- **Messages / chats:** short, point first, contractions, no sign-off summary, no formatting. One idea per message is fine.
- **Emails:** ask or news in the first two lines; specific details (dates, names, numbers); end with the concrete next step, not a pleasantry block.
- **Essays / articles:** a real claim with a named example early; at least one honest counterpoint left partly open; no restating conclusion; vary paragraph shape.
- **Social posts:** open with the specific moment or opinion; one idea; a personal detail; no hashtag/emoji padding unless the user uses them.
- **Fiction:** apply sections 1–6 fully: implied themes, subplots that echo the main theme, morally mixed protagonist, non-linear order with a reveal that recontextualizes, plainly named emotions, more dialogue, several locations, endings that aren't neatly resolved. Avoid default AI plot moves: gossip/rumor as the engine, the look-back-from-decades-later frame, epilogues that tie everything off, the protagonist's single choice fixing everything.

## Revision checklist

Structure
- [ ] Is the main point stated only once? Any moral/lesson ending to cut?
- [ ] Does it open with something interesting rather than background?
- [ ] Is there at least one specific real detail (name, number, place, experience) — and none invented?
- [ ] Is there some tension, trade-off or open question left honestly open?
- [ ] Does the shape differ from a generic intro-points-summary template?
- [ ] Does the tone move anywhere, or is it uniformly calm?

Wording
- [ ] Words from the tell list removed?
- [ ] Em-dashes, triplets, "not X but Y" mostly gone?
- [ ] Sentence and paragraph length varied?
- [ ] Formatting appropriate for how a person writes this type of text?
- [ ] Read it aloud as the user: would they actually say this?

If the user asks why a change was made, point to the specific pattern above.

If `local.md` exists next to this file, read it; where it disagrees with this file, it wins.
