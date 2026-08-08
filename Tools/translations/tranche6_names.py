"""Tranche 6h — single-word names and the Sky-unlock sentences.

The single-word entries here were the last blind spot: an earlier sweep only
looked at literals containing a space, which hid every one-word tab title,
preset, skin and settings section. They are found now by scanning display
FIELDS (`name:`, `title:`, `detail:`, …) instead of by shape.

Glossary terms appear here in their canonical form and nowhere else in a
different one: Passport, Friends, Solo, Online, Flights, Coins.

The four Sky-unlock sentences carry a NUMBER (friends to invite, minutes to
focus, days of streak) and a Sky name, so each is pluralised per language with
the Sky name as an argument — never concatenated.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Tab bar ----------------------------------------------------------
    "Home": [
        "首页", "होम", "Inicio", "Accueil", "Start", "Главная",
        "Início", "Home", "Acasă", "Start",
    ],
    "Shop": [
        "商店", "स्टोर", "Tienda", "Boutique", "Store", "Магазин",
        "Loja", "Negozio", "Magazin", "Winkel",
    ],
    "Friends": [
        "好友", "दोस्त", "Amigos", "Amis", "Freunde", "Друзья",
        "Amigos", "Amici", "Prieteni", "Vrienden",
    ],
    "Settings": [
        "设置", "सेटिंग्स", "Ajustes", "Réglages", "Einstellungen", "Настройки",
        "Ajustes", "Impostazioni", "Setări", "Instellingen",
    ],
    "Passport": [
        "护照", "पासपोर्ट", "Pasaporte", "Passeport", "Reisepass", "Паспорт",
        "Passaporte", "Passaporto", "Pașaport", "Paspoort",
    ],
    "History": [
        "历史", "इतिहास", "Historial", "Historique", "Verlauf", "История",
        "Histórico", "Cronologia", "Istoric", "Geschiedenis",
    ],

    # ---- Flight modes -----------------------------------------------------
    "Solo": [
        "单人", "अकेले", "Solo", "Solo", "Solo", "Соло",
        "Solo", "Solo", "Solo", "Solo",
    ],
    "Online": [
        "在线", "ऑनलाइन", "Online", "En ligne", "Online", "Онлайн",
        "Online", "Online", "Online", "Online",
    ],
    "Private": [
        "私人", "निजी", "Privado", "Privé", "Privat", "Приватный",
        "Privado", "Privato", "Privat", "Privé",
    ],

    # ---- Focus presets ----------------------------------------------------
    "Work": [
        "工作", "काम", "Trabajo", "Travail", "Arbeit", "Работа",
        "Trabalho", "Lavoro", "Muncă", "Werk",
    ],
    "Study": [
        "学习", "पढ़ाई", "Estudio", "Études", "Lernen", "Учёба",
        "Estudo", "Studio", "Studiu", "Studeren",
    ],
    "Read": [
        "阅读", "पढ़ना", "Lectura", "Lecture", "Lesen", "Чтение",
        "Leitura", "Lettura", "Citit", "Lezen",
    ],
    "Create": [
        "创作", "रचना", "Creación", "Création", "Erschaffen", "Творчество",
        "Criação", "Creazione", "Creație", "Creëren",
    ],
    "Meditate": [
        "冥想", "ध्यान", "Meditación", "Méditation", "Meditieren", "Медитация",
        "Meditação", "Meditazione", "Meditație", "Mediteren",
    ],
    "Exercise": [
        "运动", "व्यायाम", "Ejercicio", "Sport", "Bewegung", "Тренировка",
        "Exercício", "Esercizio", "Mișcare", "Beweging",
    ],
    "Fly": [
        "飞行", "उड़ान", "Vuelo", "Vol", "Fliegen", "Полёт",
        "Voo", "Volo", "Zbor", "Vliegen",
    ],

    # ---- Balloon skins and vehicles ---------------------------------------
    "Default": [
        "默认", "डिफ़ॉल्ट", "Predeterminado", "Par défaut", "Standard",
        "По умолчанию", "Padrão", "Predefinito", "Implicit", "Standaard",
    ],
    "Balloon": [
        "气球", "ग़ुब्बारा", "Globo", "Montgolfière", "Ballon", "Шар",
        "Balão", "Mongolfiera", "Balon", "Ballon",
    ],
    "Cloudy": [
        "多云", "बादल", "Nublado", "Nuageux", "Wolkig", "Облачный",
        "Nublado", "Nuvoloso", "Înnorat", "Bewolkt",
    ],
    "Earth": [
        "地球", "पृथ्वी", "Tierra", "Terre", "Erde", "Земля",
        "Terra", "Terra", "Pământ", "Aarde",
    ],
    "Emoji": [
        "表情", "इमोजी", "Emoji", "Émoji", "Emoji", "Эмодзи",
        "Emoji", "Emoji", "Emoji", "Emoji",
    ],
    "Galaxy": [
        "星系", "आकाशगंगा", "Galaxia", "Galaxie", "Galaxie", "Галактика",
        "Galáxia", "Galassia", "Galaxie", "Melkweg",
    ],
    "King": [
        "国王", "किंग", "Rey", "Roi", "König", "Король",
        "Rei", "Re", "Rege", "Koning",
    ],
    "Marshmallow": [
        "棉花糖", "मार्शमैलो", "Nube de azúcar", "Guimauve", "Marshmallow",
        "Маршмеллоу", "Marshmallow", "Marshmallow", "Bezea", "Marshmallow",
    ],
    "Moon": [
        "月亮", "चाँद", "Luna", "Lune", "Mond", "Луна",
        "Lua", "Luna", "Lună", "Maan",
    ],
    "Cloudship": [
        "云舟", "क्लाउडशिप", "Nave nube", "Nef des nuages", "Wolkenschiff",
        "Облачный корабль", "Nave das nuvens", "Nave delle nuvole",
        "Corabia norilor", "Wolkenschip",
    ],
    "Starfield": [
        "星场", "तारामंडल", "Campo estelar", "Champ d’étoiles",
        "Sternenfeld", "Звёздное поле", "Campo estelar", "Campo stellare",
        "Câmp stelar", "Sterrenveld",
    ],

    # ---- Cabin items (single-word) ----------------------------------------
    "Notebook": [
        "笔记本", "नोटबुक", "Cuaderno", "Carnet", "Notizbuch", "Блокнот",
        "Caderno", "Quaderno", "Caiet", "Notitieboek",
    ],
    "Headphones": [
        "耳机", "हेडफ़ोन", "Auriculares", "Casque", "Kopfhörer", "Наушники",
        "Fones de ouvido", "Cuffie", "Căști", "Koptelefoon",
    ],

    # ---- Settings sections ------------------------------------------------
    "Account": [
        "账户", "अकाउंट", "Cuenta", "Compte", "Konto", "Аккаунт",
        "Conta", "Account", "Cont", "Account",
    ],
    "Experience": [
        "体验", "अनुभव", "Experiencia", "Expérience", "Erlebnis", "Ощущения",
        "Experiência", "Esperienza", "Experiență", "Beleving",
    ],
    "Sound": [
        "声音", "आवाज़", "Sonido", "Son", "Ton", "Звук",
        "Som", "Audio", "Sunet", "Geluid",
    ],
    "Haptics": [
        "触感反馈", "हैप्टिक्स", "Vibración", "Retour haptique", "Haptik",
        "Тактильный отклик", "Vibração", "Feedback aptico", "Vibrații",
        "Trillingen",
    ],
    "Reminders": [
        "提醒", "रिमाइंडर", "Recordatorios", "Rappels", "Erinnerungen",
        "Напоминания", "Lembretes", "Promemoria", "Memento-uri", "Herinneringen",
    ],
    "Developer": [
        "开发者", "डेवलपर", "Desarrollador", "Développeur", "Entwickler",
        "Разработчик", "Desenvolvedor", "Sviluppatore", "Dezvoltator",
        "Ontwikkelaar",
    ],

    # ---- Assorted labels ---------------------------------------------------
    "All": [
        "全部", "सभी", "Todos", "Tout", "Alle", "Все",
        "Todos", "Tutti", "Toate", "Alle",
    ],
    "Awesome": [
        "太好了", "शानदार", "Genial", "Super", "Super", "Отлично",
        "Ótimo", "Fantastico", "Super", "Top",
    ],
    "Collect": [
        "收取", "इकट्ठा करें", "Recoger", "Récupérer", "Einsammeln",
        "Забрать", "Coletar", "Raccogli", "Colectează", "Ophalen",
    ],
    "Flights": [
        "飞行", "फ़्लाइट", "Vuelos", "Vols", "Flüge", "Полёты",
        "Voos", "Voli", "Zboruri", "Vluchten",
    ],
    "Participants": [
        "参与者", "प्रतिभागी", "Participantes", "Participants", "Teilnehmende",
        "Участники", "Participantes", "Partecipanti", "Participanți",
        "Deelnemers",
    ],
    "Time": [
        "时间", "समय", "Tiempo", "Temps", "Zeit", "Время",
        "Tempo", "Tempo", "Timp", "Tijd",
    ],

    # ---- Widget gallery entries, app side ---------------------------------
    "Focus Now": [
        "立即专注", "अभी फ़ोकस", "Concéntrate ya", "Concentration immédiate",
        "Jetzt fokussieren", "Фокус сейчас", "Foco agora", "Concentrati ora",
        "Concentrare acum", "Nu focussen",
    ],
    "Focus Grid": [
        "专注格子", "फ़ोकस ग्रिड", "Cuadrícula de concentración",
        "Grille de concentration", "Fokus-Raster", "Сетка фокуса",
        "Grade de foco", "Griglia di concentrazione", "Grilă de concentrare",
        "Focusraster",
    ],
    "Passport Dashboard": [
        "护照总览", "पासपोर्ट डैशबोर्ड", "Panel del Pasaporte",
        "Tableau de bord Passeport", "Reisepass-Übersicht", "Панель Паспорта",
        "Painel do Passaporte", "Pannello Passaporto", "Panoul Pașaportului",
        "Paspoortoverzicht",
    ],
    "Streak Companion": [
        "连续天数伙伴", "स्ट्रीक साथी", "Compañero de racha",
        "Compagnon de série", "Serien-Begleiter", "Спутник серии",
        "Companheiro de sequência", "Compagno della serie", "Însoțitorul seriei",
        "Reeksmaatje",
    ],

    # ---- Home Sky card ----------------------------------------------------
    "Focus in %@": [
        "在%@中专注", "%@ में फ़ोकस करें", "Concéntrate en %@",
        "Concentrez-vous dans %@", "Fokussiere dich in %@",
        "Сосредоточьтесь в небе «%@»", "Foque em %@", "Concentrati in %@",
        "Concentrează-te în %@", "Focus in %@",
    ],
    "A Sky made for deep work": [
        "一片为深度工作而生的天空", "गहरे काम के लिए बना एक आकाश",
        "Un cielo hecho para el trabajo profundo",
        "Un ciel fait pour le travail profond",
        "Ein Himmel, gemacht für tiefe Arbeit", "Небо, созданное для глубокой работы",
        "Um céu feito para trabalho profundo",
        "Un cielo fatto per il lavoro profondo",
        "Un cer făcut pentru muncă profundă", "Een lucht gemaakt voor diep werk",
    ],
    "Upgrade to FocusGlobe PRO to unlock %@.": [
        "升级到 FocusGlobe PRO 即可解锁%@。",
        "%@ अनलॉक करने के लिए FocusGlobe PRO लें।",
        "Pásate a FocusGlobe PRO para desbloquear %@.",
        "Passez à FocusGlobe PRO pour débloquer %@.",
        "Hol dir FocusGlobe PRO, um %@ freizuschalten.",
        "Оформите FocusGlobe PRO, чтобы открыть «%@».",
        "Assine o FocusGlobe PRO para desbloquear %@.",
        "Passa a FocusGlobe PRO per sbloccare %@.",
        "Treci la FocusGlobe PRO ca să deblochezi %@.",
        "Ga naar FocusGlobe PRO om %@ te ontgrendelen.",
    ],
    "Fly %@ any time.": [
        "随时在%@中飞行。", "%@ में कभी भी उड़ें।", "Vuela en %@ cuando quieras.",
        "Volez dans %@ quand vous voulez.", "Flieg jederzeit in %@.",
        "Летайте в небе «%@» в любое время.", "Voe em %@ quando quiser.",
        "Vola in %@ quando vuoi.", "Zboară în %@ oricând.",
        "Vlieg in %@ wanneer je wilt.",
    ],
}


# The three unlock rules that carry a number. `%1$lld` is the count and `%2$@`
# the Sky name, written positionally so a language may put the Sky first.
#
# key -> locale -> CLDR plural category -> value
PLURALS: dict[str, dict[str, dict[str, str]]] = {
    "Invite %lld friends or upgrade to FocusGlobe PRO to unlock %@.": {
        "en": {"one": "Invite %1$lld friend or upgrade to FocusGlobe PRO to unlock %2$@.",
               "other": "Invite %1$lld friends or upgrade to FocusGlobe PRO to unlock %2$@."},
        "zh-Hans": {"other": "邀请 %1$lld 位好友或升级到 FocusGlobe PRO 解锁%2$@。"},
        "hi": {"one": "%2$@ अनलॉक करने के लिए %1$lld दोस्त को बुलाएँ या FocusGlobe PRO लें।",
               "other": "%2$@ अनलॉक करने के लिए %1$lld दोस्तों को बुलाएँ या FocusGlobe PRO लें।"},
        "es": {"one": "Invita a %1$lld amigo o pásate a FocusGlobe PRO para desbloquear %2$@.",
               "other": "Invita a %1$lld amigos o pásate a FocusGlobe PRO para desbloquear %2$@."},
        "fr": {"one": "Invitez %1$lld ami ou passez à FocusGlobe PRO pour débloquer %2$@.",
               "other": "Invitez %1$lld amis ou passez à FocusGlobe PRO pour débloquer %2$@."},
        "de": {"one": "Lade %1$lld Freund ein oder hol dir FocusGlobe PRO, um %2$@ freizuschalten.",
               "other": "Lade %1$lld Freunde ein oder hol dir FocusGlobe PRO, um %2$@ freizuschalten."},
        "ru": {"one": "Пригласите %1$lld друга или оформите FocusGlobe PRO, чтобы открыть «%2$@».",
               "few": "Пригласите %1$lld друзей или оформите FocusGlobe PRO, чтобы открыть «%2$@».",
               "many": "Пригласите %1$lld друзей или оформите FocusGlobe PRO, чтобы открыть «%2$@».",
               "other": "Пригласите %1$lld друга или оформите FocusGlobe PRO, чтобы открыть «%2$@»."},
        "pt-BR": {"one": "Convide %1$lld amigo ou assine o FocusGlobe PRO para desbloquear %2$@.",
                  "other": "Convide %1$lld amigos ou assine o FocusGlobe PRO para desbloquear %2$@."},
        "it": {"one": "Invita %1$lld amico o passa a FocusGlobe PRO per sbloccare %2$@.",
               "other": "Invita %1$lld amici o passa a FocusGlobe PRO per sbloccare %2$@."},
        "ro": {"one": "Invită %1$lld prieten sau treci la FocusGlobe PRO ca să deblochezi %2$@.",
               "few": "Invită %1$lld prieteni sau treci la FocusGlobe PRO ca să deblochezi %2$@.",
               "other": "Invită %1$lld de prieteni sau treci la FocusGlobe PRO ca să deblochezi %2$@."},
        "nl": {"one": "Nodig %1$lld vriend uit of ga naar FocusGlobe PRO om %2$@ te ontgrendelen.",
               "other": "Nodig %1$lld vrienden uit of ga naar FocusGlobe PRO om %2$@ te ontgrendelen."},
    },
    "Focus %lld minutes to unlock %@ — free, just keep flying.": {
        "en": {"one": "Focus %1$lld minute to unlock %2$@ — free, just keep flying.",
               "other": "Focus %1$lld minutes to unlock %2$@ — free, just keep flying."},
        "zh-Hans": {"other": "专注 %1$lld 分钟即可解锁%2$@ —— 免费，继续飞行就好。"},
        "hi": {"one": "%2$@ अनलॉक करने के लिए %1$lld मिनट फ़ोकस करें — मुफ़्त, बस उड़ते रहें।",
               "other": "%2$@ अनलॉक करने के लिए %1$lld मिनट फ़ोकस करें — मुफ़्त, बस उड़ते रहें।"},
        "es": {"one": "Concéntrate %1$lld minuto para desbloquear %2$@: gratis, solo sigue volando.",
               "other": "Concéntrate %1$lld minutos para desbloquear %2$@: gratis, solo sigue volando."},
        "fr": {"one": "Concentrez-vous %1$lld minute pour débloquer %2$@ — gratuit, continuez à voler.",
               "other": "Concentrez-vous %1$lld minutes pour débloquer %2$@ — gratuit, continuez à voler."},
        "de": {"one": "Fokussiere dich %1$lld Minute, um %2$@ freizuschalten — kostenlos, flieg einfach weiter.",
               "other": "Fokussiere dich %1$lld Minuten, um %2$@ freizuschalten — kostenlos, flieg einfach weiter."},
        "ru": {"one": "Сосредоточьтесь %1$lld минуту, чтобы открыть «%2$@» — бесплатно, просто продолжайте летать.",
               "few": "Сосредоточьтесь %1$lld минуты, чтобы открыть «%2$@» — бесплатно, просто продолжайте летать.",
               "many": "Сосредоточьтесь %1$lld минут, чтобы открыть «%2$@» — бесплатно, просто продолжайте летать.",
               "other": "Сосредоточьтесь %1$lld минуты, чтобы открыть «%2$@» — бесплатно, просто продолжайте летать."},
        "pt-BR": {"one": "Foque %1$lld minuto para desbloquear %2$@ — grátis, é só continuar voando.",
                  "other": "Foque %1$lld minutos para desbloquear %2$@ — grátis, é só continuar voando."},
        "it": {"one": "Concentrati %1$lld minuto per sbloccare %2$@: gratis, continua solo a volare.",
               "other": "Concentrati %1$lld minuti per sbloccare %2$@: gratis, continua solo a volare."},
        "ro": {"one": "Concentrează-te %1$lld minut ca să deblochezi %2$@ — gratuit, doar continuă să zbori.",
               "few": "Concentrează-te %1$lld minute ca să deblochezi %2$@ — gratuit, doar continuă să zbori.",
               "other": "Concentrează-te %1$lld de minute ca să deblochezi %2$@ — gratuit, doar continuă să zbori."},
        "nl": {"one": "Focus %1$lld minuut om %2$@ te ontgrendelen — gratis, blijf gewoon vliegen.",
               "other": "Focus %1$lld minuten om %2$@ te ontgrendelen — gratis, blijf gewoon vliegen."},
    },
    "Reach a %lld-day streak or upgrade to FocusGlobe PRO to unlock %@.": {
        "en": {"one": "Reach a %1$lld-day streak or upgrade to FocusGlobe PRO to unlock %2$@.",
               "other": "Reach a %1$lld-day streak or upgrade to FocusGlobe PRO to unlock %2$@."},
        "zh-Hans": {"other": "达成连续 %1$lld 天或升级到 FocusGlobe PRO 解锁%2$@。"},
        "hi": {"one": "%2$@ अनलॉक करने के लिए %1$lld दिन की स्ट्रीक बनाएँ या FocusGlobe PRO लें।",
               "other": "%2$@ अनलॉक करने के लिए %1$lld दिन की स्ट्रीक बनाएँ या FocusGlobe PRO लें।"},
        "es": {"one": "Consigue una racha de %1$lld día o pásate a FocusGlobe PRO para desbloquear %2$@.",
               "other": "Consigue una racha de %1$lld días o pásate a FocusGlobe PRO para desbloquear %2$@."},
        "fr": {"one": "Atteignez une série de %1$lld jour ou passez à FocusGlobe PRO pour débloquer %2$@.",
               "other": "Atteignez une série de %1$lld jours ou passez à FocusGlobe PRO pour débloquer %2$@."},
        "de": {"one": "Erreiche eine %1$lld-Tag-Serie oder hol dir FocusGlobe PRO, um %2$@ freizuschalten.",
               "other": "Erreiche eine %1$lld-Tage-Serie oder hol dir FocusGlobe PRO, um %2$@ freizuschalten."},
        "ru": {"one": "Достигните серии в %1$lld день или оформите FocusGlobe PRO, чтобы открыть «%2$@».",
               "few": "Достигните серии в %1$lld дня или оформите FocusGlobe PRO, чтобы открыть «%2$@».",
               "many": "Достигните серии в %1$lld дней или оформите FocusGlobe PRO, чтобы открыть «%2$@».",
               "other": "Достигните серии в %1$lld дня или оформите FocusGlobe PRO, чтобы открыть «%2$@»."},
        "pt-BR": {"one": "Alcance uma sequência de %1$lld dia ou assine o FocusGlobe PRO para desbloquear %2$@.",
                  "other": "Alcance uma sequência de %1$lld dias ou assine o FocusGlobe PRO para desbloquear %2$@."},
        "it": {"one": "Raggiungi una serie di %1$lld giorno o passa a FocusGlobe PRO per sbloccare %2$@.",
               "other": "Raggiungi una serie di %1$lld giorni o passa a FocusGlobe PRO per sbloccare %2$@."},
        "ro": {"one": "Atinge o serie de %1$lld zi sau treci la FocusGlobe PRO ca să deblochezi %2$@.",
               "few": "Atinge o serie de %1$lld zile sau treci la FocusGlobe PRO ca să deblochezi %2$@.",
               "other": "Atinge o serie de %1$lld de zile sau treci la FocusGlobe PRO ca să deblochezi %2$@."},
        "nl": {"one": "Bereik een reeks van %1$lld dag of ga naar FocusGlobe PRO om %2$@ te ontgrendelen.",
               "other": "Bereik een reeks van %1$lld dagen of ga naar FocusGlobe PRO om %2$@ te ontgrendelen."},
    },
}


# Found by the same field sweep on a second pass: the Focus Shield rows build
# their titles through a `SettingsRow(title:)`-style initialiser, so no literal
# ever appears inside a `Text(...)`.
TRANSLATIONS.update({
    "Reflect": [
        "反思", "चिंतन", "Reflexión", "Réflexion", "Reflexion", "Размышление",
        "Reflexão", "Riflessione", "Reflecție", "Reflectie",
    ],
})
