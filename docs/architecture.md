# Architecture

> **Navigation:** feature file lists and agent read discipline → [`docs/INDEX.md`](INDEX.md)  
> **Design authority:** `docs/GAME_SPEC.md` (new mechanics only)

Single-player Godot 4.7 vertical slice. No network code.

## Layers

```
data/            static definitions (*.tres + *_definition.gd)
core/data/       authoritative Resources (per-playthrough state)
core/commands/   validate → mutate GameState → EventBus
core/simulation/ pure logic (no GameState mutations)
core/systems/    SimulationClock hooks (DemandSystem, VotingSystem)
autoloads/       singletons
world/, ui/      presentation only — read GameState, never own economy state
```

Definitions are referenced by string id, never copied into runtime state.

## Runtime (`world/main.tscn`)

```
CityMap + HUD + DemandSystem + VotingSystem + CityNavigationSystem + NPCSimulationSystem + CharacterSimulationSystem
```

## Autoloads

| Name | Role |
|---|---|
| `DataRegistry` | Loads `data/**/*.tres`, `get_good()` / `get_business_type()` / `get_scenario()` |
| `GameState` | Authoritative state, `SAVE_VERSION`, serialization |
| `SimulationClock` | Pause, speed x1/x2/x4, calendar |
| `CommandProcessor` | Single entry for all commands |
| `EventBus` | Decoupled signals |
| `FinanceHistory` | Business finance read-model + save slice |
| `PoliticsHistory` | Vote history read-model |
| `SaveManager` | JSON saves (`SAVE_FORMAT_VERSION`) |
| `LocaleService` | `trf()`, locale from `translations/game_translations.csv` |

## Command flow

1. UI / System → `CommandProcessor.execute(Command.execute, [args])`
2. Command validates against `GameState`
3. On success: mutates state, emits `EventBus`
4. UI refreshes on signals (read-only)

## Major systems (where to look)

| System | Orchestrator | Details in INDEX |
|--------|--------------|------------------|
| NPC shopping + tavern | `core/systems/demand_system.gd` | § NPC economy |
| NPC grid movement | `core/systems/npc_simulation_system.gd` | § NPC movement |
| Player point-and-click | `core/systems/character_simulation_system.gd` | § Player movement |
| Council / laws | `core/systems/voting_system.gd` | § Politics |
| Save/load | `autoloads/save_manager.gd` | § Save / load |

## Principles

- Simulation data is authoritative; UI/world are views.
- All economy mutations go through `core/commands/`.
- Time advances via `SimulationClock`, not UI frame rate.
- Single-player only.

## Planned splits (token economy)

See **§ Рекомендации по разбиению** in [`INDEX.md`](INDEX.md). Priority: `game_state_seeder`, `game_state_serializer`, `npc_purchase_applier`.
