# GAME_SPEC.md — Город и Династия

> **Это единый живой файл проекта.** Ты дорабатываешь его сам по мере
> продумывания механик, а затем даёшь целиком Cursor (перетащи в чат /
> `@docs/GAME_SPEC.md`), чтобы он понимал суть игры и архитектурные
> ограничения. Разделы 8–9 — не геймдизайн, а инженерный контракт: их лучше
> не трогать без явного решения, остальное — свободно редактируй.

---

## 0. Статус документа

| | |
|---|---|
| Движок | Godot 4.7, GDScript |
| Жанр | 2D сити-симулятор, вдохновение — The Guild 2 |
| Игрок управляет | Династией (несколько персонажей одной семьи одновременно) |
| Темп игры | Реальное время с паузой (как Guild 2 / The Sims) |
| Текущий режим | **Строго single-player** |
| Цель на будущее | Опциональный host-client кооп на 2–4 игрока в одном городе. Не MMO, не persistent online-world |

---

## 1. Концепция

Небольшой город, где живут NPC и играбельные персонажи династии. У персонажей
есть навыки и профессия, они работают на зданиях, здания производят
товары/услуги, город в целом имеет параметры (безопасность, коррупция,
дискриминация, демократия), которые реагируют на действия игрока.

---

## 2. Персонажи

### 2.1 Навыки (диапазон **-20 до 20**, отрицательные = порок/слабость)

| Навык | Пассивный эффект | Действие | Ключевая профессия |
|---|---|---|---|
| Телосложение | HP, выносливость | — | Craftsman, Rogue (силовой грабёж) |
| Ловкость | Скорость, взлом | Ограбить здание | Rogue, Craftsman (портной) |
| Интеллект | Качество лечения/учёбы | Обнаружить вора | Scholar |
| Харизма | Отношения, торговля | Улучшить отношения / обмануть | Patron |
| Скрытность | Шанс не спалиться | Избежать обнаружения | Rogue |
| Сила | Урон, задержание | Арестовать | Rogue, стража |
| Ремесло | Качество/скорость производства | Крафт | Craftsman |

### 2.2 Прогресс-параметры

| Параметр | Диапазон | Смысл |
|---|---|---|
| HP | 0–100 | При 0 — персонаж выбывает (болен/госпитализирован) |
| Опыт / Уровень | накопительно / 0–10 | Открывает доступ к сложным зданиям и должностям |
| Скорость | 0–10 | Производная от Ловкости |
| Репутация | 0–100 | Цены, доверие NPC, доступ к политике |
| Деньги | накопительно | Личный капитал |
| Флаги | bool | Преступник / Бездомный / В тюрьме |

---

## 3. Профессии

| Класс | Ключевые навыки | Геймплей | Спецспособности |
|---|---|---|---|
| **Patron** | Харизма | Политика, торговля, выборы, влияние на Демократию/Коррупцию | Улучшить отношения, лоббирование законов |
| **Craftsman** | Ремесло, Телосложение | Работает/владеет производственными зданиями, строит цепочки | Уникальные предметы (напр. "мега-броня"), бонус к урожаю |
| **Scholar** | Интеллект | Hospital (лечение), Религия (вера/культ), исследования | Неуязвимость (временный иммунитет), Создание культа |
| **Rogue** | Скрытность, Ловкость, Сила | Кражи, взломы, риск ареста | Выйти из тюрьмы (по связям/взятке) |

---

## 4. Династия и семья

- **Family** — контейнер: живые члены, казна, репутация, владения (здания).
- **Брак** — с NPC города или с персонажем другой династии игрока.
- **Дети** — растут по годам (ребёнок → подросток → взрослый), до
  совершеннолетия не управляются напрямую.
- **Старость/смерть** — риск смерти растёт с возрастом; при смерти —
  наследование (деньги, здания, часть репутации).

---

## 5. Здания и экономика

