"""Tranche 8 — findings from the use-site review of every ambiguous key.

METHOD

    Each short English key was traced to the Swift line that renders it, and
    the translation judged against what that line actually shows. Reading a
    key in isolation is exactly how the three defects below survived four
    earlier passes: every one of them is a grammatically fine translation of
    the wrong sense.

WHAT THE REVIEW FOUND

  * `Flying` is NOT "in flight". It is the badge on the balloon skin you have
    equipped (`StoreView.swift:267`, shown only `if equipped`). Ten languages
    said "en vuelo / in volo / в полёте", which describes the pilot, not the
    skin. It now reads as "in use", which is what the badge means.

  * `Open` is genuinely a verb — the button that opens a room lobby
    (`RoomDetailsView.swift:33`). But FlightSetup used the SAME word for a
    boarding-pass field meaning "apps not shielded"
    (`blockApps ? "Protected" : "Open"`), which is a different sense AND was
    never in a catalog at all. Split: the button keeps `Open`, the field gets
    its own `Unrestricted` key.

  * `Current` marks the Cabin slot an item currently sits in
    (`StoreView.swift:754`), not the running streak. The French was
    "Actuelle"; the noun there is `emplacement`, masculine, so it is now
    "Actuel". The translator comment said "streak" and was wrong.

  * `RETURN` is the return leg of a boarding pass, not a Back button. Chinese
    said 返回 (go back) and Dutch said TERUG (back); both are now 回程 / RETOUR.

  * `Landed` was reviewed and KEPT. Its only use site is
    `HistoryView.swift:107` — `record.completed ? "Landed" : "Cancelled"` — a
    flight-record status, never an action. There is no `Land` action key in
    the product, so the pair the glossary implied does not exist. Russian
    "Приземлился" is retained deliberately: it is the word Russian flight
    boards use for a flight (полёт, masculine), and it agrees with the
    "Отменён" it alternates with.

  * Twelve Store and boarding-pass strings reached the screen through helper
    arguments — `goldAction("Equip")`, `field("SHIELD", protection)` — so no
    literal ever appeared at a display call and the regex could not see them.
    They are added here.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Store: skin ownership and equipping ------------------------------
    # `Equip` is an action, `Equipped` a state — different words in every
    # language that inflects, which is most of them.
    "Equip": [
        "装备", "लगाएँ", "Usar", "Utiliser", "Verwenden", "Использовать",
        "Usar", "Usa", "Folosește", "Gebruiken",
    ],
    "Equipped": [
        "使用中", "इस्तेमाल में", "En uso", "Utilisée", "Im Einsatz",
        "Используется", "Em uso", "In uso", "În uz", "In gebruik",
    ],
    "Owned.": [
        "已拥有。", "आपके पास है।", "Adquirido.", "Acquis.", "Gekauft.",
        "Куплено.", "Adquirido.", "Acquistato.", "Achiziționat.", "Gekocht.",
    ],
    "Move": [
        "移动", "हटाएँ", "Mover", "Déplacer", "Verschieben", "Переместить",
        "Mover", "Sposta", "Mută", "Verplaatsen",
    ],
    "Place": [
        "放置", "रखें", "Colocar", "Placer", "Platzieren", "Разместить",
        "Colocar", "Posiziona", "Așază", "Plaatsen",
    ],
    "Replace…": [
        "替换…", "बदलें…", "Sustituir…", "Remplacer…", "Ersetzen…",
        "Заменить…", "Substituir…", "Sostituisci…", "Înlocuiește…",
        "Vervangen…",
    ],
    # Store preview orientation toggle.
    "Portrait": [
        "竖屏", "पोर्ट्रेट", "Vertical", "Portrait", "Hochformat",
        "Портрет", "Retrato", "Verticale", "Portret", "Staand",
    ],
    "Landscape": [
        "横屏", "लैंडस्केप", "Horizontal", "Paysage", "Querformat",
        "Альбом", "Paisagem", "Orizzontale", "Peisaj", "Liggend",
    ],
    # The free tier on a balloon skin's unlock line.
    "Free": [
        "免费", "मुफ़्त", "Gratis", "Gratuit", "Kostenlos", "Бесплатно",
        "Grátis", "Gratis", "Gratuit", "Gratis",
    ],

    # ---- Boarding pass ----------------------------------------------------
    # Field LABELS, small-caps by design on the printed pass.
    "DATE": [
        "日期", "तारीख़", "FECHA", "DATE", "DATUM", "ДАТА",
        "DATA", "DATA", "DATA", "DATUM",
    ],
    "MINUTE": [
        "分钟", "मिनट", "MINUTO", "MINUTE", "MINUTE", "МИНУТА",
        "MINUTO", "MINUTO", "MINUT", "MINUUT",
    ],
    "MINUTES": [
        "分钟", "मिनट", "MINUTOS", "MINUTES", "MINUTEN", "МИНУТ",
        "MINUTOS", "MINUTI", "MINUTE", "MINUTEN",
    ],
    "ENDLESS": [
        "无限", "अनंत", "SIN FIN", "SANS FIN", "ENDLOS", "БЕЗ КОНЦА",
        "SEM FIM", "SENZA FINE", "FĂRĂ SFÂRȘIT", "EINDELOOS",
    ],
    # The shield field's two values. `Protected` pairs with `Unrestricted`
    # rather than reusing the `Open` button, which is a verb.
    "Protected": [
        "已保护", "सुरक्षित", "Protegido", "Protégé", "Geschützt",
        "Под защитой", "Protegido", "Protetto", "Protejat", "Beschermd",
    ],
    "Unrestricted": [
        "未限制", "बिना रोक", "Sin restricción", "Sans restriction",
        "Ohne Sperre", "Без ограничений", "Sem restrição",
        "Senza restrizioni", "Fără restricții", "Zonder beperking",
    ],
}


# Translator context, corrected where the earlier note named the wrong sense.
COMMENTS: dict[str, str] = {
    "Flying": "Badge on the balloon skin the pilot has EQUIPPED — 'in use', "
              "not 'in flight'. Shown only when equipped.",
    "Equip": "Button: start using this balloon skin.",
    "Equipped": "State: this balloon skin is the one in use.",
    "Open": "Verb on the button that opens a Focus Room lobby. For the "
            "boarding-pass shield field, see 'Unrestricted'.",
    "Current": "Marks the Cabin slot an item currently occupies. The noun is "
               "the slot/placement, not the streak.",
    "RETURN": "The return leg printed on a boarding pass. Not a Back button.",
    "Landed": "Status of a finished focus flight in the logbook, paired with "
              "'Cancelled'. Never an action — FocusGlobe has no Land button.",
    "Protected": "Boarding-pass field: apps are blocked by Focus Shield.",
    "Unrestricted": "Boarding-pass field: apps are NOT blocked this flight.",
    "Free": "Price tier of a balloon skin — free of charge. Never 'release'.",
    "Portrait": "Store preview orientation.",
    "Landscape": "Store preview orientation.",
}
