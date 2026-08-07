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

sys.path.insert(0, str(ROOT / "Tools"))


def load_tranches() -> dict[str, list[str]]:
    """Merge every tranche module, in name order.

    A key defined twice is a mistake — two screens disagreeing about one
    string — so this raises rather than letting the last definition win.
    """
    import translations

    merged: dict[str, list[str]] = {}
    owner: dict[str, str] = {}
    for mod in sorted(m.name for m in pkgutil.iter_modules(translations.__path__)):
        table = importlib.import_module(f"translations.{mod}").TRANSLATIONS
        for key, values in table.items():
            if key in merged and merged[key] != values:
                raise SystemExit(
                    f"duplicate key {key!r} in {mod} (already in {owner[key]}) "
                    f"with a different translation")
            merged[key] = values
            owner.setdefault(key, mod)
    return merged


def build(path: pathlib.Path, keys: dict[str, list[str]]) -> None:
    strings = {}
    for key, values in keys.items():
        assert len(values) == len(LOCALES), f"{key!r} has {len(values)} translations"
        for code, value in zip(LOCALES, values):
            assert value.strip(), f"{key!r} has an empty {code} translation"
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                code: {"stringUnit": {"state": "translated", "value": value}}
                for code, value in zip(LOCALES, values)
            },
        }
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    print(f"  wrote {path.relative_to(ROOT)}  ({len(strings)} keys "
          f"x {len(LOCALES)} locales = {len(strings) * len(LOCALES)} translations)")


if __name__ == "__main__":
    build(ROOT / "FocusGlobe" / "Localizable.xcstrings", load_tranches())
