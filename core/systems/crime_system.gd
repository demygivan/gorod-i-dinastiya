class_name CrimeSystem
extends RefCounted
## Логика кражи/ареста. Формулы — черновые, подбирай баланс через плейтесты.

const JAIL_DAYS_DEFAULT := 5
const REPUTATION_PENALTY := 15


static func attempt_theft(thief: CharacterData, target: CharacterData) -> bool:
	var safety_penalty: float = GameState.city.safety * 0.1
	var success_chance: float = float(thief.skills.stealth - target.skills.intelligence) - safety_penalty
	var roll: float = randf_range(-20.0, 20.0)

	var success: bool = roll < success_chance
	EventBus.theft_attempted.emit(thief.id, target.id, success)

	if not success:
		_arrest(thief)
	return success


static func _arrest(character: CharacterData) -> void:
	character.is_in_jail = true
	character.is_criminal = true
	character.jail_days_left = JAIL_DAYS_DEFAULT
	character.reputation = max(0, character.reputation - REPUTATION_PENALTY)
	EventBus.character_arrested.emit(character.id)


## Спецспособность Rogue "Выйти из тюрьмы" — тратит деньги/репутацию семьи.
static func bribe_out(character: CharacterData, family: FamilyData, bribe_cost: int) -> bool:
	if not character.is_in_jail:
		return false
	if family.treasury < bribe_cost:
		return false

	family.treasury -= bribe_cost
	character.is_in_jail = false
	character.jail_days_left = 0
	EventBus.character_released.emit(character.id)
	return true


## Вызывать при GameClock.day_passed для всех, кто сидит в тюрьме.
static func tick_jail(character: CharacterData) -> void:
	if not character.is_in_jail:
		return
	character.jail_days_left -= 1
	if character.jail_days_left <= 0:
		character.is_in_jail = false
		EventBus.character_released.emit(character.id)
