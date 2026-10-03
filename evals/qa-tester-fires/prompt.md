---
description: A request to prove a change works in the running product should load the qa-tester skill.
tags: [qa-tester, fires]
max_turns: 10
timeout_seconds: 180
allowed_tools: [Read, Glob, Grep, Skill]
---
I just changed the signup form on our web app and added a new `POST /api/signup` endpoint. Before I open the PR, test the change in the running product on both the web page and the API, keep evidence for each case, and tell me what passes and what fails, with steps to reproduce any failure.
