#!/usr/bin/env python3
"""FocusGlobe localization coverage + String Catalog integrity audit.

Two jobs, deliberately kept in one small script rather than a framework:

  1. COVERAGE — sweep every .swift file for user-facing string literals and
     report which are not present as keys in a String Catalog. Literals are
     classified so the report distinguishes a real gap from an identifier that
     must stay in English.

  2. CATALOG INTEGRITY — for every key in every .xcstrings, verify that all
     supported locales are present, none is empty, and every translation's
     format placeholders match the English source. A placeholder mismatch is a
     crash in production, not a typo.

Usage:
    python3 Tools/localization_audit.py            # report
    python3 Tools/localization_audit.py --strict   # exit 1 if any gap
"""

import json
import pathlib
import re
import sys
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent

# The eleven FocusGlobe ships. Must match FocusLanguage.allCases.
LOCALES = ["en", "zh-Hans", "hi", "es", "fr", "de", "ru", "pt-BR", "it", "ro", "nl"]
SOURCE_LOCALE = "en"

# Literals appearing inside these are user-facing by construction.
DISPLAY_CALL = re.compile(
    r'(?:\bText|\bButton|\bLabel|AppPrimaryButton|SettingsRow|ToggleRow|SectionLabel|'
    r'ScreenHeader|accessibilityLabel|accessibilityHint|accessibilityValue|'
    r'navigationTitle|confirmationDialog|\.alert|localized:)\s*\(?\s*"([^"\\]{2,})"'
)
ANY_LITERAL = re.compile(r'"([^"\\\n]{2,})"')

# Category A — internal, must stay English.
INTERNAL_PATTERNS = [
    re.compile(r'^[a-z0-9_]+(\.[a-z0-9_]+)+$'),      # fg.settings, group.com.x
    re.compile(r'^https?://'),                        # URLs
    re.compile(r'^[a-z0-9]+(-[a-z0-9]+)*$'),          # sky-ids, skin-ids, sound ids
    re.compile(r'^[A-Z][A-Za-z0-9]*$'),               # TypeNames / AssetNames
    re.compile(r'^[a-z][A-Za-z0-9]*$'),               # camelCase identifiers
    re.compile(r'^%[@dlfs]'),                         # bare format specifiers
    re.compile(r'^[\W\d\s]+$'),                       # punctuation / numbers only
    re.compile(r'^p_[a-z_]+$'),                       # RPC params
]
# SF Symbol names: dotted lowercase, often with .fill/.circle
SF_SYMBOL = re.compile(r'^[a-z0-9]+(\.[a-z0-9]+)*(\.fill|\.circle|\.slash)?$')

# Files that hold no user-facing copy.
SKIP_DIRS = {".git", "Tools", "supabase", "Documentation", "build", ".build"}


def is_internal(s: str) -> bool:
    if any(p.match(s) for p in INTERNAL_PATTERNS):
        return True
    if SF_SYMBOL.match(s):
        return True
    # A single word with no space and no capital is almost never UI copy.
    if " " not in s and not any(c.isupper() for c in s) and len(s) < 12:
        return True
    return False


def swift_files():
    for p in ROOT.rglob("*.swift"):
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        yield p


def catalogs():
    for p in ROOT.rglob("*.xcstrings"):
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        yield p


def load_catalog_keys():
    keys = {}
    for path in catalogs():
        try:
            data = json.loads(path.read_text())
        except Exception as exc:                      # noqa: BLE001
            print(f"  !! {path.relative_to(ROOT)} is not valid JSON: {exc}")
            continue
        for key in data.get("strings", {}):
            keys.setdefault(key, []).append(path)
    return keys


def audit_coverage(catalog_keys):
    display, other = Counter(), Counter()
    where = defaultdict(set)
    for path in swift_files():
        text = path.read_text(errors="ignore")
        stripped = re.sub(r"//.*", "", text)
        for m in DISPLAY_CALL.findall(stripped):
            display[m] += 1
            where[m].add(str(path.relative_to(ROOT)))
        for m in ANY_LITERAL.findall(stripped):
            if m not in display:
                other[m] += 1

    missing_display = {k: v for k, v in display.items()
                       if k not in catalog_keys and not is_internal(k)}
    candidate_other = {k: v for k, v in other.items()
                       if k not in catalog_keys and not is_internal(k) and " " in k}

    print("== COVERAGE ==")
    print(f"  display-call literals found      : {len(display)}")
    print(f"  of those present in a catalog    : {len(display) - len(missing_display)}")
    print(f"  CATEGORY D (missing, must fix)   : {len(missing_display)}")
    print(f"  other sentence-like literals not "
          f"in a catalog (review)             : {len(candidate_other)}")
    if missing_display:
        print("\n  first 40 category-D strings:")
        for k, _ in sorted(missing_display.items())[:40]:
            src = sorted(where[k])[:1]
            print(f"    - {k[:70]!r}  ({src[0] if src else '?'})")
    return missing_display


