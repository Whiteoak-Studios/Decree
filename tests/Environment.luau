--[[
    Loads Decree's src/ fresh for each case under a fake game, script,
    require and task, with stubbed services, Promise and dressed players on
    Volt's mock, and further clients of the same server
--]]

--!strict
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides
local serde = require("@lune/serde")
local task = require("@lune/task")

local Volt = require("@volt")
local VoltHub = require("@volt/Hub")
local VoltMock = require("@volt/Mock")

-- Each folder a case requires from, and the module it mounts as in ServerPackages, where a game installs Decree
local ROOTS: { [string]: string } = { src = "Decree" }
local INIT: string = "init.luau"
local MODULE_FILE: string = "^(.+)%.luau$" -- A file's name or path without its extension
local STEM: string = "([^/]+)%.luau$" -- A further file's name without its folders or extension
local FOLDER_NAME: string = "([^/]+)/*$" -- A further folder's last segment, the name Rojo gives it
local PROMISE_LINK: string = "Packages/Promise.lua"
local PROMISE_KEY: string = "Packages/Promise"
local PROMISE_FILE: string = "lib/init.lua" -- Promise's module inside the folder Wally installs it in
local LINK: string = `_Index%["([^"]+)"%]%["([^"]+)"%]` -- The folder a Wally link file points its alias at
local SELF: string = "@self" -- The first segment of a string require that starts at the module itself
local HERE: string = "." -- One that starts at its parent
local UP: string = ".." -- One that starts a level further up, and any later segment that climbs one
local SERVER: string = "server" -- The side RunService reports by default, and a server schema's side
local PLAYER: string = "Player" -- The Name of the one player each environment joins to its mock
local FRAME: number = 1 / 60 -- Seconds between the fake Heartbeat's frames
local ROUND_TRIP: number = 3 -- Mock steps a client's call takes to settle: one to send, one to answer, one to hear
local QUIET: string = "--quiet" -- Keeps volt to its errors when compile runs it

-- The Roblox globals the loaded files build with, which Lune provides
local DATATYPES: { string } = {
	"BrickColor",
	"CFrame",
	"Color3",
	"Enum",
	"Font",
	"Instance",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector3",
}

type Mock = Volt.Mock
type Schema = Volt.Schema
type Transport = Volt.Transport

type Module = {
	path: string,
	source: string?, -- Read when mounted, so a require never waits on a read; a stand-in has none
	loading: boolean,
	loaded: boolean,
	result: any,
}

type Connection = { Disconnect: (self: Connection) -> () }

type Heartbeat = {
	Connect: (self: Heartbeat, callback: (delta: number) -> ()) -> Connection,
	Wait: (self: Heartbeat) -> number,
}

type Signal = {
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
}

-- An action ContextActionService holds, as the window bound it
type Action = {
	callback: (...any) -> ...any,
	touchButton: boolean,
	priority: number,
	inputs: { any },
}

-- What every environment over one mock shares, as one server's clients share it
type World = {
	mock: Mock,
	teams: { any }, -- Every team Teams:create made, in the order it made them
	userIds: { [string]: number }, -- What GetUserIdFromNameAsync answers for a name, which a case fills
}

export type Player = VoltMock.Player & {
	DisplayName: string,
	PlayerGui: any, -- One PlayerGui instance, the same in every environment over the player's mock
	Character: any?, -- Nil until a case sets it
	Team: any?, -- Nil until a case sets it to a team Teams:create made
	IsA: (self: any, className: string) -> boolean,
	WaitForChild: (self: any, name: string) -> any,
}

export type Side = "server" | "client"

export type Options = {
	side: Side?, -- The side RunService reports, the server by default
	files: { string }?, -- Further module files, such as a test schema's compiled modules, mounted in ReplicatedStorage
	folders: { string }?, -- Further folders, such as fixtures, mounted in ReplicatedStorage as Rojo maps them
}