| Здание | Функция | Навык | Вход | Выход |
|---|---|---|---|---|
| Farm | Производство | Ремесло + Телосложение | — | Зерно |
| Bakery | Производство | Ремесло | Зерно | Хлеб |
| Mine | Производство | Телосложение | — | Руда |
| Smithery | Производство | Ремесло | Руда | Оружие/броня |
| Пошив одежды | Производство | Ремесло + Ловкость | Ткань | Одежда |
| Tavern | Услуги | Харизма | Хлеб/эль | Отдых, найм Rogue |
| Hospital | Услуги | Интеллект | — | Лечение |
| Религиозное здание | Услуги | Харизма + Интеллект | — | Репутация, "вера" |

Три типа функций: **Производство** (Ремесло+Телосложение), **Услуги**
(Харизма+Интеллект), **Действия** (Ловкость+Скрытность — криминал/скрытые операции).

### 5.1 Каталог товаров (в духе The Guild 2)

Определения — **data-driven**: один `.tres` на товар в `data/goods/`, загрузка
через автозагрузку `DataRegistry`. В коде товары НЕ хардкодятся. Склада и
производства пока нет: только справочник, базовые цены и торговля через
`BusinessState.prices`.

Рецепты — ориентированный граф, не дерево:
- у товара может быть **несколько входов** (`input_ids`: доспех ← железо + кожа);
- из **одного** товара могут делаться **несколько** других (зерно → мука, эль);
- обратная сторона не дублируется в `.tres`, её считает `DataRegistry.get_goods_made_from()`.
- пустой `input_ids` = первичное сырьё / урожай / сбор (сырью сырьё не нужно).

| id | Название | Категория | База | Вход | Из него делают |
|---|---|---|---|---|---|
| grain | Зерно | raw | 3 | — | flour, ale |
| wool | Шерсть | raw | 8 | — | cloth |
| grapes | Виноград | raw | 7 | — | wine |
| vegetables | Овощи | food | 6 | — | — |
| meat | Мясо | food | 14 | — | leather |
| fish | Рыба | food | 12 | — | — |
| spices | Специи | food | 25 | — | — |
| herbs | Травы | raw | 9 | — | medicine |
| ore | Руда | raw | 8 | — | iron |
| coal | Уголь | raw | 7 | — | iron |
| wood | Древесина | raw | 4 | — | tools |
| flour | Мука | material | 6 | grain | bread |
| iron | Железо | material | 15 | ore, coal | tools, weapon, armor |
| cloth | Ткань | material | 12 | wool | clothing |
| leather | Кожа | material | 10 | meat | armor |
| bread | Хлеб | food | 10 | flour | — |
| ale | Эль | drink | 5 | grain | — |
| wine | Вино | drink | 18 | grapes | — |
| clothing | Одежда | craft | 20 | cloth | — |
| tools | Инструменты | craft | 22 | iron, wood | — |
| weapon | Оружие | equipment | 35 | iron | — |
| armor | Доспех | equipment | 45 | iron, leather | — |
| medicine | Лекарство | medicine | 28 | herbs | — |

### 5.2 Типы предприятий

`data/businesses/*.tres` (`BusinessTypeDefinition`): какие товары разрешено
продавать, дневные издержки, ёмкость склада.

| id | Название | Разрешённые товары | Издержки/день | Склад |
|---|---|---|---|---|
| bakery | Пекарня | bread, flour | 12 | 200 |
| mill | Мельница | flour, grain | 10 | 250 |
| farm | Ферма | grain, vegetables, meat, wool, grapes | 10 | 300 |
| tavern | Таверна | ale, wine, bread, meat | 18 | 150 |
| mine | Шахта | ore, coal | 20 | 250 |
| smithery | Кузница | weapon, armor, tools, iron | 25 | 150 |
| tailor | Портной | cloth, clothing, leather | 14 | 150 |

### 5.3 Сценарии

`data/scenarios/*.tres` (`ScenarioDefinition`): стартовые деньги, стартовый тип
предприятия, стартовые товары. Пока не применяются симуляцией — только данные.

| id | Старт. деньги | Старт. предприятие | Старт. товары |
|---|---|---|---|
| default_scenario | 500 | bakery | flour, bread |

