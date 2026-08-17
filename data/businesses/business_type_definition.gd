class_name BusinessTypeDefinition
extends Resource
## Статическое определение типа предприятия. Экземпляры — data/businesses/*.tres.

@export var id: String = ""
@export var name_key: String = ""
@export var allowed_goods: Array[String] = []
@export var base_daily_cost: float = 0.0
@export var storage_capacity: int = 100