export type Environment = {
	require: (target: any) -> any, -- A ModuleScript's module, or a mounted file's by its path, such as src/Guards
	find: (path: string) -> any, -- What a file mounted as, by its path without the extension, or a folder, by its path
	connect: (transport: Transport, player: any) -> Environment, -- A further client of this server's mock
	game: any, -- The fake game every loaded file sees
	mock: Mock, -- The network the generated modules run over
	player: Player, -- The player whose client transport a client module runs on
}

-- Each dressed player and team by the class its IsA answers for; weak, so none outlives its case
local Dressed: { [any]: string } = setmetatable({}, { __mode = "k" })

local Environment = {
	ROUND_TRIP = ROUND_TRIP,
}

--[[
    Compiles a test schema with the pinned volt binary, after making the
    folder its options write to, which volt needs to exist
--]]

function Environment.compile(schema: string, output: string): (boolean, string | nil)
	fs.writeDir(output)

	local compiled: process.ExecResult = process.exec("volt", { schema, QUIET })
	if not compiled.ok then
		return false, `volt could not compile {schema}: {compiled.stdout}{compiled.stderr}`
	end

	return true, nil
end

--[[
    A Heartbeat on Lune's scheduler for Promise's timers: one thread fires
    every connection once a frame, and stops when the last one disconnects
--]]

local function heartbeat(): Heartbeat
	local callbacks: { [{ nil }]: (delta: number) -> () } = {}
	local running: boolean = false

	local function pump()
		while next(callbacks) ~= nil do
			local delta: number = task.wait(FRAME)

			-- A copy, so a callback that disconnects another mid-frame skips none and runs no disconnected one
			for token: { nil }, callback: (delta: number) -> () in table.clone(callbacks) do
				if callbacks[token] then
					callback(delta)
				end
			end
		end

		running = false
	end

	return {
		Connect = function (_: Heartbeat, callback: (delta: number) -> ()): Connection
			local token: { nil } = {}
			callbacks[token] = callback

			if not running then
				running = true
				task.spawn(pump)
			end

			return {
				Disconnect = function (_: Connection)
					callbacks[token] = nil
				end,
			}
		end,

		Wait = function (_: Heartbeat): number
			return task.wait(FRAME)
		end,
	}
end

--[[
    A signal a stub exposes: Connect as the engine's, and Fire, which a case
    calls in the engine's place, running each connection on its own thread
--]]

local function signal(): Signal
	local callbacks: { [{ nil }]: (...any) -> () } = {}

	return {
		Connect = function (_: Signal, callback: (...any) -> ()): Connection
			local token: { nil } = {}
			callbacks[token] = callback

			return {
				Disconnect = function (_: Connection)
					callbacks[token] = nil
				end,
			}
		end,

		Fire = function (_: Signal, ...: any)
			-- A copy, so a connection that disconnects another mid-fire skips none and runs no disconnected one
			for token: { nil }, callback: (...any) -> () in table.clone(callbacks) do
				if callbacks[token] then
					task.spawn(callback, ...)
				end
			end
		end,
	}
end

--[[
    What a dressed player's or team's IsA answers: its own class, and
    Instance, which every class is
--]]

local function isA(object: any, className: string): boolean
	return className == Dressed[object] or className == "Instance"
end

--[[
    Dresses a player who joins the mock for the Instance checks Decree makes,
    with a DisplayName, a PlayerGui, IsA and WaitForChild; a bot stays the
    plain table the mock makes it
--]]

local function dress(joined: any)
	if VoltHub.isBot(joined) then
		return
	end

	joined.DisplayName = joined.Name
	joined.PlayerGui = roblox.Instance.new("PlayerGui")
	joined.IsA = isA

	-- The one child a mock player has, so asking for another fails at once instead of waiting forever
	joined.WaitForChild = function (self: any, name: string): any
		assert(name == self.PlayerGui.Name, `A mock player holds only its PlayerGui, not {name}`)

		return self.PlayerGui
	end

	Dressed[joined] = "Player"
end

--[[
    Finds the ModuleScript a string require names, as Luau resolves one
    from a file: @self starts at the module itself, . at its parent and ..
    a level further up, and each later .. climbs one more
--]]

