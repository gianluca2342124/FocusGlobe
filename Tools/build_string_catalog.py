#!/usr/bin/env python3
"""Generate FocusGlobe's String Catalogs from reviewable translation tables.

WHY A GENERATOR
    An .xcstrings file is machine-shaped JSON: every key repeats a
    `localizations` / `stringUnit` / `state` scaffold ten times. Reviewing a
    translation inside that is nearly impossible, and hand-editing it is how
    placeholder mismatches get in. The translations live here instead, one line
    per language, so a reviewer reads them as a table and the JSON is derived.

    Re-run after editing TRANSLATIONS; then run Tools/localization_audit.py.

GLOSSARY — the canonical term per language. Chosen once, reused everywhere, so
"Flight" is never two different words in two screens.

    NEVER TRANSLATED: FocusGlobe · FocusGlobe PRO · PRO

    Flight   es vuelo      · fr vol       · de Flug      · ru полёт
             pt-BR voo     · it volo      · ro zbor      · nl vlucht
             zh-Hans 飞行   · hi फ़्लाइट
    Sky      es cielo      · fr ciel      · de Himmel    · ru небо
             pt-BR céu     · it cielo     · ro cer       · nl lucht
             zh-Hans 天空   · hi आकाश
    Streak   es racha      · fr série     · de Serie     · ru серия
             pt-BR sequência · it serie   · ro serie     · nl reeks
             zh-Hans 连续天数 · hi स्ट्रीक
    Coins    es monedas    · fr pièces    · de Münzen    · ru монеты
             pt-BR moedas  · it monete    · ro monede    · nl munten
             zh-Hans 金币   · hi सिक्के
    Passport es Pasaporte  · fr Passeport · de Reisepass · ru Паспорт
             pt-BR Passaporte · it Passaporto · ro Pașaport · nl Paspoort
             zh-Hans 护照   · hi पासपोर्ट
    Focus Shield
             es Escudo de Enfoque · fr Bouclier de Concentration
             de Fokus-Schild      · ru Щит Фокуса
             pt-BR Escudo de Foco · it Scudo Focus
             ro Scut de Concentrare · nl Focusschild
             zh-Hans 专注护盾      · hi फ़ोकस शील्ड
    Cabin    es cabina     · fr cabine    · de Kabine    · ru кабина
             pt-BR cabine  · it cabina    · ro cabină    · nl cabine
             zh-Hans 座舱   · hi केबिन
"""

import importlib
import json
import pathlib
import pkgutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCALES = ["zh-Hans", "hi", "es", "fr", "de", "ru", "pt-BR", "it", "ro", "nl"]

# One catalog per TARGET, because a target can only read its own bundle.
#
# The widget and shield extensions are separate processes that compile none of
# the app's files; a string they render has to be in a catalog that ships inside
# THEIR bundle. A tranche module names its catalog with `CATALOG = "widgets"`;
# omitting it means the app.
CATALOGS = {
    "app": ROOT / "FocusGlobe" / "Localizable.xcstrings",
    "widgets": ROOT / "FocusGlobeWidgets" / "Localizable.xcstrings",
    "shield": (ROOT / "FocusGlobeShieldConfigurationExtension"
               / "Localizable.xcstrings"),
}

sys.path.insert(0, str(ROOT / "Tools"))


def load_tranches() -> dict[str, tuple[dict, dict]]:
    """Merge every tranche module, in name order, grouped by catalog.

    Returns {catalog: (simple strings, plural strings)}. A key defined twice
    WITHIN one catalog is a mistake — two screens disagreeing about one string —
    so this raises rather than letting the last definition win. The same key in
    two different catalogs is fine and expected: "Passport" is rendered by both
    the app and the widget, and each needs it in its own bundle.
    """
    import translations

    tables: dict[str, tuple[dict, dict]] = {name: ({}, {}) for name in CATALOGS}
    owner: dict[tuple[str, str], str] = {}
    for mod in sorted(m.name for m in pkgutil.iter_modules(translations.__path__)):
        module = importlib.import_module(f"translations.{mod}")
        catalog = getattr(module, "CATALOG", "app")
        if catalog not in CATALOGS:
            raise SystemExit(f"{mod} names unknown catalog {catalog!r}")
        merged, plurals = tables[catalog]
        for key, values in module.TRANSLATIONS.items():
            if key in merged and merged[key] != values:
                raise SystemExit(
                    f"duplicate key {key!r} in {mod} "
                    f"(already in {owner[(catalog, key)]}) with a different "
                    f"translation")
            merged[key] = values
            owner.setdefault((catalog, key), mod)
        for key, forms in getattr(module, "PLURALS", {}).items():
            if key in plurals and plurals[key] != forms:
                raise SystemExit(
                    f"duplicate plural key {key!r} in {mod} "
                    f"(already in {owner[(catalog, key)]}) with different forms")
            plurals[key] = forms
            owner.setdefault((catalog, key), mod)
    for catalog, (merged, plurals) in tables.items():
        overlap = set(merged) & set(plurals)
        if overlap:
            raise SystemExit(f"{catalog}: key(s) both simple and plural: "
                             f"{sorted(overlap)}")
    return tables


def simple_entry(key: str, values: list[str]) -> dict:
    assert len(values) == len(LOCALES), f"{key!r} has {len(values)} translations"
    for code, value in zip(LOCALES, values):
        assert value.strip(), f"{key!r} has an empty {code} translation"
    return {
        "extractionState": "manual",
        "localizations": {
            code: {"stringUnit": {"state": "translated", "value": value}}
            for code, value in zip(LOCALES, values)
        },
    }


def plural_entry(key: str, forms: dict[str, dict[str, str]]) -> dict:
    """A key whose wording depends on a number.

    English pluralises by appending "s"; Russian has four CLDR categories,
    Romanian three and Chinese one, so the rule cannot be shared. Each language
    supplies the categories it actually uses — a category iOS asks for and does
    not find falls back to `other`, which is why `other` is mandatory here and
    the rest are not.

    The SOURCE language needs its own variations too: without an `en` entry the
    catalog falls back to the key string itself, which would print "3 day".
    """
    localizations = {}
    for code in ["en"] + LOCALES:
        categories = forms.get(code)
        assert categories, f"{key!r} has no {code} plural forms"
        assert "other" in categories, f"{key!r} {code} is missing the 'other' category"
        for name, value in categories.items():
            assert value.strip(), f"{key!r} has an empty {code}/{name} form"
        localizations[code] = {
            "variations": {
                "plural": {
                    name: {"stringUnit": {"state": "translated", "value": value}}
                    for name, value in categories.items()
                }
            }
        }
    return {"extractionState": "manual", "localizations": localizations}


def build(path: pathlib.Path, keys: dict[str, list[str]],
          plurals: dict[str, dict[str, dict[str, str]]]) -> None:
    strings = {key: simple_entry(key, values) for key, values in keys.items()}
    for key, forms in plurals.items():
        strings[key] = plural_entry(key, forms)
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    print(f"  wrote {path.relative_to(ROOT)}  ({len(keys)} keys + {len(plurals)} "
          f"pluralised x {len(LOCALES)} locales = "
          f"{len(strings) * len(LOCALES)} translations)")


if __name__ == "__main__":
    for name, (keys, plurals) in load_tranches().items():
        if not keys and not plurals:
            continue
        build(CATALOGS[name], keys, plurals)
