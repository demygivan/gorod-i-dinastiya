class_name LawDefinition
extends Resource
## Статическое определение закона. Экземпляры — data/laws/*.tres.


const EFFECT_TAX_REDUCTION := "tax_reduction"
const DURATION_PERMANENT := 0

@export var id: String = ""
@export var name_key: String = ""
@export var effect_type: String = EFFECT_TAX_REDUCTION
@export var effect_value: float = 0.05
## 0 = навсегда; >0 = активен N игровых дней с момента принятия.
@export var duration_days: int = 0
