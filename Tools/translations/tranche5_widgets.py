"""Tranche 5b — the widgets, in the widget extension's own catalog.

The widget extension is a separate process with its own bundle, so its strings
cannot live in the app's catalog. Several keys here deliberately repeat keys the
app also has ("Passport", "Resume"): each bundle needs its own copy, and the
glossary keeps both spellings identical.

TWO CONSTRAINTS SHAPED THE WORDING
  * Widget tiles are tiny and clip rather than wrap. Captions and eyebrows are
    kept at or below the English length wherever a language allows it; German
    and Russian compounds were shortened rather than left to be truncated by
    `minimumScaleFactor`.
  * Widget gallery entries (`configurationDisplayName`, `.description`) are
    composed by the system widget picker in the DEVICE's language — the one
    surface FocusGlobe's own language choice cannot reach. They are translated
    anyway, so a Spanish phone lists a Spanish widget.
"""

CATALOG = "widgets"

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Widget gallery ---------------------------------------------------
    "Focus Now": [
        "立即专注", "अभी फ़ोकस", "Concéntrate ya", "Concentration immédiate",
        "Jetzt fokussieren", "Фокус сейчас", "Foco agora", "Concentrati ora",
        "Concentrare acum", "Nu focussen",
    ],
    "Start a focus flight, or watch the one you're on.": [
        "开始一次专注飞行，或查看进行中的飞行。",
        "एक फ़ोकस फ़्लाइट शुरू करें, या चल रही फ़्लाइट देखें।",
        "Empieza un vuelo de concentración o mira el que ya tienes en curso.",
        "Lancez un vol de concentration, ou suivez celui en cours.",
        "Starte einen Fokus-Flug oder verfolge den laufenden.",
        "Начните полёт фокуса или следите за текущим.",
        "Comece um voo de foco ou acompanhe o que está em andamento.",
        "Avvia un volo di concentrazione o segui quello in corso.",
        "Începe un zbor de concentrare sau urmărește-l pe cel curent.",
        "Start een focusvlucht of volg de vlucht waarin je zit.",
    ],
    "Focus Grid": [
        "专注格子", "फ़ोकस ग्रिड", "Cuadrícula de concentración",
        "Grille de concentration", "Fokus-Raster", "Сетка фокуса",
        "Grade de foco", "Griglia di concentrazione", "Grilă de concentrare",
        "Focusraster",
    ],
    "Your last six months of focus days. FocusGlobe PRO.": [
        "你最近六个月的专注日。FocusGlobe PRO。",
        "आपके पिछले छह महीनों के फ़ोकस दिन। FocusGlobe PRO।",
        "Tus días de concentración de los últimos seis meses. FocusGlobe PRO.",
        "Vos jours de concentration des six derniers mois. FocusGlobe PRO.",
        "Deine Fokus-Tage der letzten sechs Monate. FocusGlobe PRO.",
        "Ваши дни фокуса за последние полгода. FocusGlobe PRO.",
        "Seus dias de foco dos últimos seis meses. FocusGlobe PRO.",
        "Le tue giornate di concentrazione degli ultimi sei mesi. FocusGlobe PRO.",
        "Zilele tale de concentrare din ultimele șase luni. FocusGlobe PRO.",
        "Je focusdagen van de afgelopen zes maanden. FocusGlobe PRO.",
    ],
    "Passport Dashboard": [
        "护照总览", "पासपोर्ट डैशबोर्ड", "Panel del Pasaporte",
        "Tableau de bord Passeport", "Reisepass-Übersicht", "Панель Паспорта",
        "Painel do Passaporte", "Pannello Passaporto", "Panoul Pașaportului",
        "Paspoortoverzicht",
    ],
    "Your journeys, focused time, streaks and badges. FocusGlobe PRO.": [
        "你的旅程、专注时间、连续天数与徽章。FocusGlobe PRO。",
        "आपकी यात्राएँ, फ़ोकस समय, स्ट्रीक और बैज। FocusGlobe PRO।",
        "Tus viajes, tiempo concentrado, rachas e insignias. FocusGlobe PRO.",
        "Vos voyages, votre temps de concentration, vos séries et vos badges. FocusGlobe PRO.",
        "Deine Reisen, Fokuszeit, Serien und Abzeichen. FocusGlobe PRO.",
        "Ваши путешествия, время фокуса, серии и значки. FocusGlobe PRO.",
        "Suas viagens, tempo de foco, sequências e medalhas. FocusGlobe PRO.",
        "I tuoi viaggi, il tempo di concentrazione, le serie e i badge. FocusGlobe PRO.",
        "Călătoriile, timpul de concentrare, seriile și insignele tale. FocusGlobe PRO.",
        "Je reizen, focustijd, reeksen en badges. FocusGlobe PRO.",
    ],
    "Streak Companion": [
        "连续天数伙伴", "स्ट्रीक साथी", "Compañero de racha",
        "Compagnon de série", "Serien-Begleiter", "Спутник серии",
        "Companheiro de sequência", "Compagno della serie", "Însoțitorul seriei",
        "Reeksmaatje",
    ],
    "Keep your focus streak alive with your balloon companion.": [
        "和你的热气球伙伴一起延续专注连续天数。",
        "अपने ग़ुब्बारा साथी के साथ फ़ोकस स्ट्रीक बनाए रखें।",
        "Mantén viva tu racha de concentración con tu globo compañero.",
        "Faites vivre votre série de concentration avec votre montgolfière.",
        "Halte deine Fokus-Serie mit deinem Ballon-Begleiter am Leben.",
        "Поддерживайте серию фокуса вместе со своим шаром-спутником.",
        "Mantenha sua sequência de foco viva com seu balão companheiro.",
        "Tieni viva la tua serie di concentrazione con la tua mongolfiera.",
        "Ține-ți vie seria de concentrare cu balonul tău însoțitor.",
        "Houd je focusreeks levend met je ballonmaatje.",
    ],

    # ---- Focus Now --------------------------------------------------------
    "IN FLIGHT": [
        "飞行中", "उड़ान में", "EN VUELO", "EN VOL", "IM FLUG", "В ПОЛЁТЕ",
        "EM VOO", "IN VOLO", "ÎN ZBOR", "ONDERWEG",
    ],
    "FOCUS NOW": [
        "立即专注", "अभी फ़ोकस", "CONCÉNTRATE", "CONCENTREZ-VOUS",
        "JETZT FOKUS", "ФОКУС", "FOQUE AGORA", "CONCENTRATI", "CONCENTREAZĂ-TE",
        "NU FOCUSSEN",
    ],
    "Focus": [
        "专注", "फ़ोकस", "Concentración", "Concentration", "Fokus", "Фокус",
        "Foco", "Concentrazione", "Concentrare", "Focus",
    ],
    "Ready to focus": [
        "准备专注", "फ़ोकस के लिए तैयार", "Todo listo",
        "Tout est prêt", "Bereit für den Fokus", "Готовы к фокусу",
        "Tudo pronto", "Tutto pronto", "Gata de concentrare",
        "Klaar om te focussen",
    ],
    "Resume": [
        "继续", "जारी रखें", "Reanudar", "Reprendre", "Fortsetzen",
        "Продолжить", "Retomar", "Riprendi", "Reia", "Hervatten",
    ],
    "Start Focus": [
        "开始专注", "फ़ोकस शुरू करें", "Empezar", "Démarrer", "Fokus starten",
        "Начать фокус", "Começar foco", "Inizia", "Începe", "Start focus",
    ],
    "Start": [
        "开始", "शुरू", "Empezar", "Démarrer", "Start", "Начать", "Começar",
        "Inizia", "Începe", "Start",
    ],
    "Your flight is ready to continue.": [
        "你的飞行可以继续了。", "आपकी फ़्लाइट जारी रखने के लिए तैयार है।",
        "Tu vuelo está listo para continuar.", "Votre vol est prêt à reprendre.",
        "Dein Flug kann fortgesetzt werden.", "Ваш полёт готов продолжиться.",
        "Seu voo está pronto para continuar.", "Il tuo volo è pronto a riprendere.",
        "Zborul tău e gata să continue.", "Je vlucht kan verder.",
    ],
    "A quiet flight is one tap away.": [
        "一次轻点，开启宁静飞行。", "एक टैप में शांत फ़्लाइट।",
        "Un vuelo tranquilo a un toque.", "Un vol paisible en un seul geste.",
        "Ein ruhiger Flug ist einen Tipp entfernt.",
        "Тихий полёт — в одно касание.", "Um voo tranquilo a um toque.",
        "Un volo tranquillo a un tocco.", "Un zbor liniștit la o atingere.",
        "Een rustige vlucht is één tik weg.",
    ],

    # ---- Focus Grid -------------------------------------------------------
    "Focus · 6 months": [
        "专注 · 6 个月", "फ़ोकस · 6 महीने", "Concentración · 6 meses",
        "Concentration · 6 mois", "Fokus · 6 Monate", "Фокус · 6 месяцев",
        "Foco · 6 meses", "Concentrazione · 6 mesi", "Concentrare · 6 luni",
        "Focus · 6 maanden",
    ],

    # ---- Passport dashboard ----------------------------------------------
    "Passport Stats": [
        "护照统计", "पासपोर्ट आँकड़े", "Datos del Pasaporte",
        "Statistiques du Passeport", "Reisepass-Statistik", "Статистика Паспорта",
        "Dados do Passaporte", "Statistiche Passaporto", "Statistici Pașaport",
        "Paspoortcijfers",
    ],
    "Passport": [
        "护照", "पासपोर्ट", "Pasaporte", "Passeport", "Reisepass", "Паспорт",
        "Passaporte", "Passaporto", "Pașaport", "Paspoort",
    ],
    "FocusGlobe Passport": [
        "FocusGlobe 护照", "FocusGlobe पासपोर्ट", "Pasaporte FocusGlobe",
        "Passeport FocusGlobe", "FocusGlobe Reisepass", "Паспорт FocusGlobe",
        "Passaporte FocusGlobe", "Passaporto FocusGlobe", "Pașaport FocusGlobe",
        "FocusGlobe Paspoort",
    ],
    "Badges": [
        "徽章", "बैज", "Insignias", "Badges", "Abzeichen", "Значки",
        "Medalhas", "Badge", "Insigne", "Badges",
    ],
    # Compact stat captions. These render UPPERCASED in a ~50 pt column, so
    # every one is kept short enough to survive without shrinking.
    "journeys": [
        "旅程", "यात्राएँ", "viajes", "voyages", "Reisen", "поездки",
        "viagens", "viaggi", "călătorii", "reizen",
    ],
    "focused": [
        "专注时长", "फ़ोकस", "concentración", "concentration", "Fokuszeit",
        "фокус", "foco", "concentrazione", "concentrare", "focustijd",
    ],
    "day streak": [
        "连续天数", "दिन स्ट्रीक", "racha", "série", "Serie", "серия",
        "sequência", "serie", "serie", "reeks",
    ],
    "focus days": [
        "专注日", "फ़ोकस दिन", "días", "jours", "Tage", "дни",
        "dias", "giorni", "zile", "dagen",
    ],
    "streak": [
        "连续天数", "स्ट्रीक", "racha", "série", "Serie", "серия",
        "sequência", "serie", "serie", "reeks",
    ],
    "best streak": [
        "最佳连续", "बेस्ट स्ट्रीक", "mejor racha", "meilleure série",
        "Beste Serie", "рекорд", "recorde", "record", "record", "beste reeks",
    ],
    "longest": [
        "最长", "सबसे लंबा", "más larga", "plus longue", "längste", "дольше всего",
        "mais longa", "più lunga", "cea mai lungă", "langste",
    ],
    # Compact durations. The digits are the number; only the unit is translated.
    "%lldm": [
        "%lld 分", "%lld मि", "%lld min", "%lld min", "%lld Min", "%lld мин",
        "%lld min", "%lld min", "%lld min", "%lld min",
    ],
    "%lldh %@m": [
        "%lld 时 %@ 分", "%lld घं %@ मि", "%lld h %@ min", "%lld h %@ min",
        "%lld Std %@ Min", "%lld ч %@ мин", "%lld h %@ min", "%lld h %@ min",
        "%lld h %@ min", "%lld u %@ min",
    ],

    # ---- Streak companion -------------------------------------------------
    "Start your streak": [
        "开启连续天数", "अपनी स्ट्रीक शुरू करें", "Empieza tu racha",
        "Lancez votre série", "Starte deine Serie", "Начните серию",
        "Comece sua sequência", "Inizia la tua serie", "Începe-ți seria",
        "Begin je reeks",
    ],
    "Focused today": [
        "今天已专注", "आज फ़ोकस किया", "Concentración hoy",
        "Concentration aujourd’hui", "Heute fokussiert", "Сегодня в фокусе",
        "Foco hoje", "Concentrazione oggi", "Concentrare azi", "Vandaag gefocust",
    ],
    "Focus to keep it": [
        "专注以保持", "बनाए रखने के लिए फ़ोकस करें", "Concéntrate para mantenerla",
        "Concentrez-vous pour la garder", "Fokussiere, um sie zu halten",
        "Сфокусируйтесь, чтобы сохранить", "Foque para mantê-la",
        "Concentrati per mantenerla", "Concentrează-te ca s-o păstrezi",
        "Focus om je reeks te behouden",
    ],
    "Milestone! 🎉": [
        "里程碑！🎉", "मील का पत्थर! 🎉", "¡Hito! 🎉", "Cap franchi ! 🎉",
        "Meilenstein! 🎉", "Рубеж! 🎉", "Marco! 🎉", "Traguardo! 🎉",
        "Bornă atinsă! 🎉", "Mijlpaal! 🎉",
    ],
    # VoiceOver: "<streak>. <state line>." Both parts arrive translated.
    "%@. %@.": [
        "%@。%@。", "%@। %@।", "%@. %@.", "%@. %@.", "%@. %@.", "%@. %@.",
        "%@. %@.", "%@. %@.", "%@. %@.", "%@. %@.",
    ],

    # ---- Locked (non-PRO) tiles ------------------------------------------
    "Unlock with FocusGlobe Pro": [
        "使用 FocusGlobe Pro 解锁", "FocusGlobe Pro से अनलॉक करें",
        "Desbloquea con FocusGlobe Pro", "Débloquez avec FocusGlobe Pro",
        "Mit FocusGlobe Pro freischalten", "Разблокируйте с FocusGlobe Pro",
        "Desbloqueie com o FocusGlobe Pro", "Sblocca con FocusGlobe Pro",
        "Deblochează cu FocusGlobe Pro", "Ontgrendel met FocusGlobe Pro",
    ],
}


