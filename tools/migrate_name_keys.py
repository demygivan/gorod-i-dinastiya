import re
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "data"
replacements = [
    (re.compile(r'name_key = "GOOD_([A-Z]+)"'), lambda m: f'name_key = "good.{m.group(1).lower()}"'),
    (re.compile(r'name_key = "BUSINESS_([A-Z]+)"'), lambda m: f'name_key = "business.{m.group(1).lower()}"'),
    (
        re.compile(r'name_key = "NPC_ARCHETYPE_([A-Z]+)"'),
        lambda m: f'name_key = "npc.archetype.{m.group(1).lower()}"',
    ),
    ("name_key = \"LAW_TRADE_TAX_REDUCTION\"", 'name_key = "law.trade_tax_reduction"'),
    ("name_key = \"SCENARIO_DEFAULT\"", 'name_key = "scenario.default"'),
]

for path in root.rglob("*.tres"):
    text = path.read_text(encoding="utf-8")
    new = text
    for pat, repl in replacements:
        if isinstance(pat, str):
            new = new.replace(pat, repl)
        else:
            new = pat.sub(repl, new)
    if new != text:
        path.write_text(new, encoding="utf-8")
        print(path)
