class_name SaveResult
extends RefCounted
## Результат save/load операции.


var success: bool
var error: String


func _init(p_success: bool, p_error: String = "") -> void:
	success = p_success
	error = p_error


static func ok() -> SaveResult:
	return SaveResult.new(true)


static func fail(reason: String) -> SaveResult:
	return SaveResult.new(false, reason)
