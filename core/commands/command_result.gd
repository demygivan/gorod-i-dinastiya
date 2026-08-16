class_name CommandResult
extends RefCounted
## Результат выполнения команды. Любая команда возвращает это,
## а не bool — чтобы UI мог показать причину отказа игроку.

var success: bool
var error: String


func _init(p_success: bool, p_error: String = "") -> void:
	success = p_success
	error = p_error


static func ok() -> CommandResult:
	return CommandResult.new(true)


static func fail(reason: String) -> CommandResult:
	return CommandResult.new(false, reason)
