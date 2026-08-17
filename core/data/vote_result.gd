class_name VoteResult
extends RefCounted
## Snapshot результата голосования совета.


var day: int = 0
var law_id: String = ""
var votes_for: int = 0
var votes_against: int = 0
var passed: bool = false
var npc_votes: Dictionary = {}  ## npc_id -> bool (true = за)


func get_summary() -> String:
	return LocaleService.trf("msg.politics.vote_summary", {
		"for": votes_for,
		"against": votes_against,
		"result": LocaleService.trf("msg.politics.passed" if passed else "msg.politics.rejected"),
	})


func to_dict() -> Dictionary:
	return {
		"day": day,
		"law_id": law_id,
		"votes_for": votes_for,
		"votes_against": votes_against,
		"passed": passed,
		"npc_votes": npc_votes.duplicate(),
	}


static func from_dict(data: Dictionary) -> VoteResult:
	if data.is_empty():
		return null

	var result := VoteResult.new()
	result.day = int(data.get("day", 0))
	result.law_id = str(data.get("law_id", ""))
	result.votes_for = int(data.get("votes_for", 0))
	result.votes_against = int(data.get("votes_against", 0))
	result.passed = bool(data.get("passed", false))
	result.npc_votes = data.get("npc_votes", {}).duplicate()
	return result