Локализация названий — `data/locale/strings.csv` по ключам `name_key`
(`GOOD_*`, `BUSINESS_*`, `CATEGORY_*`, `SCENARIO_*`).

---

## 6. Криминал и правопорядок

```
шанс_успеха_кражи = (Скрытность_вора - Интеллект_жертвы) - Безопасность_города * 0.1 + случайный_разброс(-20..20)
провал → арест: is_in_jail=true, is_criminal=true, jail_days_left=5, -15 репутации
```

Выход из тюрьмы: отсидеть срок, или спецспособность Rogue "Выйти из тюрьмы"
(деньги/репутация семьи).

---

## 7. Городские параметры

| Параметр | Диапазон |
|---|---|
| Безопасность, Дискриминация, Коррупция, Демократия, Безработица | 0–100 |
| Население | число |

```
уровень_преступности = clamp(0,100, (100-Безопасность)*0.4 + Коррупция*0.3 + Дискриминация*0.2 + Безработица*0.1)
Преступники = Население * уровень_преступности / 100
```

---

## 8. Архитектура (Godot)

Три слоя, не смешивать:

```
core/data/      → ЧТО есть (состояние)      — Resource-классы
core/commands/  → ЧТО можно изменить        — валидация + мутация + событие
core/systems/   → ЧТО происходит само       — периодическая логика (тик/день/сезон)
world/, ui/     → КАК это выглядит          — сцены/ноды Godot, только чтение
```

Автозагрузки: `GameClock` (время), `GameState` (единое хранилище —
authoritative state), `EventBus` (события для UI и между системами).

---

## 9. Контракт готовности к мультиплееру

*(Раздел зафиксирован осознанно — не размывать ради удобства, пока нет
отдельного подтверждённого multiplayer-ТЗ.)*

### 9.1 Статус
Игра сейчас — строго single-player. Цель следующего этапа (не сейчас):
опциональный host-client кооп 2–4 игрока в одном городе. Не MMO, не
persistent online-world.

### 9.2 Запрещено делать до отдельного подтверждённого ТЗ
- Создавать `NetworkManager`, `LobbyManager`, использовать
  `MultiplayerPeer`/`MultiplayerSpawner`/`MultiplayerSynchronizer`, RPC.
- Подключать сетевые плагины или внешние backend-сервисы.
- Писать host/join UI.
- Добавлять фоновую "серверную" симуляцию.
- Усложнять UX ради гипотетического будущего мультиплеера.

### 9.3 Обязательные паттерны single-player архитектуры (готовят почву под кооп)
- UI, визуальные сцены и анимации — **не источник состояния**, только
  отображение `GameState` по id.
- Authoritative state — только в `core/data/` через `GameState`.
- **Любое** изменение мира — только через команды из `core/commands/`
  (`HireWorkerCommand`, `SetBuildingPriceCommand`, `AttemptTheftCommand`,
  `BuyResourceCommand`, `VoteOnLawCommand` и т.п.), никогда напрямую из
  UI-скрипта.
- Команда: сначала `_validate()`, затем атомарная мутация `GameState`, затем
  `EventBus.emit(...)`.
- Не менять деньги/склад/цену/репутацию/отношения/законы/время напрямую —
  только через команды.
- Симуляция зависит от `GameClock` и игрового времени, а не от FPS, позиции
  камеры или видимости NPC на экране.
- Save format должен быть сериализуемым и версионированным (пока не
  реализован, но слой `core/data/` — сплошь `Resource`, поэтому сериализация
  добавится без переделки архитектуры).

### 9.4 Шаблон документирования новой системы
При добавлении новой системы — заполнить и добавить сюда же, в раздел 10:

```
### Система: <имя>
- Authoritative state: <какие поля/классы в core/data>
- Commands: <какие команды в core/commands>
- Validation rules: <кратко>
- Emitted events: <какие сигналы EventBus>
```

### 9.5 Чек-лист перед реализацией новой системы
1. Соответствует ли она этим требованиям (9.3)?
2. Если решение мешает будущему коопу — не делать молча, а явно описать
   риск здесь и предложить single-player-friendly альтернативу.
