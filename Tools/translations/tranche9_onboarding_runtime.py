"""Tranche 9 — the values a real device proved were still rendering in English.

WHAT THIS TRANCHE IS

    A Spanish first run on a real iPhone, screenshotted. Almost everything on
    those screens was already translated — the earlier tranches did their job —
    but seven classes of value reached the screen through `Text(someString)`,
    which renders VERBATIM, or through `Calendar.current`, which answers in the
    DEVICE language. Those are render-path defects and they are fixed in Swift.

    What is new HERE is only what was genuinely missing from the catalog:

      * the seven compact weekday labels;
      * five soundscape names (`Focus Music` and `Alpha Waves` were already in,
        because they happened to appear as literals elsewhere; `Wind`, `Rain`,
        `Ocean`, `Relaxing` and `Jazz` did not);
      * the goal sentence, as ONE format per unit rather than six translated
        fragments glued together;
      * the eight routine nouns that sentence slots in;
      * the compact duration units `Formatters.durationLabel` prints;
      * the flight count, as a real plural;
      * `Distractions`, the fallback for an unanswered friction question.

WEEKDAYS ARE DESIGNED, NOT COPIED

    CLDR's narrow forms are wrong for seven side-by-side buttons in four of our
    eleven languages, so they are not simply taken:

      * pt-BR narrow is D S T Q Q S S — three ambiguous pairs. Outside a
        calendar grid, where the column position disambiguates, it is unusable.
        Brazilian interfaces use the three-letter forms, and so do we.
      * hi narrow gives शु for Friday and श for Saturday — one character apart
        in a script where that character is the shared one. The abbreviated
        forms are unmistakable and still short.
      * ro narrow repeats M for Monday and... no: it gives L M M J V S D, with
        marți and miercuri colliding. Ma/Mi separates them at no cost.
      * en narrow is M T W T F S S — two T and two S. Three letters is what
        English calendars actually print.

    Where the narrow form IS the native convention it is kept exactly: es
    L M X J V S D (X for miércoles is the standard disambiguation), fr and it
    single letters, de/nl/ru two letters, zh-Hans 一 … 六 日.

THE GOAL SENTENCE

    `Goal: Build a consistent 30-minute study routine by 6 Sep 2026` used to be
    assembled in Swift from six pieces. That produces grammatical English and
    nothing else: German wants the date first, Russian wants an infinitive in
    the instrumental frame, Chinese wants the whole thing before the noun, and
    French cannot put a bare "de" in front of "étudier" without eliding it.

    So each language gets ONE format with three placeholders and writes its own
    sentence around them — including choosing what part of speech the routine
    word is. Spanish and Italian use a noun ("de estudio"), French, Russian,
    Dutch and German use a verb ("pour étudier", "учиться", "studeren", "zum
    Lernen"). The eight routine words below are therefore translated to fit
    each language's own sentence, not translated in isolation.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Compact weekday labels -------------------------------------------
    # Seven narrow buttons, semantic order Monday → Sunday. The KEY is the
    # English abbreviation; the identity is `FocusWeekday.rawValue`, which is an
    # ISO-8601 number and is what gets persisted.
    "Mon": ["一", "सोम", "L", "L", "Mo", "Пн", "Seg", "L", "L", "ma"],
    "Tue": ["二", "मंगल", "M", "M", "Di", "Вт", "Ter", "M", "Ma", "di"],
    "Wed": ["三", "बुध", "X", "M", "Mi", "Ср", "Qua", "M", "Mi", "wo"],
    "Thu": ["四", "गुरु", "J", "J", "Do", "Чт", "Qui", "G", "J", "do"],
    "Fri": ["五", "शुक्र", "V", "V", "Fr", "Пт", "Sex", "V", "V", "vr"],
    "Sat": ["六", "शनि", "S", "S", "Sa", "Сб", "Sáb", "S", "S", "za"],
    "Sun": ["日", "रवि", "D", "D", "So", "Вс", "Dom", "D", "D", "zo"],

    # ---- Soundscape names -------------------------------------------------
    # The ID stays `wind`, `rain`, `ocean`… — these are display copy only.
    "Wind": [
        "风声", "हवा", "Viento", "Vent", "Wind", "Ветер",
        "Vento", "Vento", "Vânt", "Wind",
    ],
    "Rain": [
        "雨声", "बारिश", "Lluvia", "Pluie", "Regen", "Дождь",
        "Chuva", "Pioggia", "Ploaie", "Regen",
    ],
    # Shared with the route mood of the same name below — one word, one key.
    # The plain noun rather than "waves", because it has to read as a soundscape
    # AND as the character of a journey.
    "Ocean": [
        "海洋", "समुद्र", "Océano", "Océan", "Ozean", "Океан",
        "Oceano", "Oceano", "Ocean", "Oceaan",
    ],
    "Relaxing": [
        "放松", "आराम", "Relajante", "Détente", "Entspannung", "Расслабление",
        "Relaxante", "Relax", "Relaxare", "Ontspanning",
    ],
    # A genre name. Written as it is written in every one of these languages,
    # transliterated only where the script requires it.
    "Jazz": [
        "爵士乐", "जैज़", "Jazz", "Jazz", "Jazz", "Джаз",
        "Jazz", "Jazz", "Jazz", "Jazz",
    ],

    # ---- Routine words ----------------------------------------------------
    # These slot into the goal sentence below and ONLY into it. Each language
    # supplies whatever part of speech its own sentence needs — a noun after
    # Spanish "de", an infinitive after French "pour", a German "zum …".
    "focus": [
        "专注", "फ़ोकस", "concentración", "vous concentrer", "zum Fokussieren",
        "сосредотачиваться", "foco", "concentrazione", "concentrare", "focussen",
    ],
    "work": [
        "工作", "काम", "trabajo", "travailler", "zum Arbeiten", "работать",
        "trabalho", "lavoro", "lucru", "werken",
    ],
    "study": [
        "学习", "पढ़ाई", "estudio", "étudier", "zum Lernen", "учиться",
        "estudo", "studio", "studiu", "studeren",
    ],
    "meditation": [
        "冥想", "ध्यान", "meditación", "méditer", "zum Meditieren",
        "медитировать", "meditação", "meditazione", "meditație", "mediteren",
    ],
    "exercise": [
        "运动", "कसरत", "ejercicio", "faire du sport", "für Sport",
        "тренироваться", "exercício", "allenamento", "mișcare", "sporten",
    ],
    "reading": [
        "阅读", "पढ़ना", "lectura", "lire", "zum Lesen", "читать",
        "leitura", "lettura", "citit", "lezen",
    ],
    "creative work": [
        "创作", "रचनात्मक काम", "trabajo creativo", "créer", "für kreative Arbeit",
        "заниматься творчеством", "trabalho criativo", "lavoro creativo",
        "lucru creativ", "creatief werken",
    ],
    "reflection": [
        "反思", "चिंतन", "reflexión", "réfléchir", "zum Nachdenken",
        "размышлять", "reflexão", "riflessione", "reflecție", "reflecteren",
    ],

    # ---- Compact duration units -------------------------------------------
    # What `Formatters.durationLabel` prints. Abbreviations, so they do not
    # inflect and need no plural — but "min" is not a word in every script, and
    # 30 min under a Chinese interface was as wrong as MINUTES under a Spanish
    # one.
    "%lld min": [
        "%lld 分钟", "%lld मिनट", "%lld min", "%lld min", "%lld Min.",
        "%lld мин", "%lld min", "%lld min", "%lld min", "%lld min",
    ],
    "%lldh": [
        "%lld 小时", "%lld घं", "%lldh", "%lldh", "%lldh", "%lldч",
        "%lldh", "%lldh", "%lldh", "%lldu",
    ],
    "%lldh %lldm": [
        "%lld 小时 %lld 分", "%lld घं %lld मि", "%lldh %lldm", "%lldh %lldm",
        "%lldh %lldm", "%lldч %lldмин", "%lldh %lldm", "%lldh %lldm",
        "%lldh %lldm", "%lldu %lldm",
    ],

    # ---- Route moods and duration buckets ---------------------------------
    # Found while sweeping for the same defect: `AppRouteCard` printed
    # `route.mood.displayName` through `Text(_:)` and `AppTagChip` looked
    # `route.category.displayName` up as a key that had never been written. Both
    # are on the screen a pilot reaches immediately after this first run, so
    # Sunrise · Deep · 45–90 min sat in English next to translated everything.
    #
    # One word each, on a narrow chip: the character of a journey and how long
    # it is. `Ocean` is above, shared with the soundscape.
    "Sunrise": [
        "日出", "सूर्योदय", "Amanecer", "Lever de soleil", "Sonnenaufgang",
        "Рассвет", "Amanhecer", "Alba", "Răsărit", "Zonsopgang",
    ],
    "Sunset": [
        "日落", "सूर्यास्त", "Atardecer", "Coucher de soleil", "Sonnenuntergang",
        "Закат", "Pôr do sol", "Tramonto", "Apus", "Zonsondergang",
    ],
    "Night": [
        "夜晚", "रात", "Noche", "Nuit", "Nacht", "Ночь",
        "Noite", "Notte", "Noapte", "Nacht",
    ],
    "Aurora": [
        "极光", "अरोरा", "Aurora", "Aurore", "Polarlicht", "Северное сияние",
        "Aurora", "Aurora", "Auroră", "Poollicht",
    ],
    "Mountains": [
        "群山", "पहाड़", "Montañas", "Montagnes", "Berge", "Горы",
        "Montanhas", "Montagne", "Munți", "Bergen",
    ],
    "City": [
        "城市", "शहर", "Ciudad", "Ville", "Stadt", "Город",
        "Cidade", "Città", "Oraș", "Stad",
    ],
    "Calm": [
        "静谧", "शांत", "Calma", "Calme", "Ruhe", "Спокойствие",
        "Calmaria", "Calma", "Calm", "Kalmte",
    ],
    "Clouds": [
        "云海", "बादल", "Nubes", "Nuages", "Wolken", "Облака",
        "Nuvens", "Nuvole", "Nori", "Wolken",
    ],
    "Short": [
        "短途", "छोटी", "Corto", "Court", "Kurz", "Короткий",
        "Curto", "Breve", "Scurt", "Kort",
    ],
    "Deep": [
        "深度", "गहरी", "Profundo", "Profond", "Tief", "Глубокий",
        "Profundo", "Profondo", "Profund", "Diep",
    ],
    "Long": [
        "长途", "लंबी", "Largo", "Long", "Lang", "Длинный",
        "Longo", "Lungo", "Lung", "Lang",
    ],
    "Grand": [
        "远征", "भव्य", "Épico", "Grand", "Groß", "Большой",
        "Épico", "Epico", "Măreț", "Groots",
    ],

    # ---- The unanswered-friction fallback ---------------------------------
    "Distractions": [
        "干扰", "ध्यान भटकाव", "Distracciones", "Distractions", "Ablenkungen",
        "Отвлечения", "Distrações", "Distrazioni", "Distrageri", "Afleidingen",
    ],
}


# key -> {locale: {category: value}}. `other` is mandatory; iOS falls back to it
# for any category a language does not declare.
PLURALS: dict[str, dict[str, dict[str, str]]] = {

    # The chart's target callout. Was `"\(n) \(n == 1 ? "flight" : "flights")"`
    # in Swift — English grammar, hardcoded, in a string nobody could translate.
    "%lld flights": {
        "en":      {"one": "%lld flight", "other": "%lld flights"},
        "zh-Hans": {"other": "%lld 次飞行"},
        "hi":      {"one": "%lld फ़्लाइट", "other": "%lld फ़्लाइट"},
        "es":      {"one": "%lld vuelo", "other": "%lld vuelos"},
        "fr":      {"one": "%lld vol", "other": "%lld vols"},
        "de":      {"one": "%lld Flug", "other": "%lld Flüge"},
        "ru":      {"one": "%lld полёт", "few": "%lld полёта",
                    "many": "%lld полётов", "other": "%lld полёта"},
        "pt-BR":   {"one": "%lld voo", "other": "%lld voos"},
        "it":      {"one": "%lld volo", "other": "%lld voli"},
        "ro":      {"one": "%lld zbor", "few": "%lld zboruri",
                    "other": "%lld de zboruri"},
        "nl":      {"one": "%lld vlucht", "other": "%lld vluchten"},
    },

    # THE goal sentence, minutes. Three placeholders, one per variable:
    #   %1$lld  the session length
    #   %2$@    the routine word, from the table above
    #   %3$@    the target date, already formatted in this language
    # Every language owns its own order. Romanian needs all three categories
    # because 20 and above takes "de minute"; Russian needs four.
    "Goal: Build a consistent %1$lld-minute %2$@ routine by %3$@": {
        "en": {
            "one": "Goal: Build a consistent %1$lld-minute %2$@ routine by %3$@",
            "other": "Goal: Build a consistent %1$lld-minute %2$@ routine by %3$@",
        },
        "zh-Hans": {
            "other": "目标：在 %3$@ 之前养成每次 %1$lld 分钟的%2$@习惯",
        },
        "hi": {
            "one": "लक्ष्य: %3$@ तक हर बार %1$lld मिनट %2$@ की नियमित आदत बनाएँ",
            "other": "लक्ष्य: %3$@ तक हर बार %1$lld मिनट %2$@ की नियमित आदत बनाएँ",
        },
        "es": {
            "one": "Objetivo: Crear una rutina constante de %2$@ de %1$lld minuto antes del %3$@",
            "other": "Objetivo: Crear una rutina constante de %2$@ de %1$lld minutos antes del %3$@",
        },
        "fr": {
            "one": "Objectif : une routine de %1$lld minute pour %2$@, d'ici le %3$@",
            "other": "Objectif : une routine de %1$lld minutes pour %2$@, d'ici le %3$@",
        },
        "de": {
            "one": "Ziel: bis zum %3$@ eine feste Routine von %1$lld Minute %2$@ aufbauen",
            "other": "Ziel: bis zum %3$@ eine feste Routine von %1$lld Minuten %2$@ aufbauen",
        },
        "ru": {
            "one": "Цель: к %3$@ выработать привычку %2$@ по %1$lld минуте",
            "few": "Цель: к %3$@ выработать привычку %2$@ по %1$lld минуты",
            "many": "Цель: к %3$@ выработать привычку %2$@ по %1$lld минут",
            "other": "Цель: к %3$@ выработать привычку %2$@ по %1$lld минуты",
        },
        "pt-BR": {
            "one": "Objetivo: criar uma rotina constante de %2$@ de %1$lld minuto até %3$@",
            "other": "Objetivo: criar uma rotina constante de %2$@ de %1$lld minutos até %3$@",
        },
        "it": {
            "one": "Obiettivo: creare una routine costante di %2$@ da %1$lld minuto entro il %3$@",
            "other": "Obiettivo: creare una routine costante di %2$@ da %1$lld minuti entro il %3$@",
        },
        "ro": {
            "one": "Obiectiv: creează o rutină constantă de %2$@ de %1$lld minut până pe %3$@",
            "few": "Obiectiv: creează o rutină constantă de %2$@ de %1$lld minute până pe %3$@",
            "other": "Obiectiv: creează o rutină constantă de %2$@ de %1$lld de minute până pe %3$@",
        },
        "nl": {
            "one": "Doel: een vaste routine van %1$lld minuut %2$@ vóór %3$@",
            "other": "Doel: een vaste routine van %1$lld minuten %2$@ vóór %3$@",
        },
    },

    # The same sentence in whole hours. A separate key rather than a second
    # placeholder for the unit, because "1-hour" and "2-hour" inflect
    # differently from minutes in most of these languages and a shared unit
    # slot would force every translation back into fragments.
    "Goal: Build a consistent %1$lld-hour %2$@ routine by %3$@": {
        "en": {
            "one": "Goal: Build a consistent %1$lld-hour %2$@ routine by %3$@",
            "other": "Goal: Build a consistent %1$lld-hour %2$@ routine by %3$@",
        },
        "zh-Hans": {
            "other": "目标：在 %3$@ 之前养成每次 %1$lld 小时的%2$@习惯",
        },
        "hi": {
            "one": "लक्ष्य: %3$@ तक हर बार %1$lld घंटा %2$@ की नियमित आदत बनाएँ",
            "other": "लक्ष्य: %3$@ तक हर बार %1$lld घंटे %2$@ की नियमित आदत बनाएँ",
        },
        "es": {
            "one": "Objetivo: Crear una rutina constante de %2$@ de %1$lld hora antes del %3$@",
            "other": "Objetivo: Crear una rutina constante de %2$@ de %1$lld horas antes del %3$@",
        },
        "fr": {
            "one": "Objectif : une routine de %1$lld heure pour %2$@, d'ici le %3$@",
            "other": "Objectif : une routine de %1$lld heures pour %2$@, d'ici le %3$@",
        },
        "de": {
            "one": "Ziel: bis zum %3$@ eine feste Routine von %1$lld Stunde %2$@ aufbauen",
            "other": "Ziel: bis zum %3$@ eine feste Routine von %1$lld Stunden %2$@ aufbauen",
        },
        "ru": {
            "one": "Цель: к %3$@ выработать привычку %2$@ по %1$lld часу",
            "few": "Цель: к %3$@ выработать привычку %2$@ по %1$lld часа",
            "many": "Цель: к %3$@ выработать привычку %2$@ по %1$lld часов",
            "other": "Цель: к %3$@ выработать привычку %2$@ по %1$lld часа",
        },
        "pt-BR": {
            "one": "Objetivo: criar uma rotina constante de %2$@ de %1$lld hora até %3$@",
            "other": "Objetivo: criar uma rotina constante de %2$@ de %1$lld horas até %3$@",
        },
        "it": {
            "one": "Obiettivo: creare una routine costante di %2$@ da %1$lld ora entro il %3$@",
            "other": "Obiettivo: creare una routine costante di %2$@ da %1$lld ore entro il %3$@",
        },
        "ro": {
            "one": "Obiectiv: creează o rutină constantă de %2$@ de %1$lld oră până pe %3$@",
            "few": "Obiectiv: creează o rutină constantă de %2$@ de %1$lld ore până pe %3$@",
            "other": "Obiectiv: creează o rutină constantă de %2$@ de %1$lld de ore până pe %3$@",
        },
        "nl": {
            "one": "Doel: een vaste routine van %1$lld uur %2$@ vóór %3$@",
            "other": "Doel: een vaste routine van %1$lld uur %2$@ vóór %3$@",
        },
    },
}


COMMENTS: dict[str, str] = {
    "Mon": "Weekday button, Monday. SEVEN NARROW BUTTONS side by side, semantic "
           "order Mon→Sun. Use the shortest form a native reader recognises "
           "instantly — a single letter where your language's calendars use "
           "one, two or three where they do not.",
    "Tue": "Weekday button, Tuesday. See 'Mon'.",
    "Wed": "Weekday button, Wednesday. See 'Mon'.",
    "Thu": "Weekday button, Thursday. See 'Mon'.",
    "Fri": "Weekday button, Friday. See 'Mon'.",
    "Sat": "Weekday button, Saturday. See 'Mon'.",
    "Sun": "Weekday button, Sunday. See 'Mon'.",

    "Wind": "Soundscape name — moving air, the free default ambience. Not the "
            "verb, and never the file name.",
    "Rain": "Soundscape name — rain against the cabin window.",
    "Ocean": "Soundscape name — waves.",
    "Relaxing": "Soundscape name — calm, unspecific ambience.",
    "Jazz": "Soundscape name — the music genre.",

    "focus": "Slots into the goal sentence in place of %2$@. Use whatever part "
             "of speech YOUR sentence needs. Generic focus, the answer of "
             "someone who picked 'Fly'.",
    "work": "Goal-sentence slot (%2$@): work.",
    "study": "Goal-sentence slot (%2$@): studying.",
    "meditation": "Goal-sentence slot (%2$@): meditating.",
    "exercise": "Goal-sentence slot (%2$@): physical exercise.",
    "reading": "Goal-sentence slot (%2$@): reading.",
    "creative work": "Goal-sentence slot (%2$@): making something.",
    "reflection": "Goal-sentence slot (%2$@): thinking things over.",

    "%lld min": "Compact session length, e.g. under 60 minutes. Abbreviate the "
                "way a clock or timer does in your language.",
    "%lldh": "Compact session length, whole hours.",
    "%lldh %lldm": "Compact session length, hours and minutes.",

    "%lld flights": "The plan's target: how many focus flights the pilot's own "
                    "schedule adds up to over four weeks.",

    "Goal: Build a consistent %1$lld-minute %2$@ routine by %3$@":
        "The whole results screen in one line. %1$lld is the session length, "
        "%2$@ the routine word (see 'study', 'reading'…), %3$@ the target date, "
        "already formatted for your language. Reorder freely — this is one "
        "sentence, not six fragments.",
    "Goal: Build a consistent %1$lld-hour %2$@ routine by %3$@":
        "As the minutes variant, for whole hours.",

    "Distractions": "Shown as the Main distraction value when the pilot skipped "
                    "the question. A plural noun, not a sentence.",

    "Sunrise": "The character of a journey, on a narrow chip beside its "
               "distance. A time of day, not an action.",
    "Sunset": "Journey character chip. See 'Sunrise'.",
    "Night": "Journey character chip. See 'Sunrise'.",
    "Aurora": "Journey character chip — the northern lights.",
    "Ocean": "Soundscape name AND journey character chip: the sea. One word "
             "serves both.",
    "Mountains": "Journey character chip.",
    "City": "Journey character chip.",
    "Calm": "Journey character chip — stillness. A noun, not 'stay calm'.",
    "Clouds": "Journey character chip.",
    "Short": "Duration bucket for a journey, roughly 30 minutes. An adjective "
             "describing the flight.",
    "Deep": "Duration bucket, 45–90 minutes.",
    "Long": "Duration bucket, 2–4 hours.",
    "Grand": "Duration bucket, 6–12 hours — the Grand Expedition. Use a word "
             "that sounds like a major undertaking, not merely 'big'.",
}
