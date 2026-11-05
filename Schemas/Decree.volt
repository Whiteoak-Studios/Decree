option clientOutput = "../src/DecreeClient/Network.luau"
option serverOutput = "../src/Network.luau"
option typesOutput = "../src/DecreeClient/Shared/Wire.luau"
option runtime = "ReplicatedStorage.Packages.Volt"
option scope = Decree
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"

-- Decree's wire contract: a typed line and its reply, the caller's command list, and the lines and lists the server pushes
namespace Decree {
	enum Kind { Info, Ok, Refused, Error }

	struct Argument {
		name: string(1..64),
		type: string(1..256),
		description: string(0..512),
		optional: boolean,
	}

	struct Subcommand {
		name: string(1..64),
		description: string(0..1024),
		args: Argument[0..32],
	}

	struct Command {
		name: string(1..64),
		aliases: string(1..64)[0..16],
		description: string(0..1024),
		group: string(1..64)?,
		system: string(1..64)?,
		tags: string(1..64)[0..16],
		args: Argument[0..32],
		autoExec: string(1..4096)[0..16],
		subcommands: Subcommand[0..16],
		device: boolean,
	}

	type Commands = Command[0..512]

	-- The rates cover only the time before the server's start, which applies the game's own
	function run {
		timeout: 10,
		rate: 10,
		data: (text: string.utf8(1..4096)),
		return: (text: string.utf8(0..16384), kind: Kind),
	}

	function commands {
		timeout: 10,
		rate: 1,
		return: Commands,
	}

	event line {
		from: Server,
		type: Reliable,
		call: SingleSync,
		data: (text: string.utf8(0..16384), kind: Kind),
	}

	event access {
		from: Server,
		type: Reliable,
		call: SingleSync,
		data: Commands,
	}
}
