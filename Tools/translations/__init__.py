"""Translation tables, one module per tranche.

Split by surface rather than kept in one file so a reviewer can open the
tranche they care about, and so each localization commit touches one table.
`build_string_catalog.py` merges them in order; a key defined twice is a
mistake and the builder says so rather than silently letting the last one win.
"""
