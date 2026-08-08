"""Tranche 6g — the last public surfaces.

Three groups, all found by classifying the residual literals rather than by the
display-call sweep, because none of them reaches the screen as a `Text` literal:

  * Home's rotating Sky HEADLINES live in a `[String]` keyed by Sky id.
  * Route-category SUBTITLES are a computed `String`.
  * Two ACCESSIBILITY LABELS were assembled by appending English suffixes
    (", premium", ", locked", ", free"). Each is now a whole sentence per state,
    so the order of name and status is the translator's to choose.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Home: rotating Sky headlines -------------------------------------
    "Focus above the lagoon": [
        "在潟湖上空专注", "लैगून के ऊपर फ़ोकस करें", "Concéntrate sobre la laguna",
        "Concentrez-vous au-dessus du lagon", "Fokussiere dich über der Lagune",
        "Сосредоточьтесь над лагуной", "Foque acima da lagoa",
        "Concentrati sopra la laguna", "Concentrează-te deasupra lagunei",
        "Focus boven de lagune",
    ],
    "Turquoise calm for deep work": [
        "松石色的宁静，适合深度工作", "गहरे काम के लिए फ़िरोज़ी शांति",
        "Calma turquesa para el trabajo profundo",
        "Un calme turquoise pour le travail profond",
        "Türkise Ruhe für tiefe Arbeit", "Бирюзовый покой для глубокой работы",
        "Calma turquesa para trabalho profundo",
        "Calma turchese per il lavoro profondo",
        "Liniște turcoaz pentru muncă profundă",
        "Turquoise rust voor diep werk",
    ],
    "Study among the lanterns": [
        "在灯笼之间学习", "लालटेनों के बीच पढ़ें", "Estudia entre los faroles",
        "Étudiez parmi les lanternes", "Lerne zwischen den Laternen",
        "Учитесь среди фонарей", "Estude entre as lanternas",
        "Studia tra le lanterne", "Învață printre lampioane",
        "Studeer tussen de lantaarns",
    ],
    "A quiet Kyoto evening": [
        "一个安静的京都夜晚", "एक शांत क्योतो शाम", "Una tarde tranquila en Kioto",
        "Une soirée paisible à Kyoto", "Ein stiller Abend in Kyoto",
        "Тихий вечер в Киото", "Um entardecer tranquilo em Quioto",
        "Una sera tranquilla a Kyoto", "O seară liniștită în Kyoto",
        "Een stille avond in Kyoto",
    ],
    "Focus under the aurora": [
        "在极光下专注", "अरोरा के नीचे फ़ोकस करें", "Concéntrate bajo la aurora",
        "Concentrez-vous sous l’aurore", "Fokussiere dich unter dem Polarlicht",
        "Сосредоточьтесь под сиянием", "Foque sob a aurora",
        "Concentrati sotto l’aurora", "Concentrează-te sub auroră",
        "Focus onder het poollicht",
    ],
    "Northern lights for deep work": [
        "北极光，伴你深度工作", "गहरे काम के लिए उत्तरी रोशनी",
        "Auroras boreales para el trabajo profundo",
        "Des aurores boréales pour le travail profond",
        "Nordlichter für tiefe Arbeit", "Северное сияние для глубокой работы",
        "Auroras boreais para trabalho profundo",
        "Aurore boreali per il lavoro profondo",
        "Aurore boreale pentru muncă profundă",
        "Noorderlicht voor diep werk",
    ],
    "Study over rainy Tokyo": [
        "在雨中的东京上空学习", "बारिश वाले तोक्यो के ऊपर पढ़ें",
        "Estudia sobre un Tokio lluvioso", "Étudiez au-dessus d’un Tokyo pluvieux",
        "Lerne über dem regnerischen Tokio", "Учитесь над дождливым Токио",
        "Estude sobre a Tóquio chuvosa", "Studia sopra una Tokyo piovosa",
        "Învață deasupra unui Tokyo ploios", "Studeer boven regenachtig Tokio",
    ],
    "Neon calm and soft rain": [
        "霓虹的静与细雨", "नियॉन की शांति और हल्की बारिश",
        "Calma de neón y lluvia suave", "Un calme néon et une pluie douce",
        "Neonruhe und sanfter Regen", "Неоновый покой и мягкий дождь",
        "Calma de neon e chuva suave", "Calma al neon e pioggia leggera",
        "Liniște de neon și ploaie blândă", "Neonrust en zachte regen",
    ],
    "Study above the Alps": [
        "在阿尔卑斯上空学习", "आल्प्स के ऊपर पढ़ें", "Estudia sobre los Alpes",
        "Étudiez au-dessus des Alpes", "Lerne über den Alpen",
        "Учитесь над Альпами", "Estude sobre os Alpes",
        "Studia sopra le Alpi", "Învață deasupra Alpilor",
        "Studeer boven de Alpen",
    ],
    "Crisp mountain air for focus": [
        "清冽的山间空气，助你专注", "फ़ोकस के लिए ताज़ी पहाड़ी हवा",
        "Aire de montaña puro para concentrarte",
        "Un air de montagne vif pour se concentrer",
        "Klare Bergluft für den Fokus", "Свежий горный воздух для фокуса",
        "Ar puro de montanha para focar",
        "Aria di montagna frizzante per concentrarti",
        "Aer de munte curat pentru concentrare",
        "Frisse berglucht om te focussen",
    ],
    "Focus under desert stars": [
        "在沙漠星空下专注", "रेगिस्तानी तारों के नीचे फ़ोकस करें",
        "Concéntrate bajo las estrellas del desierto",
        "Concentrez-vous sous les étoiles du désert",
        "Fokussiere dich unter Wüstensternen",
        "Сосредоточьтесь под звёздами пустыни",
        "Foque sob as estrelas do deserto",
        "Concentrati sotto le stelle del deserto",
        "Concentrează-te sub stelele deșertului",
        "Focus onder woestijnsterren",
    ],
    "A vast night made for depth": [
        "为深度而生的辽阔夜色", "गहराई के लिए बना विशाल रात",
        "Una noche inmensa hecha para la profundidad",
        "Une nuit immense faite pour la profondeur",
        "Eine weite Nacht, gemacht für Tiefe",
        "Огромная ночь, созданная для глубины",
        "Uma noite vasta feita para a profundidade",
        "Una notte vasta fatta per la profondità",
        "O noapte vastă făcută pentru profunzime",
        "Een weidse nacht gemaakt voor diepgang",
    ],
    "Focus among the stars": [
        "在群星之间专注", "तारों के बीच फ़ोकस करें", "Concéntrate entre las estrellas",
        "Concentrez-vous parmi les étoiles", "Fokussiere dich zwischen den Sternen",
        "Сосредоточьтесь среди звёзд", "Foque entre as estrelas",
        "Concentrati tra le stelle", "Concentrează-te printre stele",
        "Focus tussen de sterren",
    ],
    "Drift through falling starlight": [
        "在流星光下漂流", "गिरती तारों की रोशनी में बहें",
        "Déjate llevar entre luz de estrellas fugaces",
        "Dérivez dans la lumière des étoiles filantes",
        "Treibe durch fallendes Sternenlicht",
        "Дрейфуйте сквозь падающий звёздный свет",
        "Flutue pela luz das estrelas cadentes",
        "Lasciati andare tra la luce delle stelle cadenti",
        "Plutește prin lumina stelelor căzătoare",
        "Zweef door vallend sterrenlicht",
    ],
    "Study in deep space": [
        "在深空中学习", "गहरे अंतरिक्ष में पढ़ें", "Estudia en el espacio profundo",
        "Étudiez dans l’espace lointain", "Lerne im tiefen Weltraum",
        "Учитесь в глубоком космосе", "Estude no espaço profundo",
        "Studia nello spazio profondo", "Învață în spațiul adânc",
        "Studeer in de diepe ruimte",
    ],
    "Cosmic silence for deep work": [
        "宇宙般的寂静，适合深度工作", "गहरे काम के लिए ब्रह्मांडीय ख़ामोशी",
        "Silencio cósmico para el trabajo profundo",
        "Un silence cosmique pour le travail profond",
        "Kosmische Stille für tiefe Arbeit", "Космическая тишина для глубокой работы",
        "Silêncio cósmico para trabalho profundo",
        "Silenzio cosmico per il lavoro profondo",
        "Liniște cosmică pentru muncă profundă",
        "Kosmische stilte voor diep werk",
    ],

    # ---- Route-category subtitles ----------------------------------------
    "30 min": [
        "30 分钟", "30 मिनट", "30 min", "30 min", "30 Min", "30 мин",
        "30 min", "30 min", "30 min", "30 min",
    ],
    "45–90 min": [
        "45–90 分钟", "45–90 मिनट", "45–90 min", "45–90 min", "45–90 Min",
        "45–90 мин", "45–90 min", "45–90 min", "45–90 min", "45–90 min",
    ],
    "2–4 hours": [
        "2–4 小时", "2–4 घंटे", "2–4 horas", "2–4 heures", "2–4 Std",
        "2–4 часа", "2–4 horas", "2–4 ore", "2–4 ore", "2–4 uur",
    ],
    "6–12 hours": [
        "6–12 小时", "6–12 घंटे", "6–12 horas", "6–12 heures", "6–12 Std",
        "6–12 часов", "6–12 horas", "6–12 ore", "6–12 ore", "6–12 uur",
    ],

    # ---- Accessibility labels (whole sentences, not suffixes) -------------
    "%@, %@, %@": [
        "%@，%@，%@", "%@, %@, %@", "%@, %@, %@", "%@, %@, %@", "%@, %@, %@",
        "%@, %@, %@", "%@, %@, %@", "%@, %@, %@", "%@, %@, %@", "%@, %@, %@",
    ],
    "%@, %@, %@, premium": [
        "%@，%@，%@，高级", "%@, %@, %@, प्रीमियम", "%@, %@, %@, premium",
        "%@, %@, %@, premium", "%@, %@, %@, Premium", "%@, %@, %@, премиум",
        "%@, %@, %@, premium", "%@, %@, %@, premium", "%@, %@, %@, premium",
        "%@, %@, %@, premium",
    ],
    "%@, FocusGlobe PRO": [
        "%@，FocusGlobe PRO", "%@, FocusGlobe PRO", "%@, FocusGlobe PRO",
        "%@, FocusGlobe PRO", "%@, FocusGlobe PRO", "%@, FocusGlobe PRO",
        "%@, FocusGlobe PRO", "%@, FocusGlobe PRO", "%@, FocusGlobe PRO",
        "%@, FocusGlobe PRO",
    ],
    "%@, FocusGlobe PRO, locked": [
        "%@，FocusGlobe PRO，已锁定", "%@, FocusGlobe PRO, लॉक",
        "%@, FocusGlobe PRO, bloqueado", "%@, FocusGlobe PRO, verrouillé",
        "%@, FocusGlobe PRO, gesperrt", "%@, FocusGlobe PRO, заблокировано",
        "%@, FocusGlobe PRO, bloqueado", "%@, FocusGlobe PRO, bloccato",
        "%@, FocusGlobe PRO, blocat", "%@, FocusGlobe PRO, vergrendeld",
    ],
    "%@, free": [
        "%@，免费", "%@, मुफ़्त", "%@, gratis", "%@, gratuit", "%@, gratis",
        "%@, бесплатно", "%@, grátis", "%@, gratis", "%@, gratuit", "%@, gratis",
    ],
}
