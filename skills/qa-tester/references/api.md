# HTTP API

Requests against the local stack, saved as request and response pairs.

## Repo facts for this surface

| Fact | Example |
| --- | --- |
| The API base URL, its health check, and where its schema lives | `http://localhost:8000/api`, `GET /health`, OpenAPI at `/api/openapi.json` |
| How a client authenticates | `POST /auth/login` returns a bearer token; or a session cookie |
| Where the server's log can be read | `docker compose logs api` |

## Tools

`curl` and `jq` through Bash, or the HTTP client Repo facts name. Before the first case, check the
base answers (`curl -sS -o /dev/null -w '%{http_code}\n' <base><health>`) and which process serves
the port (`lsof -nP -iTCP:<port> -sTCP:LISTEN`).

## Sign in

Through the API, as a client does, with the local QA account. Keep the token in `$SCRATCH/token`,
or the cookie jar in `$SCRATCH/cookies` (`curl -c` and `-b`).

## The loop for a request

Send each case's request with `curl -sS -i`, so the status line and headers come back with the
body. Then read the state back: a `GET` after a write, or a read through the database MCP server.
Assert the status, the body's shape and values, and for a failure that the error body has the
documented shape with no stack trace, SQL or internal path in it.

## Evidence

One `NN-<case>.http` per case: the request as sent, a blank line, the response as received, and
any read-back after it.

```
POST /api/settings HTTP/1.1
Content-Type: application/json
Authorization: Bearer <redacted>

{"name": ""}

HTTP/1.1 422 Unprocessable Entity
Content-Type: application/json

{"errors": {"name": ["required"]}}
```

- Pretty-print JSON with `jq`. Cut a long body to what the case asserts and mark the cut, as
  `[... 48 more items]`.
- Replace every `Authorization`, `Cookie` and `Set-Cookie` value, and any token in a body, with
  `<redacted>`.
- A server-log excerpt that explains a FAIL goes in `NN-<case>.log`.

## Cases worth covering

- **Every changed endpoint and method:** the success status and body, and that the change
  persisted.
- **Validation:** a missing, wrong-typed or out-of-range field returns the documented 4xx with a
  field-level error, never a 500.
- **Auth:** no credentials gets 401; another user's resource gets the documented 403 or 404; a
  role below the required one is refused.
- **Edges:** not found, a duplicate create, a retried request, pagination and filters, where the
  endpoint has them.
- **Contract:** the response matches the schema the repo publishes, and no field clients rely on
  changed its name or type.

## Teardown

Nothing of its own: the token and the cookie jar go with `$SCRATCH`.
