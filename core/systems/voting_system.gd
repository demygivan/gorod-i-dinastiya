extends Node
## Периодическое голосование совета и истечение срока законов.


func _ready() -> void:
	SimulationClock.day_changed.connect(_on_day_changed)


func _on_day_changed(new_day: int) -> void:
	CommandProcessor.execute(ExpireLawsCommand.execute, [new_day])

	if not _should_run_vote(new_day):
		return

	CommandProcessor.execute(
		RunCouncilVoteCommand.execute,
		[GameState.proposed_law_id, new_day],
	)


func _should_run_vote(day: int) -> bool:
	if GameState.proposed_law_id.is_empty():
		return false
	if day < GameState.council_first_vote_day:
		return false
	if day <= GameState.last_vote_day:
		return false
	var offset := day - GameState.council_first_vote_day
	return offset % GameState.council_vote_interval_days == 0
