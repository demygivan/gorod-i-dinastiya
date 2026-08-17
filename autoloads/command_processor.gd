extends Node
## Единая точка входа для игровых команд.


func execute(command: Callable, args: Array = [], log_success: bool = true) -> CommandResult:
	if not command.is_valid():
		var invalid := CommandResult.fail("Некорректная команда")
		_log_result(invalid, command)
		return invalid

	var result: Variant = command.callv(args)
	if result == null or not result is CommandResult:
		var null_result := CommandResult.fail("Команда не вернула CommandResult")
		_log_result(null_result, command)
		return null_result

	_log_result(result, command, log_success)
	return result


func _log_result(result: CommandResult, command: Callable, log_success: bool = true) -> void:
	var command_name := _describe_callable(command)
	if result.success:
		if log_success:
			print("[CommandProcessor] OK: %s" % command_name)
		return
	push_warning("[CommandProcessor] FAIL: %s — %s" % [command_name, result.error])


func _describe_callable(command: Callable) -> String:
	if command.get_object() != null and command.get_method() != &"":
		return "%s.%s" % [command.get_object(), String(command.get_method())]
	return "<command>"
