option clientOutput = "../../.volt/Smoke/Client.luau"
option serverOutput = "../../.volt/Smoke/Server.luau"
option yield = promise
option promise = "ReplicatedStorage.Packages.Promise"

-- One call a client makes and the server answers, compiled by the case that runs it
namespace Smoke {
	function echo {
		data: (text: string(1..64)),
		return: (text: string(0..64)),
	}
}
