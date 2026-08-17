class_name NpcArchetypeDefinition
extends Resource
## Статический архетип NPC. Экземпляры — data/npc_archetypes/*.tres.


@export var archetype_id: String = ""
@export var name_key: String = ""
@export var income_per_day: float = 10.0
@export var price_sensitivity: float = 1.0
@export var preferred_goods: Array[String] = []
@export var political_alignment: float = 0.0
