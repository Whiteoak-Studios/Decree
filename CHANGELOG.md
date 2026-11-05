# Changelog

## 0.1.0 - 2026-11-05

Decree's first release, an admin command console for Roblox games whose networking runs through Volt 0.1.0. It installs from Wally as `fadeluc-123/decree`, a server package.

- The server decides everything. Each player's console holds only the commands the game's `canAccess` grants them, `refreshAccess` changes a player's list without a rejoin, every command that reaches the server passes the game's `beforeRun` hooks and the definition's guards, and the server parses and checks every line again.
- A command is a folder of plain modules, `{Name}`, `{Name}Server` and `{Name}Client`, which `registerCommandsIn` pairs. A device half is cloned only to the players who hold its command.
- Commands can carry subcommands, a `confirm` step timed by `confirmSeconds`, `autoExec` lines, and `system` and `tags` for a game's own help.
- Replies take a kind, Info, Ok, Refused or Error, and a server half may return a Promise, with a 9-second limit.
- The console takes a style table, keeps a configurable number of lines, wraps long ones, shows an optional context line above the prompt, and works with game-made toggle buttons through `addToggleButton`. It ships two commands of its own, `confirm` and `clear`.
- 51 built-in argument types and five guard factories, `hasCharacter`, `maxArrayLength`, `maxStringLength`, `nonEmptyString` and `notEquals`.
- Types for luau-lsp's new type checker, re-exported from the server entry.
