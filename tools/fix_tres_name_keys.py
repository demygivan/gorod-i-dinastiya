import re
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "data"
broken = re.compile(r"^\s*param\(\$m\).*", re.MULTILINE)

for path in root.rglob("*.tres"):
    text = path.read_text(encoding="utf-8")
    if "param($m)" not in text and "GOOD_" not in text and "BUSINESS_" not in text:
        continue

    new = broken.sub("", text)

    if "/goods/" in path.as_posix():
        match = re.search(r'^id = "([^"]+)"', new, re.MULTILINE)
        if match:
            good_id = match.group(1)
            insert = f'name_key = "good.{good_id}"\n'
            new = re.sub(r'^(id = "[^"]+"\n)', r"\1" + insert, new, count=1, flags=re.MULTILINE)
    elif "/businesses/" in path.as_posix():
        match = re.search(r'^id = "([^"]+)"', new, re.MULTILINE)
        if match:
            biz_id = match.group(1)
            insert = f'name_key = "business.{biz_id}"\n'
            new = re.sub(r'^(id = "[^"]+"\n)', r"\1" + insert, new, count=1, flags=re.MULTILINE)
    elif "/npc_archetypes/" in path.as_posix():
        match = re.search(r'^archetype_id = "([^"]+)"', new, re.MULTILINE)
        if match:
            arch_id = match.group(1)
            insert = f'name_key = "npc.archetype.{arch_id}"\n'
            new = re.sub(r'^(archetype_id = "[^"]+"\n)', r"\1" + insert, new, count=1, flags=re.MULTILINE)
    elif "/laws/" in path.as_posix():
        match = re.search(r'^id = "([^"]+)"', new, re.MULTILINE)
        if match:
            law_id = match.group(1)
            insert = f'name_key = "law.{law_id}"\n'
            new = re.sub(r'^(id = "[^"]+"\n)', r"\1" + insert, new, count=1, flags=re.MULTILINE)
    elif "/scenarios/" in path.as_posix():
        match = re.search(r'^id = "([^"]+)"', new, re.MULTILINE)
        if match:
            scenario_id = match.group(1)
            insert = f'name_key = "scenario.{scenario_id.replace("_scenario", "")}"\n'
            if scenario_id == "default_scenario":
                insert = 'name_key = "scenario.default"\n'
            new = re.sub(r'^(id = "[^"]+"\n)', r"\1" + insert, new, count=1, flags=re.MULTILINE)

    # Also fix old-style keys if present
    new = re.sub(r'name_key = "GOOD_[A-Z]+"', lambda m: m.group(0), new)
    path.write_text(new, encoding="utf-8")
    print("fixed", path)
