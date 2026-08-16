class_name BuildingData
extends Resource
## Здание: производит/оказывает услуги силами назначенных работников.

@export var id: String = ""
@export var building_type: Enums.BuildingType = Enums.BuildingType.FARM
@export var function_type: Enums.BuildingFunction = Enums.BuildingFunction.PRODUCTION
@export var owner_family_id: String = ""
@export var level: int = 1
@export var worker_ids: Array[String] = []

@export var input_resource: String = ""
@export var output_resource: String = ""
@export var base_production: int = 5
@export var stock: int = 0
@export var price: int = 10  ## Цена за единицу stock при продаже
