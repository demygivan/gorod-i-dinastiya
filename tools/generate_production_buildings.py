"""Write data/city/production_buildings.tres from the profession table."""
from __future__ import annotations

from pathlib import Path

# id, profession, building name_key suffix, group, min, weight, slot_kinds, business_type_id
BUILDINGS = [
    ("bakery", "Baker", "building.bakery", "Patron", 1, 10.0, ["commercial"], "bakery"),
    ("farm", "Farmer", "building.farm", "Patron", 1, 10.0, ["residential"], "farm"),
    ("tavern", "Brewer", "building.tavern", "Patron", 1, 10.0, ["commercial"], "tavern"),
    ("fishing_hut", "Fisherman", "building.fishing_hut", "Patron", 1, 10.0, ["maritime"], ""),
    ("windmill", "Miller", "building.windmill", "Patron", 1, 10.0, ["commercial", "residential"], "mill"),
    ("orchard", "Gardener", "building.orchard", "Patron", 1, 10.0, ["residential"], ""),
    ("smithy", "Blacksmith", "building.smithy", "Craftsman", 1, 10.0, ["commercial"], "smithery"),
    ("sewing_workshop", "Tailor", "building.sewing_workshop", "Craftsman", 1, 10.0, ["commercial"], "tailor"),
    ("carpenter_workshop", "Carpenter", "building.carpenter_workshop", "Craftsman", 1, 10.0, ["commercial"], ""),
    ("stonecutter_workshop", "Stonemason", "building.stonecutter_workshop", "Craftsman", 1, 10.0, ["commercial"], ""),
    ("sawmill", "Lumberjack", "building.sawmill", "Craftsman", 1, 10.0, ["commercial", "residential"], ""),
    ("mine", "Miner", "building.mine", "Craftsman", 1, 10.0, ["residential"], "mine"),
    ("alchemist_shop", "Alchemist", "building.alchemist_shop", "Scholar", 1, 10.0, ["commercial"], ""),
    ("church", "Priest", "building.church", "Scholar", 1, 10.0, ["commercial", "residential"], ""),
    ("infirmary", "Physician", "building.infirmary", "Scholar", 1, 10.0, ["commercial"], ""),
    ("cemetery", "Gravedigger", "building.cemetery", "Scholar", 1, 10.0, ["cemetery"], ""),
    ("moneylender_office", "Banker", "building.moneylender_office", "Scholar", 1, 10.0, ["commercial"], ""),
    ("thieves_den", "Thief", "building.thieves_den", "Rogue", 1, 10.0, ["commercial", "residential"], ""),
    ("bandit_camp", "Bandit", "building.bandit_camp", "Rogue", 1, 10.0, ["residential"], ""),
    ("traveling_show", "Performer", "building.traveling_show", "Rogue", 1, 10.0, ["commercial", "residential"], ""),
    ("mercenary_barracks", "Mercenary", "building.mercenary_barracks", "Rogue", 1, 10.0, ["commercial"], ""),
    ("pirate_hideout", "Pirate", "building.pirate_hideout", "Rogue", 1, 10.0, ["maritime"], ""),
    ("watchtower", "Civil", "building.watchtower", "Infrastructure", 0, 10.0, ["residential", "commercial"], ""),
    ("warehouse", "Civil", "building.warehouse", "Infrastructure", 0, 10.0, ["commercial", "maritime"], ""),
    ("hut", "Civil", "building.hut", "Infrastructure", 0, 10.0, ["residential"], ""),
    ("house", "Civil", "building.house", "Infrastructure", 0, 10.0, ["residential"], ""),
    ("mansion", "Civil", "building.mansion", "Infrastructure", 0, 10.0, ["residential"], ""),
]


def kinds_literal(kinds: list[str]) -> str:
    inner = ", ".join(f'"{k}"' for k in kinds)
    return f"Array[String]([{inner}])"


def main() -> None:
    sub_ids = [f"entry_{row[0]}" for row in BUILDINGS]
    load_steps = 2 + len(BUILDINGS)
    lines = [
        f'[gd_resource type="Resource" script_class="BuildingSpawnPool" load_steps={load_steps} format=3]',
        "",
        '[ext_resource type="Script" path="res://data/city/building_spawn_pool.gd" id="1_pool"]',
        '[ext_resource type="Script" path="res://data/city/building_spawn_entry.gd" id="2_entry"]',
        "",
    ]
    for row in BUILDINGS:
        entry_id, profession, name_key, group, minimum, weight, kinds, business = row
        lines.append(f'[sub_resource type="Resource" id="entry_{entry_id}"]')
        lines.append('script = ExtResource("2_entry")')
        lines.append(f'id = "{entry_id}"')
        lines.append(f'name_key = "{name_key}"')
        lines.append(f'profession = "{profession}"')
        lines.append(f'group = "{group}"')
        lines.append(f"slot_kinds = {kinds_literal(kinds)}")
        lines.append(f"weight = {weight}")
        lines.append(f"minimum_quantity = {minimum}")
        if business:
            lines.append(f'business_type_id = "{business}"')
        lines.append("")

    entries_list = ", ".join(f'SubResource("{sid}")' for sid in sub_ids)
    lines.extend(
        [
            "[resource]",
            'script = ExtResource("1_pool")',
            'id = "production"',
            f"entries = [{entries_list}]",
            "",
        ]
    )

    out = Path(__file__).resolve().parents[1] / "data" / "city" / "production_buildings.tres"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {out} ({len(BUILDINGS)} buildings)")


if __name__ == "__main__":
    main()
