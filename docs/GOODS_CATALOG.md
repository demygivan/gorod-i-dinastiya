# Каталог товаров (The Guild 2 style)

Источник данных: `data/goods/*.tres` (один файл на товар).
Рецепты: `input_ids` — что нужно для производства; обратная сторона строится в `DataRegistry`.
Пустой `input_ids` = первичное сырьё / урожай / сбор.

| id | Название | Категория | Базовая цена | Max стек | Вход (`input_ids`) | Из него делают |
|---|---|---|---:|---:|---|---|
| grain | Зерно | raw | 3 | 200 | — | flour, ale |
| wool | Шерсть | raw | 8 | 150 | — | cloth |
| grapes | Виноград | raw | 7 | 150 | — | wine |
| wood | Древесина | raw | 4 | 200 | — | tools |
| ore | Руда | raw | 8 | 200 | — | iron |
| coal | Уголь | raw | 7 | 200 | — | iron |
| herbs | Травы | raw | 9 | 100 | — | medicine |
| vegetables | Овощи | food | 6 | 150 | — | — |
| meat | Мясо | food | 14 | 100 | — | leather |
| fish | Рыба | food | 12 | 100 | — | — |
| spices | Специи | food | 25 | 50 | — | — |
| flour | Мука | material | 6 | 150 | grain | bread |
| iron | Железо | material | 15 | 120 | ore, coal | tools, weapon, armor |
| cloth | Ткань | material | 12 | 100 | wool | clothing |
| leather | Кожа | material | 10 | 100 | meat | armor |
| bread | Хлеб | food | 10 | 100 | flour | — |
| ale | Эль | drink | 5 | 120 | grain | — |
| wine | Вино | drink | 18 | 80 | grapes | — |
| clothing | Одежда | craft | 20 | 60 | cloth | — |
| tools | Инструменты | craft | 22 | 60 | iron, wood | — |
| weapon | Оружие | equipment | 35 | 40 | iron | — |
| armor | Доспех | equipment | 45 | 30 | iron, leather | — |
| medicine | Лекарство | medicine | 28 | 50 | herbs | — |

## Категории

| category | Название | Кол-во |
|---|---|---:|
| raw | Сырьё | 7 |
| food | Еда | 5 |
| material | Материалы | 4 |
| craft | Изделия | 2 |
| equipment | Снаряжение | 2 |
| drink | Напитки | 2 |
| medicine | Медицина | 1 |

## Цепочки производства (граф)

```
grain ─┬─→ flour ─→ bread
       └─→ ale

grapes ──→ wine

ore  ─┐
      ├─→ iron ─┬─→ weapon
coal ─┘         ├─→ armor
                └─→ tools ─(needs wood too)

wool ─→ cloth ─→ clothing

meat ─→ leather ─→ armor

wood ─→ tools

herbs ─→ medicine
```

## Связанные определения

- Типы предприятий: `data/businesses/*.tres` — что разрешено продавать.
- Сценарий: `data/scenarios/default_scenario.tres` — стартовые товары.
- Локализация: `data/locale/strings.csv` — отображаемые названия.
