"""Tranche 6b — cabin item names and their one-line descriptions.

Item names are product names for objects, not brands: they are translated.
"Iced Latte" becomes "Latte helado" because that is what the drink is called in
Spanish — the object is the same object. Where a language has borrowed the
English word wholesale (matcha, boba, latte), the borrowed form is used, since
inventing a native calque would name a thing nobody orders.

Glossary: Cabin keeps the word chosen in tranche 1.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    "Iced Latte": [
        "冰拿铁", "आइस्ड लाटे", "Latte helado", "Latte glacé", "Iced Latte",
        "Айс-латте", "Latte gelado", "Iced latte", "Latte cu gheață",
        "IJslatte",
    ],
    "A cool companion for long flights": [
        "长途飞行的清凉伙伴", "लंबी फ़्लाइट के लिए ठंडा साथी",
        "Un compañero fresco para vuelos largos",
        "Un compagnon frais pour les longs vols",
        "Ein kühler Begleiter für lange Flüge",
        "Прохладный спутник для долгих полётов",
        "Um companheiro gelado para voos longos",
        "Un compagno fresco per i voli lunghi",
        "Un însoțitor răcoritor pentru zboruri lungi",
        "Een koele metgezel voor lange vluchten",
    ],
    "For your best ideas": [
        "为你最好的想法", "आपके बेहतरीन विचारों के लिए", "Para tus mejores ideas",
        "Pour vos meilleures idées", "Für deine besten Ideen",
        "Для ваших лучших идей", "Para suas melhores ideias",
        "Per le tue idee migliori", "Pentru cele mai bune idei ale tale",
        "Voor je beste ideeën",
    ],
    "Sink into deep focus": [
        "沉入深度专注", "गहरे फ़ोकस में डूब जाएँ", "Húndete en la concentración profunda",
        "Plongez dans la concentration profonde", "Versinke in tiefem Fokus",
        "Погрузитесь в глубокий фокус", "Mergulhe no foco profundo",
        "Immergiti nella concentrazione profonda", "Cufundă-te în concentrare profundă",
        "Zak weg in diepe focus",
    ],
    "Framed Poster": [
        "装裱海报", "फ़्रेम किया हुआ पोस्टर", "Póster enmarcado", "Affiche encadrée",
        "Gerahmtes Poster", "Постер в рамке", "Pôster emoldurado",
        "Poster incorniciato", "Poster înrămat", "Ingelijste poster",
    ],
    "A view for the wall": [
        "留给墙面的风景", "दीवार के लिए एक नज़ारा", "Una vista para la pared",
        "Une vue pour le mur", "Eine Aussicht für die Wand", "Вид для стены",
        "Uma vista para a parede", "Un panorama per la parete",
        "O priveliște pentru perete", "Een uitzicht voor de muur",
    ],
    "Festive Ornament": [
        "节日挂饰", "उत्सव सजावट", "Adorno festivo", "Décoration de fête",
        "Festlicher Anhänger", "Праздничное украшение", "Enfeite festivo",
        "Decorazione festiva", "Ornament de sărbătoare", "Feestelijk ornament",
    ],
    "A little seasonal cheer": [
        "一点节令的欢欣", "थोड़ी मौसमी ख़ुशी", "Un poco de alegría de temporada",
        "Un petit air de fête", "Ein bisschen Feststimmung",
        "Немного праздничного настроения", "Um toque de alegria da estação",
        "Un tocco di allegria stagionale", "Puțină bucurie de sezon",
        "Een vleugje seizoensvreugde",
    ],
    "Closed Laptop": [
        "合上的笔记本电脑", "बंद लैपटॉप", "Laptop cerrado", "Ordinateur portable fermé",
        "Geschlossener Laptop", "Закрытый ноутбук", "Notebook fechado",
        "Portatile chiuso", "Laptop închis", "Dichtgeklapte laptop",
    ],
    "Work set aside for the climb": [
        "为攀升暂放的工作", "चढ़ाई के लिए किनारे रखा काम",
        "El trabajo apartado para el ascenso", "Le travail mis de côté pour la montée",
        "Arbeit beiseitegelegt für den Aufstieg", "Работа отложена ради подъёма",
        "O trabalho deixado de lado para a subida",
        "Il lavoro messo da parte per la salita",
        "Munca dată deoparte pentru urcare", "Werk opzij voor de klim",
    ],
    "Sleeping Cat": [
        "熟睡的猫", "सोती बिल्ली", "Gato dormido", "Chat endormi",
        "Schlafende Katze", "Спящий кот", "Gato dormindo", "Gatto addormentato",
        "Pisică adormită", "Slapende kat",
    ],
    "A calm co-pilot": [
        "沉静的副驾驶", "एक शांत सह-पायलट", "Un copiloto tranquilo",
        "Un copilote paisible", "Ein ruhiger Kopilot", "Спокойный второй пилот",
        "Um copiloto calmo", "Un copilota tranquillo", "Un copilot liniștit",
        "Een rustige copiloot",
    ],
    "Tiny Fern": [
        "小蕨", "नन्हा फ़र्न", "Helecho pequeño", "Petite fougère",
        "Kleiner Farn", "Маленький папоротник", "Samambaia pequena",
        "Felce piccola", "Ferigă mică", "Klein varentje",
    ],
    "A cabin companion": [
        "座舱里的伙伴", "केबिन का साथी", "Un compañero de cabina",
        "Un compagnon de cabine", "Ein Kabinenbegleiter", "Спутник в кабине",
        "Um companheiro de cabine", "Un compagno di cabina",
        "Un însoțitor de cabină", "Een cabinemaatje",
    ],
    "Ceramic Teapot": [
        "陶瓷茶壶", "सिरेमिक चायदानी", "Tetera de cerámica", "Théière en céramique",
        "Keramik-Teekanne", "Керамический чайник", "Bule de cerâmica",
        "Teiera in ceramica", "Ceainic de ceramică", "Keramieken theepot",
    ],
    "For longer flights": [
        "为更长的飞行", "लंबी फ़्लाइट के लिए", "Para vuelos más largos",
        "Pour les vols plus longs", "Für längere Flüge", "Для более долгих полётов",
        "Para voos mais longos", "Per i voli più lunghi",
        "Pentru zboruri mai lungi", "Voor langere vluchten",
    ],
    "Strawberry Matcha Latte": [
        "草莓抹茶拿铁", "स्ट्रॉबेरी माचा लाटे", "Latte de matcha y fresa",
        "Latte matcha-fraise", "Erdbeer-Matcha-Latte", "Клубничный матча-латте",
        "Latte de matcha com morango", "Latte matcha e fragola",
        "Latte matcha cu căpșuni", "Aardbei-matcha latte",
    ],
    "A layered little lift": [
        "层层叠叠的小提振", "परतदार छोटा उत्साह", "Un pequeño impulso por capas",
        "Un petit remontant en couches", "Ein geschichteter kleiner Muntermacher",
        "Маленький слоёный заряд бодрости", "Um empurrãozinho em camadas",
        "Un piccolo sprint a strati", "Un mic imbold în straturi",
        "Een gelaagd oppeppertje",
    ],
    "Heart Straw Boba Tea": [
        "心形吸管珍珠奶茶", "हार्ट स्ट्रॉ बोबा टी", "Té boba con pajita de corazón",
        "Bubble tea à paille cœur", "Boba-Tee mit Herz-Strohhalm",
        "Боба-чай с трубочкой-сердечком", "Chá boba com canudo de coração",
        "Bubble tea con cannuccia a cuore", "Ceai boba cu pai în formă de inimă",
        "Bubbelthee met hartjesrietje",
    ],
    "Sweet focus energy": [
        "甜甜的专注能量", "मीठी फ़ोकस ऊर्जा", "Energía dulce para concentrarte",
        "Une énergie sucrée pour se concentrer", "Süße Fokus-Energie",
        "Сладкая энергия для фокуса", "Energia doce para focar",
        "Energia dolce per concentrarti", "Energie dulce pentru concentrare",
        "Zoete focusenergie",
    ],
    "Pastel Insulated Tumbler": [
        "粉彩保温杯", "पेस्टल इंसुलेटेड टंबलर", "Vaso térmico pastel",
        "Gourde isotherme pastel", "Pastellfarbener Thermobecher",
        "Пастельный термостакан", "Copo térmico pastel",
        "Bicchiere termico pastello", "Pahar termic pastel",
        "Pastelkleurige thermosbeker",
    ],
    "Hydration for the long route": [
        "长途航线的补水", "लंबे रास्ते के लिए पानी",
        "Hidratación para la ruta larga", "De quoi s’hydrater sur la longue route",
        "Flüssigkeit für die lange Route", "Вода для длинного маршрута",
        "Hidratação para a rota longa", "Idratazione per la rotta lunga",
        "Hidratare pentru ruta lungă", "Water voor de lange route",
    ],
    "Candle Warmer Lamp": [
        "暖烛灯", "कैंडल वॉर्मर लैंप", "Lámpara calientavelas",
        "Lampe chauffe-bougie", "Kerzenwärmer-Lampe", "Лампа-подогреватель свечи",
        "Luminária aquecedora de vela", "Lampada scaldacandela",
        "Lampă pentru încălzit lumânări", "Kaarsenwarmerlamp",
    ],
    "Amber calm without a flame": [
        "无需火焰的琥珀宁静", "बिना लौ के अंबर शांति",
        "Calma ámbar sin llama", "Un calme ambré sans flamme",
        "Bernsteinruhe ohne Flamme", "Янтарный покой без огня",
        "Calma âmbar sem chama", "Calma ambrata senza fiamma",
        "Liniște chihlimbarie fără flacără", "Amberkleurige rust zonder vlam",
    ],
    "Mushroom Lamp": [
        "蘑菇灯", "मशरूम लैंप", "Lámpara seta", "Lampe champignon",
        "Pilzlampe", "Лампа-гриб", "Luminária cogumelo", "Lampada fungo",
        "Lampă ciupercă", "Paddenstoellamp",
    ],
    "A cozy pool of light": [
        "一汪温暖的光", "रोशनी का आरामदेह घेरा", "Un charco de luz acogedor",
        "Une flaque de lumière douillette", "Eine gemütliche Lichtinsel",
        "Уютная лужица света", "Uma poça de luz aconchegante",
        "Una pozza di luce accogliente", "Un colț cald de lumină",
        "Een knusse plas licht",
    ],
    "Mini Sunset Projector": [
        "迷你日落投影灯", "मिनी सनसेट प्रोजेक्टर", "Miniproyector de atardecer",
        "Mini projecteur de coucher de soleil", "Mini-Sonnenuntergangsprojektor",
        "Мини-проектор заката", "Miniprojetor de pôr do sol",
        "Mini proiettore tramonto", "Mini proiector de apus",
        "Mini zonsondergangprojector",
    ],
    "Warm atmosphere on demand": [
        "随时唤起的温暖氛围", "जब चाहें, गर्म माहौल",
        "Ambiente cálido cuando quieras", "Une ambiance chaude à la demande",
        "Warme Stimmung auf Knopfdruck", "Тёплая атмосфера по желанию",
        "Clima quente na hora que quiser", "Atmosfera calda quando vuoi",
        "Atmosferă caldă la cerere", "Warme sfeer wanneer je wilt",
    ],
    "Digital Flip Clock": [
        "数字翻页钟", "डिजिटल फ़्लिप क्लॉक", "Reloj digital de paletas",
        "Horloge à volets numérique", "Digitale Fallblattuhr",
        "Цифровые перекидные часы", "Relógio digital flip",
        "Orologio digitale a palette", "Ceas digital cu clapete",
        "Digitale klapklok",
    ],
    "Time, quietly kept": [
        "静静守候的时间", "समय, चुपचाप सहेजा", "El tiempo, guardado en silencio",
        "Le temps, gardé en silence", "Zeit, still gehütet",
        "Время, отмеряемое тихо", "O tempo, guardado em silêncio",
        "Il tempo, custodito in silenzio", "Timpul, ținut în tăcere",
        "Tijd, stil bijgehouden",
    ],
    "Mini Vinyl Record Player": [
        "迷你黑胶唱机", "मिनी विनाइल रिकॉर्ड प्लेयर", "Minitocadiscos de vinilo",
        "Mini tourne-disque vinyle", "Mini-Plattenspieler",
        "Мини-проигрыватель винила", "Minitoca-discos de vinil",
        "Mini giradischi in vinile", "Mini pick-up cu vinil",
        "Mini platenspeler",
    ],
    "Slow grooves for deep focus": [
        "慢节奏，深专注", "गहरे फ़ोकस के लिए धीमी धुनें",
        "Ritmos lentos para concentrarte a fondo",
        "Des rythmes lents pour une concentration profonde",
        "Langsame Grooves für tiefen Fokus",
        "Медленные ритмы для глубокого фокуса",
        "Batidas lentas para foco profundo",
        "Ritmi lenti per una concentrazione profonda",
        "Ritmuri lente pentru concentrare profundă",
        "Trage grooves voor diepe focus",
    ],
    "Sleepy Capybara Plush": [
        "瞌睡水豚玩偶", "नींद में डूबा कैपिबारा सॉफ़्ट टॉय", "Peluche de capibara dormilón",
        "Peluche capybara endormi", "Verschlafenes Capybara-Plüschtier",
        "Плюшевая сонная капибара", "Pelúcia de capivara sonolenta",
        "Peluche di capibara assonnato", "Capibara adormită din pluș",
        "Slaperige capibara-knuffel",
    ],
    "The calmest co-pilot": [
        "最沉静的副驾驶", "सबसे शांत सह-पायलट", "El copiloto más tranquilo",
        "Le copilote le plus paisible", "Der ruhigste Kopilot",
        "Самый спокойный второй пилот", "O copiloto mais calmo",
        "Il copilota più tranquillo", "Cel mai liniștit copilot",
        "De rustigste copiloot",
    ],
    "Cloud Pillow": [
        "云朵抱枕", "क्लाउड तकिया", "Cojín nube", "Coussin nuage",
        "Wolkenkissen", "Подушка-облако", "Almofada nuvem", "Cuscino nuvola",
        "Pernă nor", "Wolkenkussen",
    ],
    "A softer place to land": [
        "一处更柔软的降落", "उतरने की एक नरम जगह", "Un aterrizaje más suave",
        "Un atterrissage plus doux", "Ein weicherer Landeplatz",
        "Более мягкое место для посадки", "Um pouso mais macio",
        "Un atterraggio più morbido", "Un loc mai moale de aterizare",
        "Een zachtere landingsplek",
    ],
    "Mini Disco Ball": [
        "迷你迪斯科球", "मिनी डिस्को बॉल", "Minibola de discoteca",
        "Mini boule à facettes", "Mini-Discokugel", "Мини-диско-шар",
        "Miniglobo de espelhos", "Mini palla da discoteca",
        "Mini glob disco", "Mini discobal",
    ],
    "A restrained glint overhead": [
        "头顶一抹克制的闪光", "ऊपर एक संयमित चमक",
        "Un destello discreto en lo alto", "Un éclat discret au-dessus",
        "Ein zurückhaltendes Funkeln über dir", "Сдержанный блеск наверху",
        "Um brilho discreto lá em cima", "Un luccichio discreto sopra di te",
        "O sclipire discretă deasupra", "Een ingetogen glinstering boven je",
    ],
    "Moon and Stars Mobile": [
        "月亮与星星风铃", "चाँद-सितारों का मोबाइल", "Móvil de luna y estrellas",
        "Mobile lune et étoiles", "Mond-und-Sterne-Mobile",
        "Мобиль с луной и звёздами", "Móbile de lua e estrelas",
        "Giostrina luna e stelle", "Carusel cu lună și stele",
        "Maan-en-sterrenmobiel",
    ],
    "Celestial calm above you": [
        "头顶的星空宁静", "आपके ऊपर आकाशीय शांति",
        "Calma celeste sobre ti", "Un calme céleste au-dessus de vous",
        "Himmlische Ruhe über dir", "Небесный покой над вами",
        "Calma celeste acima de você", "Calma celeste sopra di te",
        "Liniște cerească deasupra ta", "Hemelse rust boven je",
    ],
}
