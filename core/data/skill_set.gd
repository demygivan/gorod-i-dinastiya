class_name SkillSet
extends Resource
## Навыки персонажа. Диапазон -20..20: отрицательные значения — слабость/порок,
## а не просто "0 = нет навыка".

@export_range(-20, 20) var constitution: int = 0
@export_range(-20, 20) var agility: int = 0
@export_range(-20, 20) var intelligence: int = 0
@export_range(-20, 20) var charisma: int = 0
@export_range(-20, 20) var stealth: int = 0
@export_range(-20, 20) var strength: int = 0
@export_range(-20, 20) var craftsmanship: int = 0
