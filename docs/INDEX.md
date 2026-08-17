# INDEX — навигация по коду «Город и Династия»

> **Для агента:** читай этот файл первым для **новых фич** и неочевидных задач. Не сканируй репозиторий целиком.
> **Локальный баг** (parser error, encoding, опечатка) — файл из stack trace или последнего diff; INDEX и GAME_SPEC не читать.
> Дизайн механик — только `docs/GAME_SPEC.md` (новые фичи / баланс / архитектура).
> Слои и запреты — `.cursor/rules/godot-architecture.mdc` (always applied).

## С чего начать по типу задачи

| Задача | Читать (в порядке) | Не читать |
|--------|-------------------|-----------|
| NPC: спрос, деньги, таверна | § NPC economy ниже | `tests/`, `data/**/*.tres` |
| Пекарня / цены / склад | § Business economy | все 23 `good.tres` |
| HUD / таблица спроса | `ui/hud.gd`, `demand_aggregator.gd` | `debug_slice` |
| Визуал NPC на карте | `world/npc_view_manager.gd`, `npc_view.gd` | `npc_demand_simulator` |
| **Движение NPC / AStar** | § NPC movement ниже | `npc_demand_simulator`, весь `world/` |
| **Герой / point-and-click** | § Player movement ниже | `npc_demand_simulator` |
| **Карта / layout / слоты** | **`docs/CITY_MAP.md`**, `data/city/coastal_river_layout.txt` | `GAME_SPEC.md`, весь `world/` |
| Parser/runtime баг в карте | файл из ошибки или `world/coastal_city_map.gd` | `CITY_MAP.md`, layout, spawn pool |
| Parser/syntax error (любой) | только указанный `.gd` / `.tscn` | INDEX, GAME_SPEC, repo-wide grep |
| Сохранения | `save_manager.gd`, `game_state.gd` (to/from_dict) | `save_repro_test` |
| Голосования / законы | § Politics | `finance_history` |
| Локализация | `locale_service.gd`, `translations/game_translations.csv` | `*.translation` |
| Новая команда | один соседний `core/commands/*.gd` + `command_processor.gd` | весь `core/commands/` |
| Баг в одной функции | `Grep` → `Read` с offset/limit 30–50 строк | полный файл >150 строк |

## Runtime (main.tscn)

```
SimulationClock
    ├─ DemandSystem     → shopping 10–19, tavern 20:00, day rollover
    ├─ VotingSystem     → council votes по расписанию
    ├─ CityNavigationSystem → AStarGrid2D 40×30, без мутаций
    ├─ NPCSimulationSystem  → TickNpcMovementCommand (клетка за тик)
    └─ CharacterSimulationSystem → TickCharacterMovementCommand (герой у ратуши)

CityMap + HUD           → presentation only
CommandProcessor        → единая точка мутаций
GameState               → authoritative state
EventBus                → UI/world подписки
```

## Слои (кратко)

| Папка | Роль |
|-------|------|
| `data/` | Статика: `*_definition.gd` + `.tres` (контент, не трогать пачкой) |
| `core/data/` | Resource-состояние одной партии |
| `core/commands/` | validate → mutate GameState → EventBus |
| `core/simulation/` | Чистая логика, без мутаций |
| `core/systems/` | Подписка на `SimulationClock` / post-load |
| `autoloads/` | Синглтоны |
| `world/`, `ui/` | Только отображение, без своего state |

## Autoloads (9)

| Имя | Файл | Когда открывать |
|-----|------|-----------------|
| DataRegistry | `autoloads/data_registry.gd` | id товара/архетипа, имена для UI |
| GameState | `autoloads/game_state.gd` | businesses, npcs, characters, seed, save |
| SimulationClock | `autoloads/simulation_clock.gd` | время, пауза, скорость |
| CommandProcessor | `autoloads/command_processor.gd` | вызов команд |
| EventBus | `autoloads/event_bus.gd` | какие сигналы есть |
| FinanceHistory | `autoloads/finance_history.gd` | графики/история денег бизнеса |
| PoliticsHistory | `autoloads/politics_history.gd` | история голосований |
| SaveManager | `autoloads/save_manager.gd` | save/load JSON |
| LocaleService | `autoloads/locale_service.gd` | `trf()`, смена языка |

---

## NPC economy

**Дневной цикл**

```
00:00  ApplyNpcDailyIncomeCommand     → cash = npc_income_per_day (сброс, не +)
00:00  NPC возвращаются домой и исчезают (сон)
06:00  NPC выходят из домов
10–19  DemandSystem (каждый час)      → NpcShoppingScheduler → SimulateDailyDemandCommand
20:00  SimulateTavernSpendingCommand  → пропить остаток до 0
```

