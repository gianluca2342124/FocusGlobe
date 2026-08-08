#!/usr/bin/env python3
"""Track which localization values have had a NATIVE-SPEAKER review.

WHY THIS EXISTS
    `localization_audit.py` proves a translation *exists*, has the right
    placeholders and the right plural categories. It cannot tell you whether a
    Dutch speaker would ever say it. Those are different questions, and only
    the second one needs a human-shaped pass over all 1,055 translatable keys
    in ten languages.

    Reviews of that size do not fit in one sitting, so the coverage has to be
    written down somewhere a fresh reviewer can trust. This file is that
    record: one row per translatable key, one column per locale, and a mark
    that means a specific thing and nothing looser.

WHAT `R` MEANS
    A cell is `R` only when all five of these happened:

      1. the English source was read;
      2. its real use site was inspected wherever the meaning was not obvious
         from the key alone;
      3. the existing target-language value was read;
      4. its idiom, grammar and product meaning were consciously judged by
         someone writing as a native speaker of that language;
      5. it was then either deliberately KEPT or rewritten.

    Passing the audit is not review. Having a non-empty value is not review.
    Matching the glossary is not review. If you cannot say which of KEEP or
    REWRITE you chose and why, the cell stays `-`.

USAGE
    python3 Tools/review_manifest.py sync       # reconcile rows with catalogs
    python3 Tools/review_manifest.py report     # coverage, overall and by area
    python3 Tools/review_manifest.py pending es --limit 40 --area onboarding
    python3 Tools/review_manifest.py mark es --area onboarding
    python3 Tools/review_manifest.py mark es --keys-from /tmp/done.txt

`sync` is safe to re-run: it adds keys the tranches have gained, drops rows for
keys that no longer exist, refreshes the English and context columns, and
leaves every existing mark alone. A key whose ENGLISH SOURCE CHANGED loses its
marks, because the thing that was reviewed is no longer the thing that ships.
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "Tools" / "localization_review_manifest.tsv"

# Review order, which is the order the columns appear in. Deliberately NOT the
# generator's locale order: reviewers work in related pairs (Iberian, Romance,
# Germanic, Slavic+Romanian, Asian) and the file should read the way the work
# is actually done.
LOCALES = ["es", "pt-BR", "fr", "it", "de", "nl", "ru", "ro", "zh-Hans", "hi"]

COLUMNS = ["catalog", "area", "key", "english", "context"] + LOCALES

CATALOGS = {
    "app": ROOT / "FocusGlobe" / "Localizable.xcstrings",
    "widgets": ROOT / "FocusGlobeWidgets" / "Localizable.xcstrings",
    "shield": (ROOT / "FocusGlobeShieldConfigurationExtension"
               / "Localizable.xcstrings"),
}

# Where a tranche module's strings actually appear, in words a reviewer can use
# to decide what to open. The module name alone ("tranche6_app") says nothing.
AREAS = {
    "tranche1_onboarding": "onboarding",
    "tranche2_home_flight": "home-flight",
    "tranche3_store_passport_friends_settings": "store-passport-friends-settings",
    "tranche4_subscription": "paywall",
    "tranche5_notifications": "notifications",
    "tranche5_shield": "shield",
    "tranche5_widgets": "widgets",
    "tranche6_app": "app-chrome",
    "tranche6_content": "content",
    "tranche6_final": "misc",
    "tranche6_flight": "flight",
    "tranche6_items": "store-items",
    "tranche6_names": "names",
    "tranche6_online": "online",
    "tranche6_passport": "passport",
    "tranche7_extracted": "extracted",
    "tranche7_widgets_extracted": "widgets",
    "tranche8_review": "use-site-review",
    "tranche9_geography": "geography",
}

SWIFT_ROOTS = [
    ROOT / "FocusGlobe",
    ROOT / "FocusGlobeWidgets",
    ROOT / "FocusGlobeShieldConfigurationExtension",
    ROOT / "FocusGlobeShieldActionExtension",
    ROOT / "FocusGlobeDeviceActivityMonitorExtension",
]


# ---------------------------------------------------------------- collection

def tranche_owners():
    """{(catalog, key): module} plus each module's translator comments.

    Imports the tables rather than parsing them, so a key added by a loop or a
    dict comprehension is still attributed correctly.
    """
    sys.path.insert(0, str(ROOT / "Tools"))
    import pkgutil
    import importlib
    import translations

    owners: dict[tuple[str, str], str] = {}
    comments: dict[tuple[str, str], str] = {}
    for mod in sorted(m.name for m in pkgutil.iter_modules(translations.__path__)):
        module = importlib.import_module(f"translations.{mod}")
        catalog = getattr(module, "CATALOG", "app")
        for key in list(module.TRANSLATIONS) + list(getattr(module, "PLURALS", {})):
            owners.setdefault((catalog, key), mod)
        for key, comment in getattr(module, "COMMENTS", {}).items():
            comments[(catalog, key)] = comment
    return owners, comments


def swift_index():
    """literal -> "File.swift:line" for the first place each string is written.

    One sweep over the sources builds the whole index; grepping 1,080 keys one
    at a time takes minutes and produces the same answer. Only the first hit is
    kept — the column is a pointer for the reviewer, not an inventory.
    """
    index: dict[str, str] = {}
    for root in SWIFT_ROOTS:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*.swift")):
            rel = path.relative_to(ROOT)
            try:
                lines = path.read_text().splitlines()
            except UnicodeDecodeError:
                continue
            for number, line in enumerate(lines, 1):
                for literal in re.findall(r'"([^"\\]{2,})"', line):
                    index.setdefault(literal, f"{rel.name}:{number}")
    return index


def catalog_rows():
    """Every translatable key in every catalog, with its English source."""
    owners, comments = tranche_owners()
    sites = swift_index()

    rows = []
    for catalog, path in CATALOGS.items():
        if not path.exists():
            continue
        data = json.loads(path.read_text())
        for key, entry in data.get("strings", {}).items():
            if entry.get("shouldTranslate") is False:
                continue
            english = key
            variations = (entry.get("localizations", {})
                          .get("en", {}).get("variations", {}).get("plural"))
            if variations:
                other = variations.get("other", {}).get("stringUnit", {})
                english = f"{key} | plural: {other.get('value', '')}"
            module = owners.get((catalog, key), "")
            context = comments.get((catalog, key), "")
            if not context:
                context = sites.get(key, "")
            rows.append({
                "catalog": catalog,
                "area": AREAS.get(module, module or "unowned"),
                "key": key,
                "english": english,
                "context": context,
            })
    rows.sort(key=lambda r: (r["catalog"], r["key"]))
    return rows


# ------------------------------------------------------------------ manifest

def encode(value: str) -> str:
    """One row per key, so a field may not contain a newline or a tab.

    Several keys are multi-line paywall copy and onboarding prose. Escaping
    keeps the file greppable line-by-line; `decode` puts the real characters
    back before anything compares a key to a catalog.
    """
    return (value.replace("\\", "\\\\").replace("\t", "\\t")
                 .replace("\n", "\\n").replace("\r", "\\r"))


def decode(value: str) -> str:
    out, index = [], 0
    while index < len(value):
        char = value[index]
        if char == "\\" and index + 1 < len(value):
            nxt = value[index + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", "\\": "\\"}.get(nxt, nxt))
            index += 2
        else:
            out.append(char)
            index += 1
    return "".join(out)


def read_manifest():
    if not MANIFEST.exists():
        return {}
    rows = {}
    lines = MANIFEST.read_text().splitlines()
    for line in lines:
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if parts == COLUMNS:
            continue
        if len(parts) != len(COLUMNS):
            raise SystemExit(f"malformed manifest row: {line[:80]!r}")
        row = {name: decode(part) for name, part in zip(COLUMNS, parts)}
        rows[(row["catalog"], row["key"])] = row
    return rows


HEADER = """\
# FocusGlobe native-language review coverage. Generated and updated by
# Tools/review_manifest.py -- run `sync` after changing any translation table.
#
# R = a native-speaker judgement was made on THIS key in THIS language and the
#     value was then deliberately kept or rewritten. - = not yet.
# Passing localization_audit.py is NOT review; see the script's docstring.
"""


def write_manifest(rows: dict):
    ordered = sorted(rows.values(), key=lambda r: (r["catalog"], r["key"]))
    out = [HEADER + "\t".join(COLUMNS)]
    out += ["\t".join(encode(row[column]) for column in COLUMNS)
            for row in ordered]
    MANIFEST.write_text("\n".join(out) + "\n")


def cmd_sync(args):
    existing = read_manifest()
    fresh = catalog_rows()
    result = {}
    added = dropped = reset = 0
    for row in fresh:
        identity = (row["catalog"], row["key"])
        previous = existing.pop(identity, None)
        if previous is None:
            added += 1
            marks = {locale: "-" for locale in LOCALES}
        elif previous["english"] != row["english"]:
            # The source text moved under the review. Whatever was judged is
            # not what ships now, so the marks are void.
            reset += 1
            marks = {locale: "-" for locale in LOCALES}
        else:
            marks = {locale: previous[locale] for locale in LOCALES}
        result[identity] = {**row, **marks}
    dropped = len(existing)
    write_manifest(result)
    print(f"synced {len(result)} translatable keys "
          f"(+{added} new, -{dropped} removed, {reset} reset on English change)")


def cmd_report(args):
    rows = read_manifest()
    if not rows:
        raise SystemExit("no manifest; run `sync` first")
    total = len(rows)
    print(f"translatable keys : {total}")
    print(f"locales           : {len(LOCALES)}")
    print(f"cells             : {total * len(LOCALES)}")
    print()
    done_total = 0
    for locale in LOCALES:
        done = sum(1 for row in rows.values() if row[locale] == "R")
        done_total += done
        bar = "#" * (done * 30 // total) if total else ""
        print(f"  {locale:<8} {done:>5}/{total}  {bar}")
    print()
    print(f"reviewed cells    : {done_total}")
    print(f"remaining cells   : {total * len(LOCALES) - done_total}")

    if args.by_area:
        print()
        areas: dict[str, list] = {}
        for row in rows.values():
            areas.setdefault(row["area"], []).append(row)
        for area in sorted(areas):
            group = areas[area]
            done = sum(1 for row in group for locale in LOCALES
                       if row[locale] == "R")
            print(f"  {area:<34} {done:>6}/{len(group) * len(LOCALES)}")


def current_values(locale: str) -> dict[tuple[str, str], str]:
    """{(catalog, key): shipped value} so `pending` can show what to judge."""
    values = {}
    for catalog, path in CATALOGS.items():
        if not path.exists():
            continue
        data = json.loads(path.read_text())
        for key, entry in data.get("strings", {}).items():
            unit = entry.get("localizations", {}).get(locale, {})
            if "stringUnit" in unit:
                values[(catalog, key)] = unit["stringUnit"].get("value", "")
            elif "variations" in unit:
                forms = unit["variations"].get("plural", {})
                values[(catalog, key)] = " | ".join(
                    f"{name}={form.get('stringUnit', {}).get('value', '')}"
                    for name, form in sorted(forms.items()))
    return values


def cmd_pending(args):
    rows = read_manifest()
    pending = [row for row in rows.values() if row[args.locale] != "R"]
    if args.area:
        pending = [row for row in pending if row["area"] == args.area]
    if args.catalog:
        pending = [row for row in pending if row["catalog"] == args.catalog]
    pending.sort(key=lambda r: (r["area"], r["catalog"], r["key"]))
    shown = pending[: args.limit] if args.limit else pending
    values = current_values(args.locale) if args.with_values else {}
    for row in shown:
        if args.with_values:
            value = values.get((row["catalog"], row["key"]), "")
            print(f"{row['area']}\t{encode(row['key'])}\t{encode(value)}")
        else:
            print(f"{row['area']}\t{row['catalog']}\t{encode(row['key'])}")
    print(f"# {len(shown)} shown of {len(pending)} pending for {args.locale}",
          file=sys.stderr)


def cmd_mark(args):
    rows = read_manifest()
    keys = set()
    if args.keys_from:
        text = pathlib.Path(args.keys_from).read_text()
        keys = {line for line in text.splitlines() if line.strip()}
    marked = 0
    for identity, row in rows.items():
        if args.area and row["area"] != args.area:
            continue
        if args.catalog and row["catalog"] != args.catalog:
            continue
        if keys and row["key"] not in keys:
            continue
        if not args.area and not args.catalog and not keys:
            raise SystemExit("refusing to mark everything; pass a filter")
        for locale in args.locales:
            if row[locale] != "R":
                row[locale] = "R"
                marked += 1
    write_manifest(rows)
    print(f"marked {marked} cells reviewed for {', '.join(args.locales)}")


def cmd_unmark(args):
    rows = read_manifest()
    cleared = 0
    for row in rows.values():
        if args.area and row["area"] != args.area:
            continue
        for locale in args.locales:
            if row[locale] == "R":
                row[locale] = "-"
                cleared += 1
    write_manifest(rows)
    print(f"cleared {cleared} cells")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("sync").set_defaults(func=cmd_sync)

    report = sub.add_parser("report")
    report.add_argument("--by-area", action="store_true")
    report.set_defaults(func=cmd_report)

    pending = sub.add_parser("pending")
    pending.add_argument("locale", choices=LOCALES)
    pending.add_argument("--area")
    pending.add_argument("--catalog", choices=list(CATALOGS))
    pending.add_argument("--limit", type=int, default=0)
    pending.add_argument("--with-values", action="store_true",
                         help="also print the value currently shipping")
    pending.set_defaults(func=cmd_pending)

    mark = sub.add_parser("mark")
    mark.add_argument("locales", nargs="+", choices=LOCALES)
    mark.add_argument("--area")
    mark.add_argument("--catalog", choices=list(CATALOGS))
    mark.add_argument("--keys-from")
    mark.set_defaults(func=cmd_mark)

    unmark = sub.add_parser("unmark")
    unmark.add_argument("locales", nargs="+", choices=LOCALES)
    unmark.add_argument("--area")
    unmark.set_defaults(func=cmd_unmark)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
