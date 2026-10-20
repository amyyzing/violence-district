"""Enumerate catalog loadouts and flag known interaction costs, not win rates."""

import json
from collections import Counter
from itertools import combinations, product
from pathlib import Path


def analyze(catalog):
    perks = [entry["name"] for entry in catalog["perks"]]
    items = [entry["name"] for entry in catalog["items"]]
    assert len(perks) == len(set(perks)), "Duplicate perks"
    assert len(items) == len(set(items)), "Duplicate items"
    winded = {"Heads Up", "Quick Recovery", "Perfect Landing", "Great Collapse"}
    assert winded <= set(perks), "Catalog no longer matches interaction rules"
    counts = Counter()
    for triple, item in product(combinations(perks, 3), items):
        selected = set(triple)
        counts["total_loadouts"] += 1
        if len(selected & winded) > 1:
            counts["shared_winded_trigger_competition"] += 1
        self_healing = "Ambitious Medic" in selected or item == "Bandage"
        if "No Pain No Gain" in selected and self_healing:
            counts["permanent_injury_with_self_healing"] += 1
        if "High Karma" in selected and self_healing:
            counts["temporary_anti_heal_after_self_unhook"] += 1
        if "Perfectionist Planning" in selected:
            counts["repair_bonus_restricted_to_selected_generators"] += 1
        if item == "Twist of Fate":
            counts["tool_has_random_misfire"] += 1
    return dict(counts)


if __name__ == "__main__":
    source = Path(__file__).parent / "fixtures/survivor_loadout_catalog_2026_10_20.json"
    result = analyze(json.loads(source.read_text(encoding="utf-8-sig")))
    print(json.dumps(result, indent=2))
    print("Flags overlap; they are costs to consider, not invalid loadouts or rankings.")