def locale_values(entry):
    """Every translated string one locale holds for one key.

    A key is either simple (one `stringUnit`) or pluralised (a `stringUnit` per
    CLDR category under `variations.plural`). Both shapes are checked the same
    way — a placeholder mismatch inside the "few" form of a Russian plural is
    exactly as much of a production crash as one in a simple string.

    Returns `None` when the locale is absent, else a list of (label, value).
    A pluralised locale MUST carry `other`: it is the category iOS falls back
    to for any it cannot find.
    """
    if "stringUnit" in entry:
        return [("", entry["stringUnit"].get("value", ""))]
    plural = entry.get("variations", {}).get("plural")
    if not plural:
        return None
    if "other" not in plural:
        return [("[no 'other' category]", "")]
    return [(f"[{name}]", unit.get("stringUnit", {}).get("value", ""))
            for name, unit in sorted(plural.items())]


# A printf conversion is terminated by its CONVERSION CHARACTER. That is what
# makes "%lldm" one `%lld` followed by a literal "m" — the naive `%[a-zA-Z]+`
# reading treated the whole thing as a placeholder named "%lldm" and flagged
# every correct translation of a compact duration.
SPECIFIER = re.compile(
    r"%(?:\d+\$)?[-+ #0']*(?:\d+|\*)?(?:\.(?:\d+|\*))?"
    r"(hh|h|ll|l|q|L|z|t|j)?([@%diouxXeEfFgGaAcsSp])"
)


def specifiers(text):
    """The printf conversions in `text`, normalised for comparison.

    The positional index is stripped, so a translation may reorder arguments
    with "%2$@ %1$@" without being reported — several of these languages need
    to. The length modifier is KEPT: "%lld" and "%d" consume different numbers
    of bytes, and swapping them is exactly the crash this check exists to catch.
    """
    return sorted(f"%{length}{conv}"
                  for length, conv in SPECIFIER.findall(text)
                  if conv != "%")


def audit_catalogs():
    print("\n== CATALOG INTEGRITY ==")
    total_keys = 0
    problems = []
    for path in catalogs():
        try:
            data = json.loads(path.read_text())
        except Exception as exc:                      # noqa: BLE001
            problems.append((str(path.relative_to(ROOT)), "-", f"invalid JSON: {exc}"))
            continue
        strings = data.get("strings", {})
        total_keys += len(strings)
        for key, entry in strings.items():
            loc = entry.get("localizations", {})
            source = key
            src_ph = specifiers(source)
            for code in LOCALES:
                if code == SOURCE_LOCALE:
                    continue
                values = locale_values(loc.get(code, {}))
                if values is None:
                    problems.append((str(path.relative_to(ROOT)), code,
                                     f"MISSING  {key[:50]!r}"))
                    continue
                for label, value in values:
                    if not value.strip():
                        problems.append((str(path.relative_to(ROOT)), code,
                                         f"EMPTY    {key[:50]!r}{label}"))
                        continue
                    if specifiers(value) != src_ph:
                        problems.append((str(path.relative_to(ROOT)), code,
                                         f"PLACEHOLDER {key[:40]!r}{label} "
                                         f"-> {value[:40]!r}"))
    print(f"  catalogs           : {len(list(catalogs()))}")
    print(f"  total keys         : {total_keys}")
    print(f"  expected entries   : {total_keys * (len(LOCALES) - 1)}")
    print(f"  problems           : {len(problems)}")
    for path, code, msg in problems[:30]:
        print(f"    {path} [{code}] {msg}")
    if len(problems) > 30:
        print(f"    … and {len(problems) - 30} more")
    return problems


def main():
    catalog_keys = load_catalog_keys()
    missing = audit_coverage(catalog_keys)
    problems = audit_catalogs()
    print("\n== RESULT ==")
    ok = not missing and not problems
    print("  PASS — no category-D strings, no catalog problems." if ok else
          f"  INCOMPLETE — {len(missing)} unlocalized display strings, "
          f"{len(problems)} catalog problems.")
    if "--strict" in sys.argv and not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
