class_name CharacterData
extends Resource
## Данные одного персонажа династии. Это "модель" — сама по себе она ничего
## не рисует на экране, за визуал отвечают сцены в /world.

@export var id: String = ""
@export var character_name: String = ""
@export var family_id: String = ""
@export var age: int = 18
@export var is_alive: bool = true
@export var profession: Enums.Profession = Enums.Profession.CRAFTSMAN
@export var skills: SkillSet = SkillSet.new()

@export var hp: int = 100
@export var level: int = 0
@export var experience: int = 0
@export var speed: int = 5
@export var reputation: int = 50
@export var money: int = 0

@export var is_criminal: bool = false
@export var is_homeless: bool = false
@export var is_in_jail: bool = false
@export var jail_days_left: int = 0

@export var job_building_id: String = ""
@export var spouse_id: String = ""
@export var children_ids: Array[String] = []