local function resolve(script: any, path: string): any
	local segments: { string } = path:split("/")
	local first: string = table.remove(segments, 1) :: string
	local current: any

	if first == SELF then
		current = script
	elseif first == HERE then
		current = script.Parent
	elseif first == UP then
		current = script.Parent and script.Parent.Parent
	else
		error(`{script:GetFullName()} required {path}, which starts with none of @self, ./ or ../`)
	end

	for _, segment: string in segments do
		assert(current, `{script:GetFullName()} required {path}, which climbs above the DataModel`)

		if segment == UP then
			current = current.Parent
		else
			current = current:FindFirstChild(segment)
		end
	end

	assert(current, `{script:GetFullName()} required {path}, which names no instance`)

	return current
end

--[[
    Builds one environment over a world's mock: a DataModel of its own with
    the folders in ROOTS mounted as Rojo maps them inside ServerPackages,
    Promise beside them and in ReplicatedStorage.Packages with Volt, the
    stubbed services, and the player whose client transport it runs on
--]]

local function build(given: Options, world: World, player: Player, transport: Transport): Environment
	local server: boolean = (given.side or SERVER) == SERVER
	local mock: Mock = world.mock

	local dataModel: any = roblox.Instance.new("DataModel")

	local modules: { [any]: Module } = {}
	local paths: { [string]: any } = {} -- Each mounted file's module and mounted folder, by its path from the repo root
	local globals: { [string]: any } = {
		task = task,

		-- A dressed player or team reads as an Instance, as the checks Decree makes expect
		typeof = function (value: any): string
			return Dressed[value] and "Instance" or typeof(value)
		end,
	}

	for _, name: string in DATATYPES do
		globals[name] = roblox[name]
	end

	-- The joined player with that Name, as Players finds and indexes its children
	local function named(name: string): Player?
		for _, joined: VoltMock.Player in mock.players do
			if joined.Name == name then
				return joined :: Player
			end
		end

		return nil
	end

	local playerAdded: Signal = signal()
	local playerRemoving: Signal = signal()
	local added = mock.server.playerAdded :: (callback: (player: any) -> ()) -> ()
	local removing = mock.server.playerRemoving :: (callback: (player: any) -> ()) -> ()

	-- The engine's Players never lists a bot, so its signals never fire for one
	added(function (joined: any)
		if not VoltHub.isBot(joined) then
			playerAdded:Fire(joined)
		end
	end)

	removing(function (leaving: any)
		if not VoltHub.isBot(leaving) then
			playerRemoving:Fire(leaving)
		end
	end)

	local settings: { [string]: any } = {} -- Each teleport setting by its key

	-- A teleport setting is kept by value, as the engine serializes it, so a table read back is a copy
	local function copy(value: any): any
		return type(value) == "table" and table.clone(value) or value
	end

	local actions: { [string]: Action } = {} -- Each action ContextActionService holds, by its name

	local services: { [string]: any } = {
		RunService = {
			Heartbeat = heartbeat(),

			IsServer = function (_: any): boolean
				return server
			end,

			IsClient = function (_: any): boolean
				return not server
			end,

			IsStudio = function (_: any): boolean
				return false
			end,
		},

		Players = setmetatable({
			LocalPlayer = not server and player or nil,
			PlayerAdded = playerAdded,
			PlayerRemoving = playerRemoving,
			userIds = world.userIds,

			GetPlayers = function (_: any): { any }
				return table.clone(mock.players)
			end,

			FindFirstChild = function (_: any, name: string): Player?
				return named(name)
			end,

			GetUserIdFromNameAsync = function (_: any, name: string): number
				local userId: number? = world.userIds[name]
				if not userId then
					error("Players:GetUserIdFromNameAsync() failed: Unknown user")
				end

				return userId
			end,
		}, {
			__index = function (_: any, name: string): Player?
				return named(name)
			end,
		}),

		Teams = {
			GetTeams = function (_: any): { any }
				return table.clone(world.teams)
			end,

			-- A team every environment over this mock lists, standing in for a Team a game parents to Teams
			create = function (_: any, name: string, color: any): any
				local team: { [string]: any } = {
					Name = name,
					TeamColor = color,
					IsA = isA,

					-- Every player whose Team a case set to this one
					GetPlayers = function (self: any): { any }
						local members: { any } = {}

						for _, joined: VoltMock.Player in mock.players do
							if (joined :: Player).Team == self then
								table.insert(members, joined)
							end
						end

						return members
					end,
				}

				Dressed[team] = "Team"
				table.insert(world.teams, team)

				return team
			end,
		},

		TextService = {
			-- What filtering makes of a text one user sends another, which a case may replace; Studio keeps it whole
			filter = function (text: string): string
				return text
			end,

			FilterStringAsync = function (self: any, text: string, fromUserId: number): any
				return {
					GetNonChatStringForUserAsync = function (_: any, toUserId: number): string
						return self.filter(text, fromUserId, toUserId)
					end,
				}
			end,
		},

		TeleportService = {
			GetTeleportSetting = function (_: any, key: string): any
				return copy(settings[key])
			end,

			SetTeleportSetting = function (_: any, key: string, value: any)
				settings[key] = copy(value)
			end,
		},

		HttpService = {
			JSONDecode = function (_: any, text: string): any
				return serde.decode("json", text)
			end,
		},

		ContextActionService = {
			actions = actions, -- Read by a case, which calls an action's callback in the engine's place

			BindActionAtPriority = function (
				_: any,
				name: string,
				callback: (...any) -> ...any,
				touchButton: boolean,
				priority: number,
				...: any
			)
				actions[name] =
					{ callback = callback, touchButton = touchButton, priority = priority, inputs = { ... } }
			end,

			UnbindAction = function (_: any, name: string)
				actions[name] = nil
			end,
		},

		GuiService = {
			MenuOpened = signal(),
		},

		UserInputService = {
			InputBegan = signal(),
		},

		-- The chat the window hides while it shows, each configuration enabled as a new place has it
		TextChatService = {
			ChatWindowConfiguration = { Enabled = true },
			ChatInputBarConfiguration = { Enabled = true },
			ChannelTabsConfiguration = { Enabled = false },
		},
	}

	local game = {
		GetService = function (_: any, name: string): any
			return services[name] or dataModel:GetService(name)
		end,
	}

	globals.game = game

	--[[
	    Runs a ModuleScript's file once, with script set to it and a require
	    that takes a ModuleScript or a string path from it. A ModuleScript no
	    mount made, such as a clone or another environment's, runs its Source
	--]]

	local function load(module: any): any
		if not modules[module] then
			local kind: string = typeof(module)
			assert(
				kind == "Instance" and module:IsA("ModuleScript"),
				`require was given {module}, which is no ModuleScript`
			)

			modules[module] = {
				path = module:GetFullName(),
				source = module.Source,
				loading = false,
				loaded = false,
				result = nil,
			}
		end

		local record: Module = modules[module]

		if record.loaded then
			return record.result
		end

		assert(not record.loading, `{record.path} was required while it was still loading`)
		record.loading = true

		local scope: { [string]: any } = table.clone(globals)
		scope.script = module
		scope.require = function (target: any): any
			return load(type(target) == "string" and resolve(module, target) or target)
		end

		local chunk: (...any) -> ...any =
			luau.load(record.source :: string, { debugName = record.path, environment = scope })
		local results: { n: number, [number]: any } = table.pack(chunk())
		assert(results.n == 1, `{record.path} returned {results.n} values, where a module returns exactly one`)

		record.loaded = true
		record.result = results[1]

		return results[1]
	end

	local function folder(name: string, parent: any): any
		local instance: any = roblox.Instance.new("Folder")
		instance.Name = name
		instance.Parent = parent

		return instance
	end

	local function add(name: string, parent: any, record: Module): any
		local module: any = roblox.Instance.new("ModuleScript")
		module.Name = name
		module.Parent = parent
		modules[module] = record

		return module
	end

	-- A file's ModuleScript, its Source set so a clone loads, found by the file's path without its extension
	local function addFile(name: string, parent: any, path: string): any
		local source: string = fs.readFile(path)
		local module: any = add(name, parent, {
			path = path,
			source = source,
			loading = false,
			loaded = false,
			result = nil,
		})

		module.Source = source
		paths[path:match(MODULE_FILE) :: string] = module

		return module
	end

	-- A folder is a ModuleScript when it holds an init.luau, as Rojo maps it, and is found by its path
	local function mount(name: string, parent: any, directory: string): any
		local init: string = `{directory}/{INIT}`
		local instance: any = fs.isFile(init) and addFile(name, parent, init) or folder(name, parent)
		paths[directory] = instance

		for _, entry: string in fs.readDir(directory) do
			local path: string = `{directory}/{entry}`
			local stem: string? = entry:match(MODULE_FILE)

			if fs.isDir(path) then
				mount(entry, instance, path)
			elseif stem and stem ~= "init" then
				addFile(stem, instance, path)
			end
		end

		return instance
	end

	local function find(path: string): any
		local instance: any = paths[path]
		assert(instance, `No mounted file or folder is {path}, by its path without a file's extension`)

		return instance
	end

	local replicatedStorage: any = dataModel:GetService("ReplicatedStorage")
	local packages: any = folder("Packages", replicatedStorage)
	local serverPackages: any = folder("ServerPackages", dataModel:GetService("ServerScriptService"))

	for directory: string, name: string in ROOTS do
		if fs.isDir(directory) then
			mount(name, serverPackages, directory)
		end
	end

	assert(fs.isFile(PROMISE_LINK), `{PROMISE_LINK} is missing; run wally install`)

	local installed: string?, alias: string? = fs.readFile(PROMISE_LINK):match(LINK)
	assert(installed and alias, `{PROMISE_LINK} names no installed folder; run wally install`)

	-- One Promise at both paths Decree may require it by, as a game's install links them
	local promisePath: string = `Packages/_Index/{installed}/{alias}/{PROMISE_FILE}`
	local promise: Module = {
		path = promisePath,
		source = fs.readFile(promisePath),
		loading = false,
		loaded = false,
		result = nil,
	}

	paths[PROMISE_KEY] = add("Promise", packages, promise)
	add("Promise", serverPackages, promise)

	-- What a generated module starts its runtime with: the mock's server side or the player's, by the schema's side
	add("Volt", packages, {
		path = "ReplicatedStorage.Packages.Volt",
		source = nil,
		loading = false,
		loaded = true,
		result = {
			start = function (schema: Schema): Volt.Runtime
				return Volt.start(schema, schema.side == SERVER and mock.server or transport)
			end,
		},
	})

	for _, path: string in given.files or {} do
		addFile(path:match(STEM) :: string, replicatedStorage, path)
	end

	for _, directory: string in given.folders or {} do
		assert(fs.isDir(directory), `The folder {directory} is missing`)
		mount(directory:match(FOLDER_NAME) :: string, replicatedStorage, directory)
	end

	return {
		game = game,
		mock = mock,
		player = player,
		find = find,

		require = function (target: any): any
			return load(type(target) == "string" and find(target) or target)
		end,

		-- A further client with its own modules, its LocalPlayer the player or bot the transport is for
		connect = function (connected: Transport, connectedPlayer: any): Environment
			return build(
				{ side = "client", files = given.files, folders = given.folders },
				world,
				connectedPlayer,
				connected
			)
		end,
	}
end

--[[
    Builds a fresh environment on a fresh mock, whose one joined player it
    runs on, each later one dressed the moment they join
--]]

function Environment.new(options: Options?): Environment
	local mock: Mock = Volt.mock(task.spawn)
	local added = mock.server.playerAdded :: (callback: (player: any) -> ()) -> ()

	-- The first of the server's join callbacks, so every later one, Volt's own included, meets the player dressed
	added(dress)

	local player: VoltMock.Player, client: Transport = mock:join(PLAYER)

	return build(options or {}, { mock = mock, teams = {}, userIds = {} }, player :: Player, client)
end

return Environment