3. Не реализовывать сетевой код без отдельного явного решения.

---

## 10. Дорожная карта / открытые решения

*(Редактируй этот раздел по мере продумывания механик — так файл остаётся
единственным источником правды для Cursor.)*

- [x] Данные, автозагрузки (`SimulationClock`/`GameState`/`EventBus`/`CommandProcessor`)
- [x] Пример command-паттерна: `SetPriceCommand`, `BuyResourceCommand`, `ApplyDailyCostsCommand`
- [x] Data-driven определения: `DataRegistry` + `data/**/*.tres`

### Система: Bakery economy (vertical slice)
- Authoritative state: `BusinessState` в `GameState.businesses` — `cash`, `storage`, `prices`, `daily_revenue`, `daily_expenses`
- Commands: `BuyResourceCommand`, `SetPriceCommand`, `ApplyDailyCostsCommand`
- Validation rules: товар из `allowed_goods`; закупка по `base_price`; проверка `cash` и `storage_capacity`/`max_stack`; цена 1–999; дневные расходы из `BusinessTypeDefinition.base_daily_cost` (cash может уйти в минус)
- Emitted events: `business_cash_changed`, `business_storage_changed`, `business_price_changed`, `business_daily_costs_applied`
- Pure logic: `core/simulation/business_economy.gd` (без мутаций)
- Debug UI: `ui/debug_slice.tscn` — кнопки закупки/цены/расходов, read-only cash/storage

### Система: Daily demand (aggregated)
- Authoritative state: `GameState.npcs` (`NpcState`); `NpcArchetypeDefinition` в `data/npc_archetypes/`; `BusinessState.price_levels` (0–10)
- Commands: `SimulateDailyDemandCommand`, `SetPriceLevelCommand` (+ daily finance commands)
- Validation rules: 20 стартовых NPC из сценария; стартовый cash и дневной бюджет из `ScenarioDefinition` (`npc_starting_cash`, `npc_income_per_day`, по умолчанию 100); бюджет **сбрасывается** через `ApplyNpcDailyIncomeCommand` при смене дня; покупки по `demand_goods` в 10:00; в 20:00 `SimulateTavernSpendingCommand` — NPC тратят остаток в таверне до 0
- Emitted events: `business_demand_tick_completed`, `npc_purchase_recorded`, `npc_cash_changed`, `npcs_initialized`
- Pure logic: `NpcSpawner`, `NpcDemandSimulator`, `DemandFormula`
- System: `DemandSystem` — спрос в 10:00; debug — `ui/debug_slice.tscn` со списком NPC

### Система: FinanceHistory (debug read-model)
- Authoritative state: нет — autoload `FinanceHistory` хранит `FinanceLiveSnapshot` + до 30 `DayFinanceRecord` на бизнес
- Commands: `RecordDailyFinanceCommand` (архив в полночь, после `ApplyDailyCostsCommand`)
- Validation rules: архив только для `completed_day >= 1`
- Emitted events: `business_day_ended`, `finance_live_updated`, `finance_history_updated` (FinanceHistory)
- UI: `ui/finance_debug.tscn` — read-only панель, данные только через FinanceHistory + EventBus

### Система: Player reputation (v1 — без good/bad actions)
- Authoritative state: `GameState.player_reputation` (`ReputationState`, owner_id)
- Commands: `SetPlayerReputationCommand` (debug / будущие системы; пока без авто-изменений от продаж)
- Validation rules: clamp 0–100 через `ReputationFormula`
- Emitted events: `reputation_changed(owner_id, new_value, delta_applied)`
- Pure logic: `ReputationFormula.demand_multiplier()` — влияет на `NpcDemandSimulator` willingness
- Формула спроса: `final_willingness = price_willingness × reputation_mult`

