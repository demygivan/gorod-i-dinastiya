@tool
class_name BuildingSpawnEntry
extends Resource
## Одна строка пула застройки: что может появиться на слоте данного типа.


@export var id: String = ""
@export var name_key: String = ""
@export var profession: String = ""
## Patron / Craftsman / Scholar / Rogue / Infrastructure
@export var group: String = ""
## Какие slot_kind из CityLayoutParser подходят: residential, commercial, maritime, cemetery.
@export var slot_kinds: Array[String] = []
## Относительный вес (в таблице — Probability). Среди подходящих записей.
@export var weight: float = 10.0
## Сколько зданий этого типа гарантированно поставить до случайного заполнения.
@export var minimum_quantity: int = 0
## Если не пусто — слот может стать BusinessState этого типа.
@export var business_type_id: String = ""


func matches_slot_kind(slot_kind: String) -> bool:
	return slot_kind in slot_kinds


func get_category() -> String:
	if "residential" in slot_kinds and slot_kinds.size() == 1:
		return "house"
	if "cemetery" in slot_kinds or id == "town_hall":
		return "civic"
	return "production"


func get_display_name() -> String:
	if name_key.is_empty():
		return id
	return LocaleService.trf(name_key)
