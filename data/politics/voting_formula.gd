class_name VotingFormula
extends Resource
## Параметры детерминированного голосования совета.


@export var id: String = ""
@export var base_yes_score: float = 0.5
@export var alignment_weight: float = 0.2
@export var relationship_weight: float = 0.25
@export var self_interest_weight: float = 0.15
@export var relationship_self_interest_min: float = 55.0
@export var campaign_bonus_per_shift: float = 0.12
@export var max_campaign_bonus: float = 0.24
@export var pass_threshold: float = 0.5