### Система: Council voting + laws (MVP)
- Authoritative state: `GameState.laws` (`LawState`: `is_active`, `activated_day`, `expires_day`); `NpcState.campaign_vote_bonus`; `GameState.last_vote_result`
- Definitions: `LawDefinition` (`data/laws/`) — `effect_type`, `effect_value`, `duration_days` (0 = навсегда, >0 = N дней с момента принятия)
- Commands: `RunCouncilVoteCommand`, `CampaignForLawCommand`, `ExpireLawsCommand`
- Validation rules: голосование детерминировано (`simulation_seed`, `law_id`, `vote_day`, `npc.id`); принятие при `votes_for / total > pass_threshold`; агитация — cash с бизнеса, бонус NPC с `relationship >= relationship_self_interest_min`
- Emitted events: `council_vote_completed`, `law_activated`, `law_expired`, `law_campaign_applied`
- Pure logic: `VoteSimulator`, `LawEffects.get_daily_cost_multiplier()` — интеграция в `ApplyDailyCostsCommand`
- System: `VotingSystem` — каждые N дней с `council_first_vote_day`; `ExpireLawsCommand` при смене дня
- Read-model: autoload `PoliticsHistory` для debug UI
- UI: секция Politics в `ui/finance_debug.tscn` — статус голосования, активные законы, срок/«навсегда», кнопка Campaign

### Система: Save / Load
- Authoritative state: snapshot `GameState` + `SimulationClock` + `FinanceHistory` (live + до 30 дней)
- Commands: нет — `SaveManager` autoload (`save_game`, `load_game`, `list_saves`)
- Validation rules: `save_version` на верхнем уровне JSON; mismatch → явный `SaveResult.fail`, без частичной загрузки; slot name `[a-zA-Z0-9_-]+`
- Emitted events: `game_loaded(slot_name)` + `npcs_initialized`, `state_changed`, `time_of_day_changed`, `reputation_changed`
- Pure logic: `to_dict/from_dict` на data-классах; файл `user://saves/{slot}.json`
- UI: `ui/debug_slice.tscn` — LineEdit слота + Save / Load
- Тест: `tests/save_repro_test.tscn` — round-trip + version mismatch

### Система: Localization (CSV)
- Authoritative state: нет — `translations/game_translations.csv` (`keys,en,ru` + будущие столбцы)
- Autoload: `LocaleService` — OS locale → доступный столбец → fallback `en`
- Import: Godot `csv_translation` → `game_translations.{locale}.translation` на каждый столбец
- UI: все строки через `tr()` / `LocaleService.trf()`; переключение EN/RU в `debug_slice`
- Emitted events: `locale_changed(locale_code)` — HUD/debug панели перерисовываются
- Ключи данных: иерархические (`good.*`, `business.*`, `npc.archetype.*`, `law.*`, `label.*`, `action.*`, `msg.*`)

### Система: NpcView (presentation)
- Authoritative state: нет — только `npc_id` на ноде; данные в `GameState.npcs`
- Commands: нет
- Validation rules: `_process` читает `NpcState.current_cell` и интерполирует к центру тайла; скорость × `SimulationClock.speed_multiplier`; путь не считается в world
- Emitted events: слушает EventBus (индикатор покупки); `npc_positions_changed` для отладки
- Pure logic: нет — `world/npc_view_manager.gd` спавн, `world/npc_view.gd` `CharacterBody2D`
- POI: `CoastalCityMap.cell_to_world(cell)`

### Система: NPC navigation (grid + wander)
- Authoritative state: `NpcState.current_cell`, `home_cell`, `home_slot_id`, `movement_state` (`AT_HOME` / `IDLE_WANDER` / `MOVING_TO_GOAL` / `RETURNING_HOME` / `STROLLING_PARK`), `path_cells`, `idle_ticks_left`, `activity_until_abs_minute`
- Commands: `TickNpcMovementCommand` (батч на тик часов)
- Validation rules: шаг только по `SimulationClock.tick_elapsed` с аккумулятором `tile_size / walk_speed`; дневные цели — двери производственных слотов (`commercial` / `maritime` / `fisherman`) и парк `A`; дома — слоты `residential`; выход в `npc_leave_home_hour` (6:00), возврат и сон в `npc_sleep_hour` (00:00) даже из парка; визит в парк — 4 игровых часа, ходьба от одного края к другому, затем новая случайная цель; в `AT_HOME` view скрыт
- Emitted events: `npc_positions_changed`
- Pure logic: `CityLayoutParser.footprint_rect` / `collect_building_footprint_cells`; `is_house_slot` / `is_production_slot` / `is_park`
- System: `CityNavigationSystem` (`AStarGrid2D` 40×30, solid: вода/лес/footprint зданий, `get_door_node`, `get_house_homes`, `pick_production_door`, `pick_park_end_cell`); `NPCSimulationSystem` оркестратор
- Collision: физика тайлов вода/лес/`obstacle_layer`; `PlacedBuildingView` = `StaticBody2D`

