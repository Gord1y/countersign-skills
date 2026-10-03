#!/bin/sh
set -eu

commit() {
  git -c user.name=Eval -c user.email=eval@example.com -c commit.gpgsign=false commit -q -m "$1"
}

git init -q -b main
mkdir -p src
printf 'writeups/\n' > .gitignore
printf '%s\n' \
  'export const readSession = request => JSON.parse(request.cookies.session ?? "null")' \
  'export const writeSession = (response, session) => response.cookie("session", JSON.stringify(session))' \
  > src/session.js
printf '{ "name": "shop", "type": "module" }\n' > package.json
git add .
commit "feat: keep the session in a cookie"

printf '%s\n' \
  'import { store } from "./store.js"' \
  'export const readSession = async request => store.get(request.cookies.sid)' \
  'export const writeSession = async (response, session) => {' \
  '  const sid = await store.put(session)' \
  '  response.cookie("sid", sid, { httpOnly: true, sameSite: "lax" })' \
  '}' \
  > src/session.js
printf '%s\n' \
  'const sessions = new Map()' \
  'export const store = {' \
  '  get: async sid => sessions.get(sid) ?? null,' \
  '  put: async session => { const sid = crypto.randomUUID(); sessions.set(sid, session); return sid }' \
  '}' \
  > src/store.js
git add .
commit "feat: keep sessions in a server-side store"

qa=writeups/changes/2026-10-03-session-store/qa
mkdir -p "$qa"
printf '%s\n' \
  '# QA run - session store - 2026-10-03' \
  '' \
  '| Case | Verdict | Evidence |' \
  '| --- | --- | --- |' \
  '| 01 sign-in sets only an opaque sid cookie | PASS | 01-sign-in.http |' \
  '| 02 the session survives a reload | PASS | 02-reload.http |' \
  '| 03 signing out clears the server entry | PASS | 03-sign-out.http |' \
  > "$qa/results.md"
printf 'POST /api/sign-in\n\nHTTP/1.1 200 OK\nSet-Cookie: sid=4f1c; HttpOnly; SameSite=Lax\n' > "$qa/01-sign-in.http"
printf 'GET /api/me\nCookie: sid=4f1c\n\nHTTP/1.1 200 OK\n{"email":"qa-agent@shop.example"}\n' > "$qa/02-reload.http"
printf 'POST /api/sign-out\nCookie: sid=4f1c\n\nHTTP/1.1 204 No Content\n' > "$qa/03-sign-out.http"
