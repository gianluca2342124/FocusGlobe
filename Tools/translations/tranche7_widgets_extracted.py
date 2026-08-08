"""Tranche 7b — keys Xcode extracted from the widget target.

All three are bare format specifiers or a symbol; there is nothing to
translate, so they are marked `shouldTranslate: false` rather than given ten
identical values.
"""

CATALOG = "widgets"

TRANSLATIONS: dict[str, list[str]] = {}

DO_NOT_TRANSLATE = {"%lld", "%lld/%lld", "∞"}
