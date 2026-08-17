class_name GoodDefinition
extends Resource
## Статическое определение товара. Экземпляры живут в data/goods/*.tres.

@export var id: String = ""
@export var name_key: String = ""
@export var base_price: float = 1.0
@export var category: String = "food"
@export var max_stack: int = 100
## Что нужно, чтобы сделать ЭТОТ товар. Несколько id = несколько ингредиентов.
## Пустой массив = первичное сырьё / сбор / урожай (из него ничего не «требуется»).
## Обратная сторона (из зерна → мука, эль, вино) считается в DataRegistry.
@export var input_ids: Array[String] = []


func is_primary() -> bool:
	return input_ids.is_empty()
