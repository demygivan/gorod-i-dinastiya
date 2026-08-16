class_name FamilyData
extends Resource
## Династия: список членов, общая казна и владения.

@export var id: String = ""
@export var family_name: String = ""
@export var member_ids: Array[String] = []
@export var treasury: int = 0
@export var reputation: int = 50
@export var owned_building_ids: Array[String] = []
