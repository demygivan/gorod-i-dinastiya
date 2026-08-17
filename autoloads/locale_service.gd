extends Node
## Выбор локали: OS locale → доступный столбец CSV → fallback en.


const FALLBACK_LOCALE := "en"
const TRANSLATIONS_DIR := "res://translations"
const TRANSLATIONS_PREFIX := "game_translations."


func _ready() -> void:
	TranslationServer.set_locale(detect_best_locale())


func detect_best_locale() -> String:
	var available := get_available_locales()
	if available.is_empty():
		return FALLBACK_LOCALE

	var os_locale := OS.get_locale().to_lower()
	var candidates: PackedStringArray = [os_locale]
	if os_locale.contains("_"):
		candidates.append(os_locale.split("_")[0])
	if os_locale.contains("-"):
		candidates.append(os_locale.split("-")[0])

	for candidate in candidates:
		if available.has(candidate):
			return candidate

	return FALLBACK_LOCALE


func get_available_locales() -> PackedStringArray:
	var locales := PackedStringArray()
	var dir := DirAccess.open(TRANSLATIONS_DIR)
	if dir == null:
		return locales

	for file_name in dir.get_files():
		if not file_name.ends_with(".translation"):
			continue
		if not file_name.begins_with("game_translations."):
			continue
		var locale_code := file_name.trim_prefix("game_translations.").trim_suffix(".translation")
		if not locale_code.is_empty():
			locales.append(locale_code)

	locales.sort()
	return locales


func set_locale(locale_code: String) -> void:
	var normalized := locale_code.strip_edges().to_lower()
	var available := get_available_locales()
	if not available.has(normalized):
		push_warning("LocaleService: locale \"%s\" not available, using %s" % [normalized, FALLBACK_LOCALE])
		normalized = FALLBACK_LOCALE

	if TranslationServer.get_locale() == normalized:
		return

	TranslationServer.set_locale(normalized)
	EventBus.locale_changed.emit(normalized)


func trf(key: String, args: Dictionary = {}) -> String:
	var text := tr(key)
	if args.is_empty():
		return text
	return text.format(args)
