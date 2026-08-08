"""Tranche 6a — product catalog content: Skies, skins, vehicles, cabin items.

WHAT IS AND IS NOT TRANSLATED HERE

    Sky NAMES are translated, including their place elements, using each
    language's own exonym: "Swiss Alps" is "Alpes suizos" in Spanish and
    "Schweizer Alpen" in German, because those are what those languages call
    that place. Japanese and Fijian place names (Kyoto, Fiji, Tokyo) keep their
    established local forms.

    The English string stays the IDENTITY everywhere — ids, analytics,
    persistence, legacy migration maps and the App Group snapshot all keep it.
    Only the moment a name is drawn goes through the catalog. That is why the
    old Sky names ("Sahara Night", "Amber Highlands", "Golden Hour", …) are
    absent from this file: they exist solely as migration keys and are never
    shown.

    Glossary is honoured: Sky, Flight, Cabin, Coins, Passport keep the one word
    chosen in tranche 1.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Sky names --------------------------------------------------------
    "Desert Night": [
        "沙漠之夜", "रेगिस्तानी रात", "Noche del desierto", "Nuit du désert",
        "Wüstennacht", "Ночь в пустыне", "Noite no deserto", "Notte nel deserto",
        "Noapte în deșert", "Woestijnnacht",
    ],
    "Fiji Lagoon": [
        "斐济潟湖", "फ़िजी लैगून", "Laguna de Fiyi", "Lagon des Fidji",
        "Fidschi-Lagune", "Лагуна Фиджи", "Lagoa de Fiji", "Laguna delle Figi",
        "Laguna Fiji", "Fiji-lagune",
    ],
    "Kyoto Lantern Night": [
        "京都灯笼之夜", "क्योतो लालटेन रात", "Noche de faroles en Kioto",
        "Nuit des lanternes de Kyoto", "Kyoto-Laternennacht",
        "Ночь фонарей в Киото", "Noite das lanternas de Quioto",
        "Notte delle lanterne di Kyoto", "Noaptea lampioanelor din Kyoto",
        "Kyoto-lantaarnnacht",
    ],
    "Northern Aurora": [
        "北极极光", "उत्तरी अरोरा", "Aurora boreal", "Aurore boréale",
        "Nordlicht", "Северное сияние", "Aurora boreal", "Aurora boreale",
        "Aurora boreală", "Noorderlicht",
    ],
    "Rainy Tokyo": [
        "雨中东京", "बारिश में तोक्यो", "Tokio bajo la lluvia", "Tokyo sous la pluie",
        "Tokio im Regen", "Дождливый Токио", "Tóquio na chuva",
        "Tokyo sotto la pioggia", "Tokyo în ploaie", "Regenachtig Tokio",
    ],
    "Swiss Alps": [
        "瑞士阿尔卑斯", "स्विस आल्प्स", "Alpes suizos", "Alpes suisses",
        "Schweizer Alpen", "Швейцарские Альпы", "Alpes suíços", "Alpi svizzere",
        "Alpii elvețieni", "Zwitserse Alpen",
    ],
    "Starfall Nebula": [
        "流星星云", "स्टारफ़ॉल नेबुला", "Nebulosa de estrellas fugaces",
        "Nébuleuse des étoiles filantes", "Sternenfall-Nebel",
        "Туманность звездопада", "Nebulosa da chuva de estrelas",
        "Nebulosa delle stelle cadenti", "Nebuloasa stelelor căzătoare",
        "Sterrenregennevel",
    ],
    "Deep Space": [
        "深空", "गहरा अंतरिक्ष", "Espacio profundo", "Espace lointain",
        "Tiefer Weltraum", "Глубокий космос", "Espaço profundo",
        "Spazio profondo", "Spațiul cosmic", "Diepe ruimte",
    ],

    # ---- Sky category labels ---------------------------------------------
    "Free Sky": [
        "免费天空", "मुफ़्त आकाश", "Cielo gratuito", "Ciel gratuit",
        "Kostenloser Himmel", "Бесплатное небо", "Céu gratuito",
        "Cielo gratuito", "Cer gratuit", "Gratis lucht",
    ],
    "Nature Sky": [
        "自然天空", "प्रकृति आकाश", "Cielo natural", "Ciel nature",
        "Natur-Himmel", "Природное небо", "Céu natural", "Cielo naturale",
        "Cer natural", "Natuurlucht",
    ],
    "City Sky": [
        "城市天空", "शहर आकाश", "Cielo urbano", "Ciel urbain",
        "Stadt-Himmel", "Городское небо", "Céu urbano", "Cielo urbano",
        "Cer urban", "Stadslucht",
    ],
    "Cosmic Sky": [
        "宇宙天空", "ब्रह्मांडीय आकाश", "Cielo cósmico", "Ciel cosmique",
        "Kosmischer Himmel", "Космическое небо", "Céu cósmico",
        "Cielo cosmico", "Cer cosmic", "Kosmische lucht",
    ],
    "FocusGlobe PRO only": [
        "仅限 FocusGlobe PRO", "केवल FocusGlobe PRO", "Solo FocusGlobe PRO",
        "FocusGlobe PRO uniquement", "Nur FocusGlobe PRO", "Только FocusGlobe PRO",
        "Somente FocusGlobe PRO", "Solo FocusGlobe PRO", "Doar FocusGlobe PRO",
        "Alleen FocusGlobe PRO",
    ],

    # ---- Sky descriptions -------------------------------------------------
    "A vast, silent desert night under a star-heavy sky.": [
        "繁星密布的天幕下，一片辽阔而寂静的沙漠之夜。",
        "तारों से भरे आकाश के नीचे विशाल, ख़ामोश रेगिस्तानी रात।",
        "Una noche de desierto inmensa y silenciosa bajo un cielo cargado de estrellas.",
        "Une nuit de désert vaste et silencieuse sous un ciel chargé d’étoiles.",
        "Eine weite, stille Wüstennacht unter einem sternenschweren Himmel.",
        "Огромная безмолвная ночь в пустыне под густо усыпанным звёздами небом.",
        "Uma noite de deserto vasta e silenciosa sob um céu carregado de estrelas.",
        "Una notte del deserto vasta e silenziosa sotto un cielo carico di stelle.",
        "O noapte de deșert vastă și tăcută sub un cer plin de stele.",
        "Een weidse, stille woestijnnacht onder een sterrenrijke hemel.",
    ],
    "Turquoise air over a quiet lagoon, soft islands drifting far below.": [
        "宁静潟湖上空的松石色空气，柔和的岛屿在远处漂移。",
        "शांत लैगून के ऊपर फ़िरोज़ी हवा, नीचे दूर बहते कोमल द्वीप।",
        "Aire turquesa sobre una laguna tranquila, con islas suaves a lo lejos.",
        "Un air turquoise au-dessus d’un lagon paisible, des îles douces au loin.",
        "Türkisfarbene Luft über einer stillen Lagune, sanfte Inseln tief unten.",
        "Бирюзовый воздух над тихой лагуной и мягкие острова далеко внизу.",
        "Ar turquesa sobre uma lagoa tranquila, ilhas suaves lá embaixo.",
        "Aria turchese su una laguna tranquilla, isole morbide molto più in basso.",
        "Aer turcoaz peste o lagună liniștită, insule blânde departe dedesubt.",
        "Turquoise lucht boven een stille lagune, zachte eilanden diep beneden.",
    ],
    "A calm Japanese evening — lantern glow and quiet temple roofs below.": [
        "一个平静的日本夜晚——灯笼的暖光与下方安静的庙宇屋顶。",
        "एक शांत जापानी शाम — लालटेन की चमक और नीचे शांत मंदिरों की छतें।",
        "Un atardecer japonés en calma: el brillo de los faroles y los tejados de los templos abajo.",
        "Un soir japonais paisible — la lueur des lanternes et les toits des temples en contrebas.",
        "Ein ruhiger japanischer Abend — Laternenlicht und stille Tempeldächer unter dir.",
        "Спокойный японский вечер — свет фонарей и тихие крыши храмов внизу.",
        "Um entardecer japonês calmo — o brilho das lanternas e os telhados dos templos abaixo.",
        "Una sera giapponese calma: il bagliore delle lanterne e i tetti dei templi in basso.",
        "O seară japoneză liniștită — lumina lampioanelor și acoperișurile templelor dedesubt.",
        "Een rustige Japanse avond — lantaarnlicht en stille tempeldaken beneden.",
    ],
    "Curtains of green and violet breathing over silent snow.": [
        "绿色与紫色的光幕，在寂静的雪原上缓缓呼吸。",
        "ख़ामोश बर्फ़ पर साँस लेते हरे और बैंजनी परदे।",
        "Cortinas verdes y violetas respirando sobre la nieve silenciosa.",
        "Des rideaux verts et violets qui respirent au-dessus d’une neige silencieuse.",
        "Grüne und violette Vorhänge, die über stillem Schnee atmen.",
        "Зелёные и фиолетовые завесы дышат над безмолвным снегом.",
        "Cortinas verdes e violetas respirando sobre a neve silenciosa.",
        "Tende verdi e viola che respirano sopra la neve silenziosa.",
        "Perdele verzi și violete respirând peste zăpada tăcută.",
        "Groene en violette gordijnen die ademen boven stille sneeuw.",
    ],
    "Soft rain over a muted neon skyline — cozy, blue, and quiet.": [
        "细雨落在柔和的霓虹天际线上——温暖、湛蓝、安静。",
        "मद्धम नियॉन स्काईलाइन पर हल्की बारिश — आरामदेह, नीली और शांत।",
        "Lluvia suave sobre un horizonte de neón apagado: acogedor, azul y tranquilo.",
        "Une pluie douce sur des néons feutrés — douillet, bleu et silencieux.",
        "Sanfter Regen über gedämpftem Neon — gemütlich, blau und still.",
        "Мягкий дождь над приглушённым неоном — уютно, синё и тихо.",
        "Chuva suave sobre um horizonte de neon abafado — aconchegante, azul e silencioso.",
        "Pioggia leggera su uno skyline al neon smorzato: accogliente, blu e tranquillo.",
        "Ploaie blândă peste un orizont de neon estompat — cald, albastru și liniștit.",
        "Zachte regen boven een gedempte neonskyline — knus, blauw en stil.",
    ],
    "High snowy peaks in a cold, clean sunrise glow.": [
        "高耸的雪峰，沐浴在清冷洁净的日出光辉中。",
        "ठंडी, साफ़ सूर्योदय की आभा में ऊँची बर्फ़ीली चोटियाँ।",
        "Altas cumbres nevadas bajo un amanecer frío y limpio.",
        "De hauts sommets enneigés dans une aube froide et limpide.",
        "Hohe Schneegipfel im kalten, klaren Licht des Sonnenaufgangs.",
        "Высокие снежные вершины в холодном чистом свете рассвета.",
        "Altos picos nevados sob um nascer do sol frio e limpo.",
        "Alte vette innevate in un’alba fredda e limpida.",
        "Piscuri înalte înzăpezite într-un răsărit rece și curat.",
        "Hoge besneeuwde toppen in een koude, heldere zonsopgang.",
    ],
    "Purple-blue nebula mist and distant stars, drifting slowly.": [
        "紫蓝色的星云雾气与遥远星辰，缓缓漂流。",
        "बैंजनी-नीली नेबुला धुंध और दूर के तारे, धीरे-धीरे बहते हुए।",
        "Bruma de nebulosa azul violeta y estrellas lejanas, a la deriva.",
        "Une brume de nébuleuse bleu-violet et des étoiles lointaines, à la dérive.",
        "Violett-blauer Nebeldunst und ferne Sterne, langsam treibend.",
        "Фиолетово-синяя дымка туманности и далёкие звёзды, медленно дрейфующие.",
        "Névoa de nebulosa azul-violeta e estrelas distantes, à deriva.",
        "Foschia di nebulosa viola-blu e stelle lontane, alla deriva.",
        "Ceață de nebuloasă violet-albastră și stele îndepărtate, plutind încet.",
        "Paarsblauwe neveldamp en verre sterren, langzaam drijvend.",
    ],
    "Planets, a dense starfield, and complete cosmic silence.": [
        "行星、密集的星场，以及彻底的宇宙寂静。",
        "ग्रह, घना तारामंडल और पूरी ब्रह्मांडीय ख़ामोशी।",
        "Planetas, un campo de estrellas denso y silencio cósmico absoluto.",
        "Des planètes, un champ d’étoiles dense et un silence cosmique total.",
        "Planeten, ein dichtes Sternenfeld und vollkommene kosmische Stille.",
        "Планеты, плотное звёздное поле и полная космическая тишина.",
        "Planetas, um campo estelar denso e silêncio cósmico completo.",
        "Pianeti, un campo stellare fitto e silenzio cosmico assoluto.",
        "Planete, un câmp stelar dens și liniște cosmică deplină.",
        "Planeten, een dicht sterrenveld en volledige kosmische stilte.",
    ],

    # ---- Balloon skins: taglines -----------------------------------------
    "The calm default": [
        "沉静的默认款", "शांत डिफ़ॉल्ट", "El clásico sereno", "Le classique paisible",
        "Der ruhige Standard", "Спокойный вариант по умолчанию", "O padrão calmo",
        "Il classico tranquillo", "Varianta calmă implicită", "De rustige standaard",
    ],
    "Bright and bold": [
        "明亮而大胆", "चमकदार और साहसी", "Vivo y atrevido", "Vif et audacieux",
        "Hell und mutig", "Яркий и смелый", "Vivo e ousado", "Vivace e deciso",
        "Viu și îndrăzneț", "Fel en gedurfd",
    ],
    "Soft and sweet": [
        "柔和而甜美", "कोमल और मीठा", "Suave y dulce", "Doux et tendre",
        "Sanft und süß", "Мягкий и нежный", "Suave e doce", "Morbido e dolce",
        "Blând și dulce", "Zacht en lief",
    ],
    "Say hello": [
        "打个招呼", "नमस्ते कहें", "Saluda", "Dites bonjour", "Sag hallo",
        "Поздоровайтесь", "Diga olá", "Saluta", "Salută", "Zeg hallo",
    ],
    "Ho Ho Ho": [
        "Ho Ho Ho", "हो हो हो", "Jo, jo, jo", "Ho ho ho", "Ho ho ho",
        "Хо-хо-хо", "Ho ho ho", "Oh oh oh", "Ho ho ho", "Ho ho ho",
    ],
    "Festive cheer": [
        "节日气氛", "उत्सव की ख़ुशी", "Espíritu festivo", "Esprit de fête",
        "Festliche Stimmung", "Праздничное настроение", "Clima de festa",
        "Spirito festivo", "Voie bună de sărbători", "Feeststemming",
    ],
    "Sky Pilot": [
        "天空飞行员", "स्काई पायलट", "Piloto del cielo", "Pilote du ciel",
        "Himmelspilot", "Небесный пилот", "Piloto do céu", "Pilota del cielo",
        "Pilot al cerului", "Luchtpiloot",
    ],
    "Ready for the skies": [
        "为天空而生", "आकाश के लिए तैयार", "Listo para los cielos",
        "Prêt pour les cieux", "Bereit für den Himmel", "Готов к небесам",
        "Pronto para os céus", "Pronto per i cieli", "Gata pentru ceruri",
        "Klaar voor de luchten",
    ],
    "A world of focus": [
        "一个专注的世界", "फ़ोकस की एक दुनिया", "Un mundo de concentración",
        "Un monde de concentration", "Eine Welt aus Fokus", "Мир фокуса",
        "Um mundo de foco", "Un mondo di concentrazione", "O lume a concentrării",
        "Een wereld van focus",
    ],
    "Lunar glow": [
        "月华微光", "चंद्र आभा", "Brillo lunar", "Lueur lunaire",
        "Mondschein", "Лунное сияние", "Brilho lunar", "Bagliore lunare",
        "Strălucire lunară", "Maanlicht",
    ],
    "Cosmic drift": [
        "宇宙漂流", "ब्रह्मांडीय बहाव", "Deriva cósmica", "Dérive cosmique",
        "Kosmische Drift", "Космический дрейф", "Deriva cósmica",
        "Deriva cosmica", "Derivă cosmică", "Kosmische drift",
    ],
    "Head in the clouds": [
        "云端漫游", "बादलों में खोया", "La cabeza en las nubes",
        "La tête dans les nuages", "Kopf in den Wolken", "Витая в облаках",
        "Cabeça nas nuvens", "Testa fra le nuvole", "Cu capul în nori",
        "Hoofd in de wolken",
    ],
    "Rule the skies": [
        "统御天空", "आकाश पर राज करें", "Domina los cielos", "Régnez sur les cieux",
        "Beherrsche den Himmel", "Царствуйте в небе", "Domine os céus",
        "Domina i cieli", "Stăpânește cerurile", "Heers over de luchten",
    ],

    # ---- Vehicles ---------------------------------------------------------
    "Sky Balloon": [
        "天空气球", "स्काई बलून", "Globo del cielo", "Montgolfière du ciel",
        "Himmelsballon", "Небесный шар", "Balão do céu", "Mongolfiera del cielo",
        "Balon al cerului", "Luchtballon",
    ],
    "Soft cream • the calm default": [
        "柔和奶油色 • 沉静的默认款", "सॉफ़्ट क्रीम • शांत डिफ़ॉल्ट",
        "Crema suave • el clásico sereno", "Crème doux • le classique paisible",
        "Sanftes Creme • der ruhige Standard", "Мягкий кремовый • спокойный по умолчанию",
        "Creme suave • o padrão calmo", "Crema tenue • il classico tranquillo",
        "Crem blând • varianta calmă implicită", "Zacht crème • de rustige standaard",
    ],
    "Classic Balloon": [
        "经典气球", "क्लासिक बलून", "Globo clásico", "Montgolfière classique",
        "Klassischer Ballon", "Классический шар", "Balão clássico",
        "Mongolfiera classica", "Balon clasic", "Klassieke ballon",
    ],
    "Warm stripes": [
        "暖色条纹", "गर्म धारियाँ", "Franjas cálidas", "Rayures chaudes",
        "Warme Streifen", "Тёплые полосы", "Listras quentes", "Strisce calde",
        "Dungi calde", "Warme strepen",
    ],
    "Night Balloon": [
        "夜行气球", "नाइट बलून", "Globo nocturno", "Montgolfière de nuit",
        "Nachtballon", "Ночной шар", "Balão noturno", "Mongolfiera notturna",
        "Balon de noapte", "Nachtballon",
    ],
    "Moonlit glow": [
        "月照微光", "चाँदनी आभा", "Resplandor de luna", "Lueur au clair de lune",
        "Mondbeschienener Schimmer", "Свечение в лунном свете", "Brilho ao luar",
        "Bagliore al chiaro di luna", "Strălucire în lumina lunii", "Maanverlichte gloed",
    ],
    "Aurora Airship": [
        "极光飞艇", "अरोरा एयरशिप", "Aeronave aurora", "Dirigeable aurore",
        "Aurora-Luftschiff", "Дирижабль «Аврора»", "Dirigível aurora",
        "Dirigibile aurora", "Dirijabil aurora", "Aurora-luchtschip",
    ],
    "Shimmering hull": [
        "流光船身", "झिलमिलाता ढाँचा", "Casco reluciente", "Coque chatoyante",
        "Schimmernder Rumpf", "Мерцающий корпус", "Casco cintilante",
        "Scafo scintillante", "Carenă strălucitoare", "Glinsterende romp",
    ],
    "Drifts on mist": [
        "随雾漂流", "धुंध पर बहता", "Se desliza entre la bruma",
        "Dérive sur la brume", "Treibt auf Nebel", "Дрейфует в дымке",
        "Desliza sobre a névoa", "Scivola sulla foschia", "Plutește pe ceață",
        "Drijft op nevel",
    ],
    "Paper Balloon": [
        "纸气球", "पेपर बलून", "Globo de papel", "Montgolfière en papier",
        "Papierballon", "Бумажный шар", "Balão de papel", "Mongolfiera di carta",
        "Balon de hârtie", "Papieren ballon",
    ],
    "Folded & light": [
        "轻盈折纸", "मुड़ा और हल्का", "Plegado y ligero", "Plié et léger",
        "Gefaltet & leicht", "Сложенный и лёгкий", "Dobrado e leve",
        "Piegato e leggero", "Pliat și ușor", "Gevouwen & licht",
    ],

    # ---- Cabin item placement: labels ------------------------------------
    "Table · Left": [
        "桌面 · 左", "मेज़ · बाएँ", "Mesa · izquierda", "Table · gauche",
        "Tisch · Links", "Стол · слева", "Mesa · esquerda", "Tavolo · sinistra",
        "Masă · stânga", "Tafel · links",
    ],
    "Table · Center": [
        "桌面 · 中", "मेज़ · बीच", "Mesa · centro", "Table · centre",
        "Tisch · Mitte", "Стол · по центру", "Mesa · centro", "Tavolo · centro",
        "Masă · centru", "Tafel · midden",
    ],
    "Table · Right": [
        "桌面 · 右", "मेज़ · दाएँ", "Mesa · derecha", "Table · droite",
        "Tisch · Rechts", "Стол · справа", "Mesa · direita", "Tavolo · destra",
        "Masă · dreapta", "Tafel · rechts",
    ],
    "Bench · Left": [
        "长椅 · 左", "बेंच · बाएँ", "Banco · izquierda", "Banc · gauche",
        "Bank · links", "Скамья · слева", "Banco · esquerda", "Panca · sinistra",
        "Bancă · stânga", "Bank · Links",
    ],
    "Bench · Center": [
        "长椅 · 中", "बेंच · बीच", "Banco · centro", "Banc · centre",
        "Bank · Mitte", "Скамья · по центру", "Banco · centro", "Panca · centro",
        "Bancă · centru", "Bank · midden",
    ],
    "Wall · Left": [
        "墙面 · 左", "दीवार · बाएँ", "Pared · izquierda", "Mur · gauche",
        "Wand · links", "Стена · слева", "Parede · esquerda", "Parete · sinistra",
        "Perete · stânga", "Wand · Links",
    ],
    "Wall · Right": [
        "墙面 · 右", "दीवार · दाएँ", "Pared · derecha", "Mur · droite",
        "Wand · rechts", "Стена · справа", "Parede · direita", "Parete · destra",
        "Perete · dreapta", "Wand · Rechts",
    ],
    "Hook · Left": [
        "挂钩 · 左", "हुक · बाएँ", "Gancho · izquierda", "Crochet · gauche",
        "Haken · Links", "Крючок · слева", "Gancho · esquerda", "Gancio · sinistra",
        "Cârlig · stânga", "Haak · links",
    ],
    "Hook · Right": [
        "挂钩 · 右", "हुक · दाएँ", "Gancho · derecha", "Crochet · droite",
        "Haken · Rechts", "Крючок · справа", "Gancho · direita", "Gancio · destra",
        "Cârlig · dreapta", "Haak · rechts",
    ],
    "Hanging · Left": [
        "悬挂 · 左", "लटका · बाएँ", "Colgado · izquierda", "Suspendu · gauche",
        "Hängend · Links", "Подвес · слева", "Pendurado · esquerda",
        "Appeso · sinistra", "Suspendat · stânga", "Hangend · links",
    ],
    "Hanging · Right": [
        "悬挂 · 右", "लटका · दाएँ", "Colgado · derecha", "Suspendu · droite",
        "Hängend · Rechts", "Подвес · справа", "Pendurado · direita",
        "Appeso · destra", "Suspendat · dreapta", "Hangend · rechts",
    ],
    "Floor · Right": [
        "地面 · 右", "फ़र्श · दाएँ", "Suelo · derecha", "Sol · droite",
        "Boden · Rechts", "Пол · справа", "Chão · direita", "Pavimento · destra",
        "Podea · dreapta", "Vloer · rechts",
    ],

    # ---- Cabin item placement: hints -------------------------------------
    "On the table, left side": [
        "在桌子左侧", "मेज़ पर, बाईं ओर", "En la mesa, a la izquierda",
        "Sur la table, à gauche", "Auf dem Tisch, links", "На столе, слева",
        "Na mesa, à esquerda", "Sul tavolo, a sinistra", "Pe masă, în stânga",
        "Op de tafel, links",
    ],
    "On the table, in the middle": [
        "在桌子中间", "मेज़ पर, बीच में", "En la mesa, en el centro",
        "Sur la table, au centre", "Auf dem Tisch, in der Mitte", "На столе, по центру",
        "Na mesa, ao centro", "Sul tavolo, al centro", "Pe masă, la mijloc",
        "Op de tafel, in het midden",
    ],
    "On the table, right side": [
        "在桌子右侧", "मेज़ पर, दाईं ओर", "En la mesa, a la derecha",
        "Sur la table, à droite", "Auf dem Tisch, rechts", "На столе, справа",
        "Na mesa, à direita", "Sul tavolo, a destra", "Pe masă, în dreapta",
        "Op de tafel, rechts",
    ],
    "On the bench, left side": [
        "在长椅左侧", "बेंच पर, बाईं ओर", "En el banco, a la izquierda",
        "Sur le banc, à gauche", "Auf der Bank, links", "На скамье, слева",
        "No banco, à esquerda", "Sulla panca, a sinistra", "Pe bancă, în stânga",
        "Op de bank, links",
    ],
    "On the bench, in the middle": [
        "在长椅中间", "बेंच पर, बीच में", "En el banco, en el centro",
        "Sur le banc, au centre", "Auf der Bank, in der Mitte", "На скамье, по центру",
        "No banco, ao centro", "Sulla panca, al centro", "Pe bancă, la mijloc",
        "Op de bank, in het midden",
    ],
    "On the left wall": [
        "在左侧墙上", "बाईं दीवार पर", "En la pared izquierda", "Sur le mur de gauche",
        "An der linken Wand", "На левой стене", "Na parede esquerda",
        "Sulla parete sinistra", "Pe peretele din stânga", "Aan de linkerwand",
    ],
    "On the right wall": [
        "在右侧墙上", "दाईं दीवार पर", "En la pared derecha", "Sur le mur de droite",
        "An der rechten Wand", "На правой стене", "Na parede direita",
        "Sulla parete destra", "Pe peretele din dreapta", "Aan de rechterwand",
    ],
    "On the left hook": [
        "在左侧挂钩上", "बाएँ हुक पर", "En el gancho izquierdo",
        "Sur le crochet de gauche", "Am linken Haken", "На левом крючке",
        "No gancho esquerdo", "Sul gancio sinistro", "Pe cârligul din stânga",
        "Aan de linkerhaak",
    ],
    "On the right hook": [
        "在右侧挂钩上", "दाएँ हुक पर", "En el gancho derecho",
        "Sur le crochet de droite", "Am rechten Haken", "На правом крючке",
        "No gancho direito", "Sul gancio destro", "Pe cârligul din dreapta",
        "Aan de rechterhaak",
    ],
    "Hanging above, to the left": [
        "悬挂在上方偏左", "ऊपर लटका, बाईं ओर", "Colgado arriba, a la izquierda",
        "Suspendu au-dessus, à gauche", "Oben hängend, links",
        "Подвешено сверху, слева", "Pendurado acima, à esquerda",
        "Appeso in alto, a sinistra", "Suspendat deasupra, în stânga",
        "Hangend boven, links",
    ],
    "Hanging above, to the right": [
        "悬挂在上方偏右", "ऊपर लटका, दाईं ओर", "Colgado arriba, a la derecha",
        "Suspendu au-dessus, à droite", "Oben hängend, rechts",
        "Подвешено сверху, справа", "Pendurado acima, à direita",
        "Appeso in alto, a destra", "Suspendat deasupra, în dreapta",
        "Hangend boven, rechts",
    ],
    "On the floor, right side": [
        "在地面右侧", "फ़र्श पर, दाईं ओर", "En el suelo, a la derecha",
        "Au sol, à droite", "Auf dem Boden, rechts", "На полу, справа",
        "No chão, à direita", "Sul pavimento, a destra", "Pe podea, în dreapta",
        "Op de vloer, rechts",
    ],
}