# key -> locale -> CLDR plural category -> value
PLURALS: dict[str, dict[str, dict[str, str]]] = {
    "%lld focus days": {
        "en":      {"one": "%lld focus day", "other": "%lld focus days"},
        "zh-Hans": {"other": "%lld 个专注日"},
        "hi":      {"one": "%lld फ़ोकस दिन", "other": "%lld फ़ोकस दिन"},
        "es":      {"one": "%lld día de concentración",
                    "other": "%lld días de concentración"},
        "fr":      {"one": "%lld jour de concentration",
                    "other": "%lld jours de concentration"},
        "de":      {"one": "%lld Fokus-Tag", "other": "%lld Fokus-Tage"},
        "ru":      {"one": "%lld день фокуса", "few": "%lld дня фокуса",
                    "many": "%lld дней фокуса", "other": "%lld дня фокуса"},
        "pt-BR":   {"one": "%lld dia de foco", "other": "%lld dias de foco"},
        "it":      {"one": "%lld giorno di concentrazione",
                    "other": "%lld giorni di concentrazione"},
        "ro":      {"one": "%lld zi de concentrare",
                    "few": "%lld zile de concentrare",
                    "other": "%lld de zile de concentrare"},
        "nl":      {"one": "%lld focusdag", "other": "%lld focusdagen"},
    },
    "%lld-day streak": {
        "en":      {"one": "%lld-day streak", "other": "%lld-day streak"},
        "zh-Hans": {"other": "连续 %lld 天"},
        "hi":      {"one": "%lld दिन की स्ट्रीक", "other": "%lld दिन की स्ट्रीक"},
        "es":      {"one": "racha de %lld día", "other": "racha de %lld días"},
        "fr":      {"one": "série de %lld jour", "other": "série de %lld jours"},
        "de":      {"one": "%lld-Tag-Serie", "other": "%lld-Tage-Serie"},
        "ru":      {"one": "%lld день подряд", "few": "%lld дня подряд",
                    "many": "%lld дней подряд", "other": "%lld дня подряд"},
        "pt-BR":   {"one": "sequência de %lld dia",
                    "other": "sequência de %lld dias"},
        "it":      {"one": "serie di %lld giorno", "other": "serie di %lld giorni"},
        "ro":      {"one": "serie de %lld zi", "few": "serie de %lld zile",
                    "other": "serie de %lld de zile"},
        "nl":      {"one": "reeks van %lld dag", "other": "reeks van %lld dagen"},
    },
}
