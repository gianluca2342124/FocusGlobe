#!/usr/bin/env python3
"""Prove that every country in FocusGlobe's geography has an ISO 3166-1 code.

WHY THIS IS A SCRIPT AND NOT AN ASSERTION

    It used to be an assertion, in `FocusGlobeApp.init()`, and it took the app
    down on launch over the word "China". A country FocusGlobe cannot name in
    Spanish is a cosmetic defect on one label; refusing to open is not a
    proportionate response to it.

    The check itself is worth keeping — it is the thing that catches a
    destination added to the JSON without a code. It just belongs somewhere that
    can fail loudly for free. Nothing here needs a device, a simulator or a
    running app: the inputs are two JSON files and one Swift table, all of them
    static, all of them readable from a terminal in under a second.

WHAT IT CHECKS

    1. Every distinct `country` value in WorldCities.json and
       TravelDestinations.json resolves to an ISO 3166-1 alpha-2 code.
    2. Every key in the Swift table is already in normalised form, so no key can
       be written in a way `CanonicalRegionCodes.normalize` would never produce
       and therefore never match.
    3. Every value is a well-formed alpha-2 code.
    4. Where WorldCities.json carries its own `countryCode`, it agrees with the
       table. Two sources of truth that disagree are worse than one.

USAGE

    python3 Tools/region_audit.py            # strict: non-zero exit on failure
    python3 Tools/region_audit.py --list     # also print the full resolution
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_TABLE = ROOT / "FocusGlobe" / "Shared" / "CanonicalRegionCodes.swift"
WORLD_CITIES = ROOT / "FocusGlobe" / "Resources" / "WorldCities.json"
DESTINATIONS = ROOT / "FocusGlobe" / "Resources" / "TravelDestinations.json"


def normalize(value: str) -> str:
    """The Python twin of `CanonicalRegionCodes.normalize`.

    Kept deliberately literal rather than clever, because its only job is to
    agree with the Swift. Diacritics stripped, case folded, full stops dropped,
    commas turned into spaces, whitespace runs collapsed, a leading English
    article removed.
    """
    decomposed = unicodedata.normalize("NFD", value)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    folded = unicodedata.normalize("NFKC", stripped).lower()
    folded = folded.replace(".", "").replace(",", " ")
    key = " ".join(folded.split())
    if key.startswith("the "):
        key = key[4:]
    return key


ENTRY = re.compile(r'^\s*"([^"]+)"\s*:\s*"([^"]+)"\s*,\s*(?://.*)?$')


def load_table() -> dict[str, str]:
    """Read the `table` literal out of the Swift source.

    Parsing Swift with a regex is only acceptable because the shape being parsed
    is a flat dictionary of string literals, one per line, and because the
    alternative — a second copy of the table in Python — is the exact duplication
    this script exists to police.
    """
    text = SWIFT_TABLE.read_text(encoding="utf-8")
    start = text.find("static let table: [String: String] = [")
    if start < 0:
        sys.exit(f"region_audit: no `table` literal in {SWIFT_TABLE}")
    body = text[start:]
    end = body.find("\n    ]")
    if end < 0:
        sys.exit(f"region_audit: unterminated `table` literal in {SWIFT_TABLE}")

    table: dict[str, str] = {}
    for line in body[:end].splitlines()[1:]:
        match = ENTRY.match(line)
        if match:
            key, code = match.group(1), match.group(2)
            if key in table and table[key] != code:
                sys.exit(f'region_audit: "{key}" is mapped twice, to '
                         f"{table[key]} and {code}")
            table[key] = code
    if not table:
        sys.exit(f"region_audit: parsed an empty table from {SWIFT_TABLE}")
    return table


def bundled_countries() -> tuple[list[str], dict[str, str]]:
    """Every distinct country value, and the codes the JSON already carries."""
    cities = json.loads(WORLD_CITIES.read_text(encoding="utf-8"))
    nodes = json.loads(DESTINATIONS.read_text(encoding="utf-8"))
    names = {c["country"] for c in cities if c.get("country")}
    names |= {n["country"] for n in nodes if n.get("country")}
    declared = {c["country"]: c["countryCode"]
                for c in cities if c.get("countryCode")}
    return sorted(names), declared


def main() -> int:
    table = load_table()
    names, declared = bundled_countries()
    failures: list[str] = []

    # 2 + 3 — the table is well-formed on its own terms.
    for key, code in sorted(table.items()):
        if normalize(key) != key:
            failures.append(f'key "{key}" is not normalised '
                            f'(normalize gives "{normalize(key)}")')
        if len(code) != 2 or not code.isascii() or not code.isupper() or not code.isalpha():
            failures.append(f'"{key}" maps to "{code}", '
                            f"which is not an ISO 3166-1 alpha-2 code")

    # 1 — coverage of the bundled geography.
    resolved: dict[str, str] = {}
    unresolved: list[str] = []
    for name in names:
        code = table.get(normalize(name))
        if code:
            resolved[name] = code
        else:
            unresolved.append(name)
    for name in unresolved:
        failures.append(f'no ISO region for bundled country "{name}"')

    # 4 — the JSON's own codes agree with the table.
    for name, code in sorted(declared.items()):
        mapped = table.get(normalize(name))
        if mapped and mapped != code:
            failures.append(f'"{name}": WorldCities.json says {code}, '
                            f"the table says {mapped}")

    if "--list" in sys.argv:
        for name in names:
            print(f"  {name:24} {resolved.get(name, '— UNRESOLVED')}")
        print()

    print(f"country values : {len(names)}")
    print(f"resolved       : {len(resolved)}")
    print(f"unresolved     : {len(unresolved)}"
          + (f" ({', '.join(unresolved)})" if unresolved else ""))
    print(f"table rows     : {len(table)} "
          f"({len(set(table.values()))} distinct regions)")

    if failures:
        print()
        for failure in failures:
            print(f"FAIL  {failure}")
        return 1
    print("\nOK — every bundled country resolves to an ISO 3166-1 alpha-2 code.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
