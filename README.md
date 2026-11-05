# Decree

Decree is an admin command console for Roblox games, rewritten from Cmdr 1.13.1 onto Volt, Whiteoak's networking library. The server decides everything. Each player's console holds only the commands the game grants that player, every command that reaches the server passes the game's `beforeRun` hook first, and the server parses and checks every line again, whatever the client checked.

Decree is published on Wally as `fadeluc-123/decree`. This README covers version 0.1.0.

## Install

### wally.toml

Decree's generated network modules require the game's own Volt and Promise at `ReplicatedStorage.Packages.Volt` and `ReplicatedStorage.Packages.Promise`, so the game installs both itself. Add these sections beside the game's own `[package]` section:

```toml
[place]
shared-packages = "game.ReplicatedStorage.Packages"

[dependencies]
Promise = "evaera/promise@4.0.0"
Volt = "fadeluc-123/volt@0.1.0"

[server-dependencies]
Decree = "fadeluc-123/decree@0.1.0"
```

- The aliases must be exactly `Volt` and `Promise`. Wally names each installed module after its alias, and instance names are case sensitive.
- Decree's manifest sets `realm = "server"`, so it goes under `[server-dependencies]`, installs into `ServerPackages/`, and its server code never replicates.
- Decree depends on Promise, and the game lists Promise too, so Wally installs Promise once in `Packages/` and links Decree to it through `shared-packages`. Without the `[place]` block, `wally install` stops with "A server or dev dependency is depending on a shared dependency" and leaves a half-written tree.
- Decree 0.1.0 was compiled by Volt 0.1.0, and the game's Volt must be on the same 0.1 line. Wally can't check that pairing, since Volt is only a dev dependency of Decree, and it would install a second Volt line beside the first instead of refusing it. Under Wally's rules `0.1.0` means `>=0.1.0, <0.2.0`. A Volt runtime on another line errors at the first require, for example `Volt: Decree's schema was compiled by Volt 0.1.0 and the runtime is 0.2.0`.

### Rojo

Map `Packages` to `ReplicatedStorage.Packages` and `ServerPackages` to a server container:

```json
{
	"name": "Game",
	"tree": {
		"$className": "DataModel",
		"ReplicatedStorage": {
			"Packages": { "$path": "Packages" }
		},
		"ServerScriptService": {
			"ServerPackages": { "$path": "ServerPackages" }
		}
	}
}
```

The server requires Decree as `ServerScriptService.ServerPackages.Decree`. That require sets Decree up: it binds Decree to Volt and moves the client half to `ReplicatedStorage.DecreeClient`, where the client requires it.

### Typed install

Wally replaces each package with a one-line link module that loses the package's exported types. After every `wally install`, run these four commands in this order, with the project file your game builds with:

```sh
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
wally-package-types --sourcemap sourcemap.json ServerPackages/
```

`wally-package-types` 1.6.2 exits 1 on a second pass over links it has already typed (`'REQUIRED_MODULE' is not a function call`) and on a link the sourcemap doesn't hold, so it always runs on a fresh install with a fresh sourcemap.

Decree is written for luau-lsp's new type checker. Analyze with `--flag:LuauSolverV2=true`, since without it the command line runs the old checker:

```sh
luau-lsp analyze --platform=roblox --flag:LuauSolverV2=true --sourcemap=sourcemap.json --definitions=globalTypes.d.luau src
```

In VS Code, turn the same checker on with `"luau-lsp.fflags.enableNewSolver": true` in the workspace settings. This release was built and checked with Rojo 7.7.0, Wally 0.3.2, wally-package-types 1.6.2 and luau-lsp 1.70.0.

## Quick start

These four files give every player an `echo` command. The server script is `ServerScriptService/Admin.server.luau`:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local OPEN_GROUP: string = "Player" -- The command group every player holds

type CommandDefinition = Decree.CommandDefinition
type Context = Decree.Context

Decree.registry:registerHook("beforeRun", function (context: Context): string?
	if context.group ~= OPEN_GROUP then
		return `{context.name} is not open to you.`
	end

	return nil
end)

Decree.registry:registerCommandsIn(ServerScriptService.Commands)

Decree:start({
	rate = { perSecond = 1, burst = 4 },

	canAccess = function (_: Player, command: CommandDefinition): boolean
		return command.group == OPEN_GROUP
	end,
})
```

The command is a folder, `ServerScriptService/Commands/Echo/`, holding its definition, `Echo.luau`:

```luau
--!strict
return {
	name = "echo",
	description = "Replies with the text you give it.",
	group = "Player",
	args = {
		{ name = "text", type = "string", description = "What to reply with" },
	},
}
```

and its server half, `EchoServer.luau`:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

type Context = Decree.Context
type Kind = Decree.Kind

return function (_: Context, text: string): (string, Kind)
	return text, "Ok"
end
```

The client script goes in `StarterPlayer/StarterPlayerScripts`:

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- The server moves the client half to ReplicatedStorage at run time, so its type comes from where Wally installs it
type DecreeClient = typeof(require(
	ServerScriptService.ServerPackages._Index["fadeluc-123_decree@0.1.0"].decree.DecreeClient
))

local DecreeClient: DecreeClient = (require :: any)(ReplicatedStorage:WaitForChild("DecreeClient"))

DecreeClient:start()
```

