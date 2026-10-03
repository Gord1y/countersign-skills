# Game

Played through the repo's editor MCP server, or run headless.

## Repo facts for this surface

| Fact | Example |
| --- | --- |
| The engine and where the project lives | Godot 4.7, project in `game/` |
| The editor MCP server and what it can do | `godot-ai` at `http://127.0.0.1:8001/mcp`: run a scene, send input, screenshot, read the scene tree and the output |
| The headless run and test commands | `godot --headless --path game -s res://tests/run.gd` |
| How to reach a given state quickly | a debug scene per feature, or a save file in `game/tests/saves/` |

## Tools

- **The editor MCP server**, when the editor is open: play a scene, send input events, take
  screenshots, read the scene tree and the output log.
- **The headless run** otherwise: the repo's tests, or a scratch script in `$SCRATCH`, run with
  `-s`, that prints the state you assert on. It exits on its own.
- Never open or close the editor yourself (it holds the MCP port), and never edit scenes or project
  settings to make a case pass.

## The loop for a game

Play the scene that holds the change, drive it with input events, poll the scene tree or the output
until the state appears, then assert on the state you read, not on a screenshot alone. Take the
screenshot once the assertion holds. Stop the play session before the next case unless that case
continues from it.

## Evidence

- `NN-<case>.png`, the screenshot from the MCP server.
- `NN-<case>-state.txt`, the scene-tree or variable read the case asserts on.
- `NN-<case>.txt`, a headless run's transcript with `exit=<code>` last.
- `NN-<case>.log`, the output's errors and warnings for a FAIL.

## Cases worth covering

- **Load:** the scene opens with no new errors or warnings in the output.
- **Each changed mechanic:** the input produces the state change, at its boundaries (minimum and
  maximum values, the edge of a collision area, a timer running out).
- **Persistence:** the change survives a scene reload and, if the game saves, a save and a load.
- **Frame time**, when the change could cost frames: before and after in the same scene.

## Teardown

Stop every play session you started, and leave the editor open.