### Система: Player movement (point-and-click)
- Authoritative state: `CharacterState` в `GameState.characters` (`id`, `current_cell`, `path_cells`); герой `hero_1`
- Commands: `MoveCharacterCommand` (клик задаёт путь через `CityNavigationSystem` / `AStarGrid2D`); `TickCharacterMovementCommand` (шаг клетки на тике)
- Validation rules: цель в пределах сетки и проходима; клик по зданию → ближайшая дорога `get_door_node`; спавн новой игры — случайная ROAD-клетка у footprint ратуши `H`
- Emitted events: `characters_initialized`, `character_path_changed`, `character_positions_changed`, `character_arrived`
- System: `CharacterSimulationSystem` на `SimulationClock.tick_elapsed`; аккумулятор `tile_size / walk_speed`
- UI/world: ПКМ в `coastal_city_map.gd` создаёт команду; `player_view.gd` интерполирует к `cell_to_world(current_cell)` × `speed_multiplier`

### Система: Coastal city map (ASCII layout)
- Authoritative state: нет — presentation; слоты как `CitySlotMarker` (meta для будущего assigner)
- Commands: нет
- Validation rules: геометрия только из `data/city/coastal_river_layout.txt`; вода логически `river`/`sea` (flood-fill от нижних рядов); мост `=` на `road_layer`, проходим; бизнесы в слоты не назначаются
- Emitted events: нет
- Pure logic: `CityLayoutParser`, `CityLayoutBuilder`, `CityPlaceholderTileset`
- Scene: `world/coastal_city_map.tscn` (32px tiles); rebuild — кнопка в инспекторе + `auto_build_on_ready`

### Система: DataRegistry (слой определений)
- Authoritative state: нет — только статические определения из `data/`
  (`GoodDefinition`, `BusinessTypeDefinition`, `ScenarioDefinition`);
  состояние партии остаётся в `core/data/` + `GameState`.
- Commands: нет — реестр только читает данные с диска.
- Validation rules: непустой и уникальный `id`; несовпадение типа ресурса —
  `push_error`; у обработанного товара должен быть хотя бы один `input_ids`;
  ссылки `input_ids` / `allowed_goods` / `starting_*` на несуществующие id —
  `push_warning`. Обратный граф (из сырья → продукты) строится из `input_ids`.
- Emitted events: нет (загрузка один раз при старте, до `GameState`).
- [ ] `ui/hud.tscn` — текстовый вывод состояния без графики
- [ ] Клик по зданию на карте → панель здания (`placed_building_view.gd`)
- [x] `player_view.tscn` — спавн у ратуши, point-and-click по сетке
- [ ] `character_view.tscn` — движение персонажей между домом/работой
- [ ] Семейные механики: `core/systems/family_system.gd` (брак/дети/старение)
- [x] Политика (MVP): `VotingSystem`, один закон `trade_tax_reduction`, агитация
- [ ] Политика (расширение): несколько законов, партии, парламентский UI
- [x] Save/Load: JSON `user://saves/`, `SaveManager`, версия формата 9

**Открытые вопросы:**
- Общая казна семьи или у каждого персонажа своя?
- Обычные NPC-горожане (`Citizen`) без профессии игрока — облегчённая версия `CharacterData`?
- Формат "боя" при кражах/арестах — формула или мини-игра?