| Шаг | Файл |
|-----|------|
| Состояние NPC | `core/data/npc_state.gd` (`cash`, `demand_goods`, `home_slot_id`, `AT_HOME`) |
| Событие покупки | `core/data/npc_purchase_event.gd` |
| Спавн | `core/simulation/npc_spawner.gd` |
| Профиль 3×10 товаров | `core/simulation/npc_demand_profile_generator.gd` |
| Час похода 10–19 | `core/simulation/npc_shopping_scheduler.gd` |
| Симуляция покупок | `core/simulation/npc_demand_simulator.gd` |
| Фасад | `core/simulation/demand_simulator.gd` |
| Агрегат для HUD | `core/simulation/demand_aggregator.gd` |
| Команда покупок | `core/commands/simulate_daily_demand_command.gd` |
| Таверна (сим) | `core/simulation/npc_tavern_simulator.gd` |
| Таверна (команда) | `core/commands/simulate_tavern_spending_command.gd` |
| Сброс бюджета | `core/commands/apply_npc_daily_income_command.gd` |
| Оркестратор | `core/systems/demand_system.gd` |
| Сценарий (cash, часы) | `data/scenarios/scenario_definition.gd`, `default_scenario.tres` |
| Визит на карте | `world/npc_view_manager.gd` → сигнал `npc_shopping_visit` |
| Сигналы | `autoloads/event_bus.gd` (`npc_*`) |

**Bootstrap таверны:** `game_state.gd` → `_register_tavern()` (ale 200, wine 100).

---

## NPC movement

Логика на тике `SimulationClock.tick_elapsed`, визуал в `_process`.

```
CityNavigationSystem (AStar) → NPCSimulationSystem → TickNpcMovementCommand
     → NpcState.current_cell / path_cells
     дневные цели: двери цехов + парк (4 часа от края к краю)
NpcView._process → move_toward(cell_to_world(current_cell))
```

| Роль | Файл |
|------|------|
| Клетка, путь, `AT_HOME` / `IDLE_WANDER` / `MOVING_TO_GOAL` / `RETURNING_HOME` / `STROLLING_PARK` | `core/data/npc_state.gd` |
| AStar 40×30, вес дорог/парка 1.0 / полей 10.0, `get_door_node`, дома, двери цехов, парк | `core/systems/city_navigation_system.gd` |
| Спавн в доме, выход 6:00, дневные цели (цеха + парк 4ч), возврат 00:00 | `core/systems/npc_simulation_system.gd` |
| Мутация | `core/commands/tick_npc_movement_command.gd` |
| Footprint зданий для solid | `core/simulation/city_layout_parser.gd` (`footprint_rect`) |
| Интерполяция | `world/npc_view.gd` (`CharacterBody2D`) |
| Спавн view | `world/npc_view_manager.gd` |
| `cell_to_world` | `world/coastal_city_map.gd` |
| Коллизии тайлов | `world/city_placeholder_tileset.gd`, слой `obstacle_layer` |

---

## Player movement

Спавн у ратуши, клик по карте → команда → шаг клетки на тике → интерполяция в view.

```
ПКМ CoastalCityMap → MoveCharacterCommand (AStar path)
CharacterSimulationSystem → TickCharacterMovementCommand
     → CharacterState.current_cell / path_cells
PlayerView._process → move_toward(cell_to_world(current_cell)) × speed_multiplier
```

| Роль | Файл |
|------|------|
| Состояние героя (`current_cell`, `path_cells`) | `core/data/character_state.gd` |
| Словарь персонажей, `DEFAULT_CHARACTER_ID` | `autoloads/game_state.gd` |
| Спавн: соседние `#` вокруг footprint `H` | `city_layout_parser.gd` (`find_town_hall_*`), `city_navigation_system.gd` (`pick_town_hall_spawn_cell`) |
| Клик → путь | `core/commands/move_character_command.gd` |
| Шаг клетки | `core/commands/tick_character_movement_command.gd` |
| Оркестратор тика | `core/systems/character_simulation_system.gd` |
| ПКМ, `world_to_cell` / `local_to_map`, дверь здания | `world/coastal_city_map.gd` |
| Интерполяция | `world/player_view.gd` (`CharacterBody2D`) |

---

## Business economy

| Роль | Файл |
|------|------|
| Состояние | `core/data/business_state.gd` |
| Чистая логика | `core/simulation/business_economy.gd` |
| Закупка | `core/commands/buy_resource_command.gd` |
| Цена / уровень | `set_price_command.gd`, `set_price_level_command.gd` |
| Дневные расходы | `apply_daily_costs_command.gd` |
| Финансы дня | `record_daily_finance_command.gd`, `reset_daily_stats_command.gd` |
| Типы зданий | `data/businesses/business_type_definition.gd` |
| Товары (схема) | `data/goods/good_definition.gd`, `goods_catalog.csv` |
| Формула цены 0–10 | `data/demand/demand_formula.gd` |
| Репутация → спрос | `data/reputation/reputation_formula.gd` |

---

## Save / load

| Роль | Файл |
|------|------|
| Файл на диске | `autoloads/save_manager.gd` (`SAVE_FORMAT_VERSION`) |
| Сериализация мира | `autoloads/game_state.gd` (`SAVE_VERSION`, to/from_dict) |
| Время | `autoloads/simulation_clock.gd` |
| Финансы | `autoloads/finance_history.gd` |
| Post-load | `demand_system.reset_after_load`, `EventBus.game_loaded` |