In a play test, press F2 and type `echo hello`. The console prints `hello` in the Ok color. [Typing notes](#typing-notes) explains the client's two require lines.

## The server

### start

`Decree:start(settings)` runs once, after the game has registered its hooks and commands. Its settings are:

- `rate = { perSecond: number, burst: number? }`, required. Each player's allowance for typed lines and, separately, for list requests, both applied through Volt. `burst` is `perSecond` when left out, and both must be numbers above 0. Until `start` runs, the rates in Decree's schema apply, and every line is refused anyway.
- `canAccess: (player: Player, command: CommandDefinition) -> boolean`, optional, but without it no player holds any command. It must answer at once, without yielding. Only `true` grants the command, and an error answers `false` with a warning.
- `confirmSeconds: number`, required once any registered command or subcommand has a `confirm` key. How long a line that asks for confirmation waits for `confirm`. It must be above 0.
- `onFailure: (player: (Player | Bot)?, kind: string, detail: string) -> ()`, optional. Hears every failure Volt reports on Decree's scope, each on a thread of its own. `Bot` is Volt's `{ Name: string }`. See [Volt failures](#volt-failures).

`start` raises an error on a second call, on settings that aren't a table, on a missing `rate` or a `perSecond` or `burst` that isn't a number above 0, on a `confirmSeconds` that isn't a number above 0, on a `canAccess` or `onFailure` that isn't a function, and on no `confirmSeconds` while a registered command asks for confirmation. Each message starts with `[Decree]`.

It warns once when no `beforeRun` hook is registered yet (`[Decree] No beforeRun hook is registered, so every command is refused until one is.`) and once when `canAccess` is missing (`[Decree] start was given no canAccess, so no player holds any command.`).

Until `start` runs, every typed line is refused with "Decree has not started" and every console gets an empty list, which `start` then replaces.

### Registering commands, types and hooks

The server object's `registry` holds the commands, the argument types and the hooks:

| Call | What it does |
|---|---|
| `registerCommandsIn(container)` | Registers every command in a container and the folders inside it. See [A command's modules](#a-commands-modules). |
| `registerCommand(module, serverModule?, clientModule?)` | Registers the command a definition module returns, with the run its server half returns and its device half. |
| `registerCommandObject(definition)` | Registers a definition table directly. It has no device half. |
| `registerHook(name, callback, priority?)` | Registers a `beforeRun` or `afterRun` hook on the server. See [Hooks](#hooks). |
| `registerType(name, definition)` | Registers an argument type. See [Your own types](#your-own-types). |
| `registerTypesIn(container)` | Registers every type of every ModuleScript in a container and its folders, each module returning `{ [string]: TypeDefinition }`. |
| `registerTypeAlias(name, union)` | Names a whole union of types, such as `"string # integer"`, which an argument's `type` can then name. |
| `registerTypePrefix(name, union)` | Adds a prefixed type after a type's name, such as `"# positiveInteger"`, so a prefix typed before a value picks another type. |
| `getCommand(name)` | The definition a name or alias finds, in any case. |
| `getCommands()` | Every definition once, in registration order. |
| `getCommandNames(includeAliases?, executor?)` | Every command's name, with aliases when asked. With an executor, only the commands that player holds. |
| `getDeviceHalf(name)` | The `{Name}Client` module a command registered with. |
| `getType(name)`, `getTypeName(name)`, `getTypeNames()`, `hasType(typeName)` | Type lookups: a definition, the union a name expands to, every registered name, and whether every type in a name's union is registered. |
| `hasHook(name)` | Whether any hook of that name is registered. |

A command registered after `start` reaches the joined players' lists on the next deferred step.

### Gating by rank

`canAccess` decides which commands a player's console holds, and with them which device halves are cloned to that player. The `beforeRun` hook decides each run. They should agree, but the hook is the gate: a player's client can send any text, and the server refuses it there.

Decree asks `canAccess` about every command when `start` runs, when a player joins, when a command registers after `start`, and when the game calls `Decree:refreshAccess(player)`. When the answer changes a player's list, Decree clones or destroys that player's device halves to match and pushes them the whole new list once their console has asked for one, so a rank that arrives after the player joins shows without a rejoin.

This gate gives each command group a lowest rank and reads each player's rank from an attribute the game sets:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local RANK: string = "Rank" -- The player attribute the game sets to each player's rank
local RANK_MISSING: string = "Your rank is still loading, so try again in a moment."

-- The lowest rank that holds each command group, by the group a definition names
local GROUP_RANKS: { [string]: number } = {
	Player = 0,
	Admin = 255,
}

type CommandDefinition = Decree.CommandDefinition
type Context = Decree.Context

local function holds(rank: number?, group: string?): boolean
	if rank == nil or group == nil then
		return false
	end

	local needed: number? = GROUP_RANKS[group]

	return needed ~= nil and rank >= needed
end

Decree.registry:registerHook("beforeRun", function (context: Context): string?
	local rank = context.executor:GetAttribute(RANK) :: number?

	if rank == nil then
		return RANK_MISSING
	elseif not holds(rank, context.group) then
		return `{context.name} needs a higher rank than yours.`
	end

	return nil
end)

Decree.registry:registerCommandsIn(ServerScriptService.Commands)

Decree:start({
	rate = { perSecond = 1, burst = 4 },
	confirmSeconds = 30,

	canAccess = function (player: Player, command: CommandDefinition): boolean
		return holds(player:GetAttribute(RANK) :: number?, command.group)
	end,
})
```

Wherever the game sets a player's rank, once it knows it and again whenever it changes, it calls `refreshAccess` after:

```luau
player:SetAttribute(RANK, rank)
Decree:refreshAccess(player)
```

Hooks and `canAccess` never yield, so a rank that takes a web call, such as a group rank, is looked up when the player joins. Until it arrives the player holds nothing, and the hook refuses their lines.

### Hooks

`Decree.registry:registerHook(name, callback, priority?)` registers a hook on the server, the only place hooks run. `name` is `"beforeRun"` or `"afterRun"`, and a hook is `(context: Context) -> string?`. Hooks run from the lowest `priority` up, 0 when left out, and hooks of one priority run in the order they registered. A hook is called synchronously.

- `beforeRun` hooks run before every command that reaches the server, after its line has parsed and validated. A hook returns `nil` to pass the command, and any other value refuses it, as text with the Refused kind. The first refusal ends the run.
- With no `beforeRun` hook registered, every command that reaches the server is refused with "No permission hook is registered", in Studio too.
- `afterRun` hooks run once the command has an answer, with that answer in `context.response`. This covers a server half that raised, rejected or ran past its time limit, whose answer is the Error reply, and the question a `confirm` command asks. The first hook that returns text replaces the reply, as Info. They don't run for a line a `beforeRun` hook or a guard refused.

This `afterRun` hook prints an audit line for every command that reached its run:

```luau
Decree.registry:registerHook("afterRun", function (context: Context): string?
	print(`{context.executor.Name} ran "{context.rawText}" and got "{tostring(context.response)}"`)

	-- Any text returned here would replace the reply
	return nil
end)
```

On the server a typed line goes through these steps: Volt's packet, decode and rate checks; Decree's refusals of a bot, a line before `start` and a second line while one runs; a `confirm` line, which Decree answers itself; parsing and validating every argument again; the `beforeRun` hooks; the definition's guards; the confirmation question; the server half; the `afterRun` hooks; and the reply, once the lines the command sent have gone out.

### Other server calls

- `Decree:refreshAccess(player)` asks `canAccess` about every command again for one player. See [Gating by rank](#gating-by-rank).
- `Decree.dispatcher:evaluateAndRun(text, player)` runs a line as that player from server code, through the same hooks and guards, and returns a Promise of the reply's text and kind that never rejects. With no player it answers "A command run from the server needs the player who runs it." as Refused.
- `Decree.dispatcher:sendEvent(player, "AddLine", text, kind?)` prints a line in a player's console from the game's own code. `AddLine` is the only event the server sends, and a line sent this way has no caller, so it isn't filtered.
- `Decree.util` holds the text helpers and the type builders, and `Decree.guards` the guard factories.

### Volt failures

When the game passes `onFailure`, Decree registers one handler with Volt. A `handshake` failure first goes to Volt's own default handler, which kicks a player whose client schema doesn't match with Volt's message and only warns about a bot. Then every failure, `handshake` included, goes to `onFailure` on a thread of its own. For every other kind Volt's default handler no longer runs, so its warnings stop and `onFailure` takes their place.

Without `onFailure`, Volt's default handler handles every kind: `departed` and `budget` are silent, `handshake` kicks the player (never a bot), and any other kind warns, at most once a minute for each kind and player.

The kinds Volt 0.1.0 can report on Decree's server scope are:

| Kind | What happened |
|---|---|
| `packet` | Volt refused a packet before decoding it: over 8,192 bytes, from a player who has left, sent before the handshake, or malformed. |
| `rate` | A player passed 240 packets a second, or the `rate` on `Decree.run` or `Decree.commands`. A call over its rate is answered "rate limited", which the console prints as "The command failed: rate limited". |
| `handshake` | The client's schema hash differs from the server's. |
| `decode` | A message failed to decode, such as text out of its byte range or not valid UTF-8. The rest of its packet is dropped. |
| `handler` | A handler raised or returned a value its type can't carry. Decree's `run` handler answers every line itself, its errors included, so on Decree's scope this is the `commands` call refusing a list past the [size limits](#limits). |
| `outgoing` | A message was dropped because the player's frame had no room under Volt's 262,144-byte cap. |
| `departed` | A line was fired at a player who had left or whose handshake failed. |

Volt reports `budget` only for a scope with a byte budget, and Decree's scope has none. Failures on the player's own device keep Volt's built-in handling either way.

Bots reach Volt's network too. Decree gives a bot an empty list, refuses every line from one with "Decree takes no commands from a bot.", never kicks one, and checks for a bot before any game code, such as `canAccess` or a hook, sees the player.

This `onFailure` warns with the player's name:

```luau
onFailure = function (player: (Player | { Name: string })?, kind: string, detail: string)
	local name: string = player and player.Name or "no player"

	warn(`Volt reported a {kind} failure for {name}: {detail}`)
end,
```

## Writing commands

### A command's modules

A command is a folder of plain ModuleScripts named after it:

- `{Name}`, such as `Kill/Kill.luau`, returns the definition.
- `{Name}Server`, such as `Kill/KillServer.luau`, returns the server half, the function that runs on the server.
- `{Name}Client`, such as `DeviceTime/DeviceTimeClient.luau`, returns the device half, which runs on the player's own device. See [Device halves](#device-halves).

A command has a server half, a device half or both, and one with neither answers "No implementation." while the server warns. `Decree.registry:registerCommandsIn(container)` walks the container and every folder inside it, pairs each `{Name}` module with the `{Name}Server` and `{Name}Client` modules beside it, and leaves every module where it is. A module is a half only when its name is a sibling module's name followed by `Server` or `Client`, so a command module named `ServerStatus` or `ClientInfo` is still a command. The definition's `name` is what players type, whatever the module is called.

Use plain `.luau` ModuleScripts, never Rojo's `.server.luau` or `.client.luau` scripts. A half runs when its command is typed, not at boot.

### Definition keys

| Key | Value | What it does |
|---|---|---|
| `name` | text, 1 to 64 bytes | The word that runs the command, matched in any case. `confirm` and `clear` are Decree's own and taken. |
| `aliases` | up to 16 texts, 1 to 64 bytes each | Other words that run it. |
| `description` | text, up to 1,024 bytes | Shown in autocomplete. |
| `group` | text, 1 to 64 bytes | Plain data for the game's `canAccess` and hooks. |
| `system` | text, 1 to 64 bytes | Plain data that reaches the player's list, for the game's own help. |
| `tags` | up to 16 texts, 1 to 64 bytes each | Plain data that reaches the player's list, such as `"Admin only"`. |
| `args` | up to 32 argument definitions | See [Arguments](#arguments). |
| `autoExec` | up to 16 lines, 1 to 4,096 bytes each | Lines the console runs when it receives the command. See [autoExec](#autoexec). |
| `run` | a function | The server half. `{Name}Server` fills it in. |
| `guards` | a list of guards | Server checks that run after the `beforeRun` hooks. See [Guards](#guards). |
| `confirm` | `true` or a function | Asks the player to send `confirm` first. See [Confirm](#confirm). |
| `subcommands` | up to 16 subcommand definitions | See [Subcommands](#subcommands). |

Registration raises an error, naming the command and the key, for an unknown key; for `clientRun`, which goes in the command's `{Name}Client` module now, and `data`, which is removed; for `args` beside `subcommands`, or `confirm` beside `subcommands`; for a name or alias another command or Decree already has, or one listed twice; for text or a list of the wrong type or past its bounds; for an argument that isn't a plain table, names an unknown key, or carries an inline type table; for a required argument after an optional one; and, after `start` was given no `confirmSeconds`, for a command that asks for confirmation.

### The server half

A server half is called with the context and one value for each argument, in order:

```luau
return function (context: Context, target: Player, text: string): (string, Kind)
```

It returns the reply's text and, optionally, its kind, or a Promise that resolves to them.

- The text goes through `tostring`. A half that returns nothing replies "Command executed." as Info.
- The kind is `"Info"`, `"Ok"`, `"Refused"` or `"Error"`. Anything else, nothing, a Color3 or an options table included, is Info.
- A reply is cut to 16,384 bytes at a character boundary, and each byte that isn't valid UTF-8 becomes U+FFFD.
- A half that raises, returns a Promise that rejects, or returns one still pending after 9 seconds is answered "An error occurred while running this command. Check the console for more information." as Error, and the server warns with the cause.
- A half that has to wait returns a Promise. One that yields instead holds the player's one waiting line, and after 10 seconds the console gives up with "The command failed: timeout".
- The reply goes out after the lines the command sent while it ran, waiting for them until 9.5 seconds after the line arrived. Past that the reply goes first, and the server warns.

This server half looks a user up through a Promise:

```luau
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Decree = require(ServerScriptService.ServerPackages.Decree)

type Context = Decree.Context
type Kind = Decree.Kind

return function (_: Context, userId: number): any
	return Promise.try(function (): string
		return Players:GetNameFromUserIdAsync(userId)
	end)
		:andThen(function (name: string): (string, Kind)
			return `User {userId} is {name}.`, "Ok"
		end)
		:catch(function (): (string, Kind)
			return `No user has the id {userId}.`, "Refused"
		end)
end
```

with its definition:

```luau
--!strict
return {
	name = "username",
	description = "Looks up the name of a user id.",
	group = "Player",
	args = {
		{ name = "userId", type = "positiveInteger", description = "The id to look up" },
	},
}
```

### The context

The context is one typed line naming a command. The same context goes through the hooks, the guards and the half.

| Field or method | What it is |
|---|---|
| `executor` | The player who ran the line. |
| `name` | The command's name. |
| `alias` | The word the player typed for it. |
| `aliases`, `description`, `group` | The definition's values. |
| `object` | The command's definition. |
| `subcommand` | The subcommand's definition, or nil. |
| `rawText` | The whole line as typed. |
| `rawArguments` | The words typed for the arguments. |
| `arguments`, `getArgument(index)` | The argument contexts, and the one at a position. |
| `argumentDefinitions` | The definitions of the arguments the line takes, the subcommand's when it has one. |
| `state` | An empty table for the line's own use, shared by its hooks, guards and half. |
| `response` | The answer's first value as the half returned it, or the Error reply's text, set before the `afterRun` hooks run. |
| `decree` | The server object on the server, and the client object in a device half. |
| `dispatcher` | The realm's dispatcher. |
| `reply(text, kind?)` | Prints a line in the executor's console while the command runs, in a reply kind's color. |
| `sendEvent(player, "AddLine", text, kind?)` | Prints a line in another player's console. On the client it runs a local event for the local player instead. |
| `getData()` | Always nil. |
| `broadcastEvent(event)` | Raises an error. Decree sends no event to every client, so a game that broadcasts uses its own event. |

On the server, `reply` and `sendEvent` never wait. Each line joins its recipient's queue, which sends lines in order and paces them. A line to a player other than the command's executor is filtered with TextService for that player first, and one that fails to filter is dropped with a warning. A line to the executor goes as it is. This server half prints in another player's console:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

type Context = Decree.Context
type Kind = Decree.Kind

return function (context: Context, target: Player, text: string): (string, Kind)
	-- Decree filters a line for its recipient whenever the recipient is not the caller
	context:sendEvent(target, "AddLine", `{context.executor.Name} whispers: {text}`, "Info")

	return `Sent to {target.Name}.`, "Ok"
end
```

### Arguments

An argument definition has these keys:

| Key | Value | What it does |
|---|---|---|
| `name` | text, 1 to 64 bytes | Shown in autocomplete and refusals. |
| `type` | text, 1 to 256 bytes | A registered type's name, an alias, or a union such as `"integer # string"`. |
| `description` | text, up to 512 bytes | Shown in autocomplete. |
| `optional` | boolean | The argument may be left out, and the half gets nil for it. |
| `default` | any value | The value the server half gets when the argument is left out. It makes the argument optional. |

A required argument can't follow an optional one. The words past the last argument fold into it, so a last `string` argument takes the rest of the line. A run of words in matching quotes is one argument, and `\t`, `\n`, `\xHH` and `\uHHHH` read as escapes. A default stays on the server: a device half gets nil for an argument left out.

These operators work in an argument whose type supports them:

- `.` is the type's default for the caller, such as the caller's own name for `player`.
- `?` is one of the type's suggestions at random.
- In a listable type, `*` is every suggestion, `**` every suggestion but the caller's own, and `?3` three at random.
- `player`, `playerId` and their listable forms also read `me`, `all`, `others` and `random` as `.`, `*`, `**` and `?`.
- A backslash before `.`, `?` or `*` keeps the character as text.

A listable type reads values separated by commas, such as `Player1,Player2` for `players`, and gives the half a list of the distinct values.

The built-in types:

| Type | Reads | Listable form |
|---|---|---|
| `string` | Any text. | `strings` |
| `number` | A finite number. | `numbers` |
| `integer` | A whole number. | `integers` |
| `positiveInteger` | A whole number above 0. | `positiveIntegers` |
| `nonNegativeInteger` | 0 or a whole number above it. | `nonNegativeIntegers` |
| `byte` | A whole number from 0 to 255. | `bytes` |
| `digit` | A whole number from 0 to 9. | `digits` |
| `boolean` | `true`, `t`, `yes`, `y`, `on`, `enable`, `enabled`, `1` or `+`, and `false`, `f`, `no`, `n`, `off`, `disable`, `disabled`, `0` or `-`, in any case. | `booleans` |
| `url` | Text that starts with `http://` or `https://`. | `urls` |
| `json` | JSON text, decoded with `HttpService:JSONDecode`. | none |
| `mathOperator` | `+`, `-`, `*`, `/`, `**` or `%`, as a table with `Name` and `perform(a, b)`. | none |
| `player` | A joined player, found by part of their name. | `players`, which also reads `%` and a team name as that team's players |
| `playerId` | A full user name as a user id, or `#` and a user id. The name lookup runs on the server. | `playerIds` |
| `team` | A team. | `teams` |
| `teamPlayers` | A team's players, as a list. | itself |
| `teamColor` | A team's TeamColor. | `teamColors` |
| `brickColor` | A BrickColor by name, or `%` and a team for its color. | `brickColors` |
| `brickColor3` | A BrickColor's Color3, by name. | `brickColor3s` |
| `color3` | Red, green and blue from 0 to 255, such as `255,128,0`, or `#` and a hex color, or `!` and a BrickColor name. | `color3s` |
| `hexColor3` | A hex color such as `#ff8000` or `#f80`, the `#` optional. | `hexColor3s` |
| `vector3`, `vector2` | Numbers separated by commas, such as `1,2,3`. | `vector3s`, `vector2s` |
| `positionVector3` | A `vector3` where `~` is the caller's character position on that axis and `~5` is 5 from it. | `positionVector3s` |
| `duration` | Numbers with units, such as `1d6h` or `30m`, as seconds. `m` alone is minutes. | `durations` |
| `command` | One of the caller's own commands. | `commands` |
| `type` | A registered type's name. | `types` |
| `userInput` | A UserInputType or a KeyCode. | `userInputs` |

### Your own types

A type is a table of these keys, each optional except `parse`:

| Key | What it does |
|---|---|
| `transform(text, executor)` | Turns the typed text into the values every later step takes. Without it they take the text. |
| `validate(...)` | Returns whether the value is valid and, if not, why. Runs as the player types and again when the line is sent. |
| `validateOnce(...)` | The same, run only when the line is sent, for a check too slow to run on every key. |
| `autocomplete(...)` | Returns the suggestions and, optionally, `{ isPartial = true }` when they are only part of a value. |
| `parse(...)` | Returns the value the half gets. |
| `displayName` | The name autocomplete shows, the registered name when left out. |
| `listable` | Whether `parse` returns a list. |
| `prefixes` | A prefixed union registered with the type, such as `"# positiveInteger"`. |
| `default(executor)` | The text `.` stands for. |
| `argumentOperatorAliases` | Words that stand for operators, such as `{ me = "." }`. |

A type's name is alphanumeric and starts with a lowercase letter or a digit, and each name registers once. Parsing and autocomplete run on the client as well as the server, so a game registers each of its own types on both realms under the same name, and on the client before it calls `start`. The server leaves a command out of every list, with one warning, while one of its argument types isn't registered on the server.

`Decree.util` on the server and `DecreeClient.util` on the client build common types: `makeEnumType(name, values)` for a set of names, Instances, EnumItems or an Enum, `makeListableType(definition, override?)` for the listable form of a type, and `makeSequenceType(options)` for values such as a Vector3. This registers a `material` type on the server:

```luau
Decree.registry:registerType("material", Decree.util.makeEnumType("Material", Enum.Material))
```

and this on the client, before `start`:

```luau
DecreeClient.registry:registerType("material", DecreeClient.util.makeEnumType("Material", Enum.Material))
```

### Guards

A guard is `(context: Context) -> string?`, a check in the definition's `guards` list. Guards run on the server after the `beforeRun` hooks, in order. A guard returns nil to pass and text to refuse, as Refused. `Decree.guards` makes five:

| Factory | Refuses |
|---|---|
| `hasCharacter(index?)` | A caller, or the player or players in argument `index`, with no character holding a HumanoidRootPart. |
| `maxArrayLength(index, maxCount)` | A list argument with more than `maxCount` values. |
| `maxStringLength(index, maxLength)` | A text argument longer than `maxLength` bytes. |
| `nonEmptyString(index)` | An argument that isn't text holding more than whitespace. |
| `notEquals(index, forbiddenValue)` | An argument whose value is `forbiddenValue`. |

The definition requires the server object for its guards:

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

return {
	name = "kill",
	description = "Resets your character.",
	group = "Player",
	guards = { Decree.guards.hasCharacter() },
}
```

```luau
--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

type Context = Decree.Context
type Kind = Decree.Kind

return function (context: Context): (string, Kind)
	-- The hasCharacter guard has already refused a caller with no character
	local character = context.executor.Character :: Model
	local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return "Your character has no Humanoid to reset.", "Refused"
	end

	humanoid.Health = 0

	return "Your character was reset.", "Ok"
end
```

### Subcommands

A command can hold a plain `subcommands` list one level deep instead of `args`. Each subcommand has a `name` (1 to 64 bytes, unique in any case), a `description` (up to 1,024 bytes), its own `args` and its own `confirm`. The first word after the command picks the subcommand, the server half gets `context.subcommand` and that subcommand's argument values, and a command with subcommands has no `confirm` of its own. A line with no subcommand is refused with the list of them, such as "kick takes a subcommand: player, others."

```luau
--!strict
return {
	name = "kick",
	description = "Removes players from this server.",
	group = "Admin",
	system = "Moderation",
	tags = { "Admin only" },
	subcommands = {
		{
			name = "player",
			description = "Kicks one player",
			args = {
				{ name = "player", type = "player", description = "Who to kick" },
			},
		},
		{
			name = "others",
			description = "Kicks every player but you, once you send confirm",
			confirm = true,
		},
	},
}
```

```luau
--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local KICKED: string = "An admin removed you from this server."

type Context = Decree.Context
type Kind = Decree.Kind
type SubcommandDefinition = Decree.SubcommandDefinition

return function (context: Context, target: Player?): (string, Kind)
	local subcommand = context.subcommand :: SubcommandDefinition

	if subcommand.name == "player" and target then
		target:Kick(KICKED)

		return `{target.Name} was kicked.`, "Ok"
	end

	for _, player: Player in Players:GetPlayers() do
		if player ~= context.executor then
			player:Kick(KICKED)
		end
	end

	return "Every other player was kicked.", "Ok"
end
```

### Confirm

A command or subcommand with a `confirm` key runs only once the same player sends `confirm` within `confirmSeconds`. The key is `true` or a function, `(context: Context) -> string?`.

- With `true`, the line replies, as Info, "Send confirm within 30 seconds to run: kick others", with the game's `confirmSeconds` and the typed line.
- A function returns the question to ask, such as exactly what the line will change, or nil to run the line at once.
- Each player has one waiting line, and a new question replaces it. `confirm` runs the waiting line again from the start, past the `beforeRun` hooks and the guards again, and it then runs without asking.
- `confirm` refuses, as Refused, "Nothing is waiting for confirm.", "The command waiting for confirm has expired." and "confirm takes no arguments."
- `confirm` is Decree's own command. It reaches every player who holds a command that asks for confirmation, and no game command may take its name.

### autoExec

`autoExec` lists lines the player's console runs, one at a time, when it receives the command, and again each time the command is handed to that player after being taken away. They run as that player. A line bound for the server is an ordinary typed line, so it counts against the `rate` and the one waiting line. Each line's reply is thrown away, so a line meant to show something prints it through `context:reply` while it runs.

```luau
autoExec = { "motd" },
```

### system and tags

`system` and `tags` are plain data. Decree shows neither itself. They reach the player's list with the command's aliases and its arguments' type names, so a game's own help command, as a device half reading `context.decree.registry:getCommands()`, can group commands by system and show their tags.

### Device halves

A `{Name}Client` module is the command's device half. When `canAccess` grants a player the command, the server clones the module into a ScreenGui named `DecreeCommands` in that player's PlayerGui, which replicates to that player alone, and names the clone after the definition's `name` followed by `Client`. It destroys the clone when the command is taken away. A bot gets none.

A device half returns its run, `(context, ...) -> (text, kind?)`, with the same returns and the same 9-second Promise limit as a server half. It runs on the player's device once the line has parsed and validated there, and its reply prints at once without a network round trip. A device half that returns nothing hands the line to the server, where the command's server half runs. The console holds a device command back, unseen and unrunnable, until its clone has arrived. The server's hooks and guards don't run for a device half's own answer, so keep a device half to the player's own screen. The server checks anything that reaches it.

The clone sits in the PlayerGui, so it can require only modules that replicate, never its server siblings, and its code is readable on that player's client, so it holds no secret. Its context's `decree` is the client object. This command has only a device half:

```luau
--!strict
return {
	name = "devicetime",
	description = "Answers with your device's clock, from your device.",
	group = "Player",
	args = {},
}
```

```luau
--!strict
local FORMAT: string = "LTS" -- Hours, minutes and seconds
local LOCALE: string = "en-us"

-- A clone in the player's PlayerGui reaches no server module, so the context goes untyped
return function (_: any): (string, string)
	return `Your device's clock reads {DateTime.now():FormatLocalTime(FORMAT, LOCALE)}.`, "Ok"
end
```

## Reply kinds

Every reply and printed line carries one of four kinds, which the console draws in the style's color for it:

| Kind | Default color | Decree uses it for |
|---|---|---|
| `Info` | (255, 255, 255) | A reply with no kind, the confirmation question, an `afterRun` hook's replacement, "Command executed." and "No implementation." |
| `Ok` | (131, 255, 131) | Nothing of its own. Commands return it for success. |
| `Refused` | (255, 153, 153) | A hook's or a guard's refusal, an unknown command or subcommand, a missing or invalid argument, a line the console refuses before sending, a line before `start`, from a bot or while another waits, and `confirm`'s refusals. |
| `Error` | (255, 73, 73) | A half that raised, rejected or ran out of time, a call Volt failed ("The command failed: " and its reason), and "Decree could not load your commands: " and the reason. |

Every line on the network is plain text, so no rich text arrives from the server. The typed line is echoed in the style's `echo` color after the prompt, and a line the console can't run prints its reason in the Refused color without being sent.

## The client

### start

`DecreeClient:start(settings?)` runs once. It builds the console, a ScreenGui named `Decree` in the PlayerGui with `ResetOnSpawn` off and `DisplayOrder` 1000, then listens for the server's lines and lists and asks for the player's commands. Its settings are:

- `style`, optional: a partial style table. Each key left out keeps its default.
- `maxLines`, optional: how many printed lines the console keeps, a whole number of 1 or more, 500 when left out. The oldest go first.

`start` raises an error on a second call, on a `maxLines` that isn't a whole number of 1 or more, on a style key the style doesn't have (`[Decree] The style has no key ...`), and on a style value of the wrong kind (`[Decree] The style's ... is a ..., where it takes a ...`). The style is fixed once `start` runs.

The style keys, each optional:

| Key | Type | Default | What it colors or sets |
|---|---|---|---|
| `background` | Color3 | (17, 17, 17) | The window behind the lines. |
| `text` | Color3 | (255, 255, 255) | The typed line while it's valid. |
| `invalid` | Color3 | (255, 73, 73) | The typed line while it isn't, and an invalid argument's description. |
| `prompt` | Color3 | (255, 223, 93) | The `Name$` prompt and the context line above it. |
| `echo` | Color3 | (255, 223, 93) | The typed line, printed as it's sent. |
| `info` | Color3 | (255, 255, 255) | An Info line. |
| `ok` | Color3 | (131, 255, 131) | An Ok line. |
| `refused` | Color3 | (255, 153, 153) | A Refused line. |
| `error` | Color3 | (255, 73, 73) | An Error line. |
| `suggestions` | Color3 | (59, 59, 59) | The suggestions' backgrounds. |
| `suggestionText` | Color3 | (255, 255, 255) | A suggestion, and the suggested argument's name, type and description. |
| `typed` | Color3 | (131, 222, 255) | The typed part of a suggestion. |
| `outputFont` | Font | `Font.fromEnum(Enum.Font.Code)` | The printed lines and the context line. Monospace. |
| `inputFont` | Font | `Font.fromEnum(Enum.Font.Code)` | The prompt, the typed line and the suggestions. Monospace. |
| `titleFont` | Font | `Font.fromEnum(Enum.Font.SourceSansBold)` | The suggested argument's name. |
| `descriptionFont` | Font | `Font.fromEnum(Enum.Font.SourceSansLight)` | Its description. |
| `typeFont` | Font | `Font.fromEnum(Enum.Font.SourceSans)` | Its type. |

Colors are `Color3.fromRGB` values.

### Opening the console

The console opens and closes with F2, the default activation key, which `setActivationKeys` changes. A game binds a gamepad button and a touch button through its own input code and calls `toggle`. Hide on lost focus is on by default, so a tap outside the console hides it. A button registered with `addToggleButton` doesn't count as outside, so it closes the console as well as opening it. This client script opens the console from a touch button and from D-pad Left as well as F2, in its own style:

```luau
--!strict
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Player = Players.LocalPlayer

local TOGGLE_ACTION: string = "ToggleConsole"
local TOUCH_BUTTON: boolean = false -- The game's own button below is the touch opener

type DecreeClient = typeof(require(
	ServerScriptService.ServerPackages._Index["fadeluc-123_decree@0.1.0"].decree.DecreeClient
))

local DecreeClient: DecreeClient = (require :: any)(ReplicatedStorage:WaitForChild("DecreeClient"))
local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui

-- A few keys off the defaults; every key left out keeps its default
local STYLE = {
	background = Color3.fromRGB(16, 24, 48),
	prompt = Color3.fromRGB(120, 200, 255),
	ok = Color3.fromRGB(64, 224, 176),
	titleFont = Font.fromEnum(Enum.Font.FredokaOne),
}

-- The new checker refuses a partial table held in a local as Style?, and start checks every key and kind itself
DecreeClient:start({ style = STYLE :: any, maxLines = 200 })

local buttonGui: ScreenGui = Instance.new("ScreenGui")
buttonGui.Name = "ConsoleButton"
buttonGui.ResetOnSpawn = false
buttonGui.Parent = PlayerGui

local button: TextButton = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -16)
button.Size = UDim2.fromOffset(112, 44)
button.Text = "Console"
button.Parent = buttonGui

DecreeClient:addToggleButton(button)

button.Activated:Connect(function ()
	DecreeClient:toggle()
end)

ContextActionService:BindAction(TOGGLE_ACTION, function (_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		DecreeClient:toggle()
	end

	return Enum.ContextActionResult.Sink
end, TOUCH_BUTTON, Enum.KeyCode.DPadLeft)
```

With mash to enable on, the console first opens only after five presses of an activation key, each within a second of the last. Showing the console focuses its text box and turns TextChatService's chat window, input bar and channel tabs off, and hiding it puts back the states they had. Escape and opening the Roblox menu hide it.

In the console, Enter runs the typed line, Tab completes the selected suggestion, Up and Down move through the suggestions or the history, and Ctrl+Backspace clears the line. The history is kept across teleports within the game.

### The prompt and the context line

The prompt reads `Name$`, the player's name, or `Name@Place$` once the game sets a place name with `setPlaceName`. `setContextLine(text)` shows a line above the prompt, and a call with no text hides it. This one names the place and the server, a line a game might set only for its admins:

```luau
DecreeClient:setContextLine(`Place {game.PlaceId} | Job {game.JobId}`)
```

### Decree's own commands

- `clear` empties the console. It runs only on the device and sends nothing, and every player who holds at least one command gets it.
- `confirm` runs the line waiting for confirmation. See [Confirm](#confirm).

No game command may take either name.

### Client calls

Each setter can be called before or after `start`.

| Call | What it does |
|---|---|
| `start(settings?)` | Builds the console and asks for the player's commands. |
| `setEnabled(enabled)` | Whether the activation keys, `show` and `toggle` open the console. Off hides it. On by default. |
| `setActivationKeys(keys)` | The `Enum.KeyCode` list that opens and closes the console, `{ Enum.KeyCode.F2 }` by default. |
| `setActivationUnlocksMouse(enabled)` | Whether the mouse is freed while the console shows. Off by default. |
| `setHideOnLostFocus(enabled)` | Whether a click or tap outside the console hides it. On by default. |
| `setMashToEnable(enabled)` | Whether the console first opens only after a mash of an activation key. Off by default. |
| `setPlaceName(name)` | The place name in the prompt, empty by default. |
| `setContextLine(text?)` | The line above the prompt, hidden with no text. |
| `addToggleButton(button)` | A game button that toggles the console, so a tap on it never counts as outside. Held until the button is destroyed. |
| `show()`, `hide()`, `toggle()` | Shows, hides or toggles the console. `show` and `toggle` do nothing before `start` or while it's disabled. |
| `handleEvent(name, callback)` | Sets the handler a local event runs, replacing any before it. `AddLine` prints a device half's `reply` and its local `sendEvent` lines. |
| `toggled:Connect(callback)` | Calls back with whether the console shows, each time that changes. Returns an object with `Disconnect`. |
| `gui` | The console's ScreenGui, once `start` builds it. |
| `registry` | The client's registry, for registering types and reading the player's commands. |
| `dispatcher` | `dispatcher:evaluateAndRun(text)` runs a line as the local player, with no echo, and returns a Promise of the reply's text and kind that never rejects. |
| `util` | The same helpers and type builders as the server's. |

## Limits

| Limit | Value |
|---|---|
| A typed line | 1 to 4,096 bytes of valid UTF-8. The console refuses anything else before sending: "Command cannot be empty.", "A command is at most 4096 bytes, and this one is N." or "A command must be valid UTF-8 text." |
| A reply or printed line | 16,384 bytes, cut at a character boundary past that. |
| Names, aliases, groups, systems, tags, argument and subcommand names | 1 to 64 bytes each. |
| An argument's type | 1 to 256 bytes. |
| A command's or subcommand's description | Up to 1,024 bytes. |
| An argument's description | Up to 512 bytes. |
| Aliases, tags, `autoExec` lines and subcommands | 16 each per command. An `autoExec` line is 1 to 4,096 bytes. |
| Arguments | 32 per command or subcommand. |
| A player's list | 512 commands, `confirm` included, and 131,072 bytes, counting each text's bytes plus 2. A list past either isn't sent: the console prints "Decree could not load your commands: " and the reason, and a pushed list warns on the server instead. |
| The rate | `rate.perSecond`, with a burst of `rate.burst`, per player, for typed lines and for list requests separately. |
| Waiting lines | One per player. A second line while one waits is refused with "Wait for your last command to finish.", by the console and by the server. |
| A half's Promise | 9 seconds, then Error. |
| A reply's wait for the command's earlier lines | Until 9.5 seconds after the line arrived. |
| The whole call | 10 seconds, then "The command failed: timeout". |
| Output pacing | 65,536 bytes of lines to one player per frame. The next line then waits for Volt's flush to that player, for up to 1 second, then goes on with a warning. |
| The console's lines | 500, or `maxLines`. |

## Typing notes

On the server, after the [typed install](#typed-install), `require(ServerScriptService.ServerPackages.Decree)` carries Decree's types: `ArgumentContext`, `ArgumentDefinition`, `CommandDefinition`, `Confirm`, `Context`, `Guard`, `Hook`, `HookName`, `Kind`, `Run`, `Settings`, `SubcommandDefinition` and `TypeDefinition`, named as `Decree.Context` and so on.

On the client, `require(ReplicatedStorage.DecreeClient)` is an unknown require to luau-lsp, since the server moves the client half there at run time and the sourcemap never shows it there. Type it from the installed package instead, as the quick start does:

```luau
type DecreeClient = typeof(require(
	ServerScriptService.ServerPackages._Index["fadeluc-123_decree@0.1.0"].decree.DecreeClient
))

local DecreeClient: DecreeClient = (require :: any)(ReplicatedStorage:WaitForChild("DecreeClient"))
```

- `typeof` in a type is never run, so the client never touches ServerScriptService, which is empty on a client.
- The path goes through `_Index`, since the `Decree` link module has no children. Its folder, `fadeluc-123_decree@0.1.0`, changes with each version the game installs.
- The client half's own types, `Style` among them, can't be named from a client script, since naming them takes a `require` that would run on the client.

A style table written in the `start` call analyzes clean. Held in a local or returned by a config module, a partial style table is refused by the new checker as `Style?`, so pass it `:: any`, as the client script above does. `start` checks every key and kind at run time.

A device half's clone can reach no server module, so its context is typed `any`. Promise is typed `any` wherever Decree's code and its examples require it.

## Differences from Cmdr 1.13.1

- Networking runs through Volt. The `CmdrEvent` and `CmdrFunction` remotes are gone, and Decree's remotes live under `ReplicatedStorage.Volt.Decree`.
- Decree is a server package. Its client half moves to `ReplicatedStorage.DecreeClient` when the server requires it, the window is a ScreenGui named `Decree`, and every name and message drops Cmdr's.
- Every public name is camelCase, with no aliases under the old names: `registerCommandsIn`, `evaluateAndRun`, `beforeRun`, `executor`, `reply` and the rest. `SplitPrioritizedDelimeter` is `splitPrioritizedDelimiter`, and `mathOperator`'s `Perform` is `perform`.
- Both realms start with `start(settings)`. The server requires a `rate`, and refuses every line with "Decree has not started" until `start` runs.
- Each console holds only its player's commands, from the server's list and `canAccess`, with `refreshAccess` to change it. No definition or server half replicates, and the shared `Commands` folder is gone.
- A command is a folder of `{Name}`, `{Name}Server` and `{Name}Client` modules. The `ClientRun` and `Data` keys are removed and refused at registration, server `getData` returns nil, and a device half is cloned only to the players who hold its command.
- Hooks and guards run on the server only. Client hooks, `RegisterHooksIn` and the `BeforeCommandRegister` hook are removed.
- With no `beforeRun` hook every command is refused, in Studio too, and the `DefaultUtil` and `UserAlias` groups no longer run without one.
- All 39 built-in commands and `RegisterDefaultCommands` are removed. Decree ships only its own `confirm` and `clear`, and their names are taken.
- The `storedKey` and `storedKeys` types, the `IsDataStoreAvailable` guard, the DataStore read at server start, `GetStore`, the Message event and its announcement line are removed.
- `Util.RunCommandString`, `Util.RunEmbeddedCommands`, `Util.EncodeEscapedOperator` and `Util.EncodeEscapedOperators`, `Util.MakeAliasCommand`, `Util.SubstituteArgs`, `Util.DictionaryKeys`, `Util.Mutex`, `Util.Each`, `Util.GetTextSize`, `Util.EmulateTabstops`, `Dispatcher:Run`, `Dispatcher:GetHistory`, `Registry:GetCommandsAsStrings`, `Registry:AddHook`, the context's `HasImplementation` and `GetLastArgument`, the forwarding calls and the read-only proxies are removed. A server run with no player is refused.
- `RegisterCommand` and `RegisterCommandsIn` lose their `filter` and `isDefault` parameters. A repeated command name now errors.
- Replies take a kind, Info, Ok, Refused or Error, in place of a Color3. A Color3 or options table still works as Info, and no line carries rich text.
- A server half may return a Promise, with a 9-second limit, and `afterRun` hooks also run for a half that raised, rejected or ran out of time.
- New definition keys: `subcommands`, `confirm`, `system` and `tags`.
- Server `sendEvent` sends only `AddLine`, filtered for a recipient other than the caller, and `broadcastEvent` raises an error.
- The console takes a style table instead of a game-made `Cmdr` ScreenGui, wraps long lines, keeps `maxLines` lines, and adds the context line, `addToggleButton`, `clear`, gamepad selection of the window and its text box, and an echo color.
- A typed line is at most 4,096 bytes, down from 10,000, and unknown-command messages no longer suggest the help command.
- `toggled` is no longer a BindableEvent. `Connect` returns an object with `Disconnect`.
- Fixed on the way: a typed backslash before an operator was lost; four BrickColor names showed twice in suggestions; a parse error locked the console; `splitString` let a piece past its max through; `*`, `**` and `?N` threw on a type with no suggestions; only the first escaped wildcard was freed; `splitPrioritizedDelimiter` found `.` in any text; hooks of equal priority ran out of order; number types read `inf` and `nan`; one type table couldn't register under two names; a type alias could skip the name rule or take a type's name; a fuzzy finder didn't rank equal Enum matches by the shorter name; `playerId` failed for a player named like a Players member; `duration` read `1h foo` as one hour; a command named `ServerStatus` never registered; a client-run command's Promise had no time limit; `?N` emptied a type's own suggestion list; and a required argument after an optional one registered, then refused every line.

## Security

How to report a vulnerability is in [SECURITY.md](SECURITY.md).

## License

Decree is licensed under the Apache License 2.0, in [LICENSE](LICENSE). It includes code from Cmdr 1.13.1, which is MIT licensed, and [NOTICE](NOTICE) carries Cmdr's copyright and permission notice.