---

## Politics

| Роль | Файл |
|------|------|
| Оркестратор | `core/systems/voting_system.gd` |
| Голосование | `core/commands/run_council_vote_command.gd` |
| Агитация | `campaign_for_law_command.gd` |
| Истечение законов | `expire_laws_command.gd` |
| Симуляция | `core/simulation/vote_simulator.gd`, `law_effects.gd` |
| UI debug | `ui/finance_debug.gd` |

---

## UI

| Экран | Файлы | Примечание |
|-------|-------|------------|
| Основной HUD | `ui/hud.gd`, `hud.tscn` | ~250 строк — читать по секциям |
| Debug slice | `ui/debug_slice.gd` | save, locale, ручной demand |
| Finance debug | `ui/finance_debug.gd` | политика + финансы |

**HUD секции (hud.gd):** `_refresh_demand_table`, `_refresh_business_panel`, `_populate_goods_catalog` — независимы.

---

## World / visuals

| Роль | Файл |
|------|------|
| Точка входа | `world/main.tscn` → `coastal_city_map.tscn` |
| **Спека карты (читать первой)** | **`docs/CITY_MAP.md`** |
| ASCII-карта (40×30, top-down) | `data/city/coastal_river_layout.txt` |
| Генератор черновика | `tools/generate_coastal_layout.py` |
| Каталог зданий | `data/city/production_buildings.tres` |
| Assigner | `core/simulation/city_layout_assigner.gd` (минимумы, затем random) |
| Парсер | `core/simulation/city_layout_parser.gd` (river/sea flood-fill) |
| Сборка слоёв | `world/city_layout_builder.gd`, `coastal_city_map.gd` |
| Слоты | `world/city_slot_marker.gd` |
| Tileset-заглушки | `world/city_placeholder_tileset.gd` (физика воды/леса/footprint) |
| Здания на слотах | `world/placed_building_view.gd` (`StaticBody2D`) |
| NPC views | `world/npc_view_manager.gd`, `npc_view.gd` (интерполяция к `current_cell`) |
| Герой | `world/player_view.gd` (интерполяция к `CharacterState.current_cell`) |

---

## Локализация

- Редактировать: `translations/game_translations.csv`
- Сервис: `autoloads/locale_service.gd`
- Не читать: `*.translation` (скомпилировано Godot)

---

## Не читать без явной причины

```
tests/**              — repro-тесты, не прод-поток
**/*.tres             — читай *_definition.gd + один пример
**/*.translation      — бинарные переводы
**/*.uid, .godot/**   — метаданные редактора
tools/*.py            — миграции
data/goods/*.tres     — 23 файла; имена через DataRegistry
```

---

## Крупнейшие файлы (осторожно с полным чтением)

| Строк | Файл | Что внутри |
|------:|------|------------|
| ~312 | `data_registry.gd` | загрузка + валидация + i18n-хелперы |
| ~250 | `hud.gd` | 3 независимые панели |
| ~220 | `finance_history.gd` | listeners + serialize |
| ~218 | `debug_slice.gd` | много debug-кнопок |
| ~305 | `game_state.gd` | state + seed + serialize + tavern + characters |

---

## Рекомендации по разбиению (экономия токенов в будущем)

Приоритет **высокий** — вынести, когда трогаешь файл повторно:

| Новый файл | Откуда вынести | Зачем |
|------------|----------------|-------|
| `core/bootstrap/game_state_seeder.gd` | `game_state._seed_demo`, `_register_tavern`, `_ensure_npc_demand_profiles` | GameState ≈100 строк вместо ~200 |
| `core/serialization/game_state_serializer.gd` | `game_state.to_dict/from_dict` | save-задачи не тянут seed |
| `core/commands/npc_purchase_applier.gd` | `apply_sales_to_business`, `apply_npc_purchase_events` из `simulate_daily_demand_command.gd` | tavern+demand в одном месте |
| `autoloads/data_registry_validator.gd` | `data_registry._validate_references` | загрузка отдельно от валидации |

Приоритет **средний**:

| Новый файл | Откуда |
|------------|--------|
| `ui/hud_demand_panel.gd` | `_refresh_demand_table` + nodes из hud |
| `ui/hud_business_panel.gd` | `_refresh_business_panel`, slider, buy flour |
| `ui/price_level_formatter.gd` | дубль в `hud.gd` и `debug_slice.gd` |

**Не дробить сейчас:** simulators ~120–170 строк, `demand_system.gd` (~95), отдельные команды — уже нормальный размер.

---

## Дисциплина чтения (для агента)

1. `Grep` по символу → `Read` 30–80 строк вокруг совпадения.
2. Один `.tres` как образец, схема — в `.gd` definition.
3. Тесты — только если пользователь просит или ломается CI.
4. `--import` — только новый `class_name` или смена autoload.
5. `GAME_SPEC.md` — новая механика; INDEX — навигация; architecture — слои.

---

## Версии save

- `GameState.SAVE_VERSION` и `SaveManager.SAVE_FORMAT_VERSION` — держать в синхроне (сейчас **9**).
