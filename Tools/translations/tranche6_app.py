"""Tranche 6f — onboarding, Store, Settings, Focus Shield, location picker.

Closes the last public surfaces. Two decisions are recorded here rather than in
a commit message, because they are the kind a future translator will re-open:

  1. The onboarding TESTIMONIALS are translated; the four names are not. The
     code already marks them as illustrative rather than as real reviews from
     named users, and leaving English paragraphs under a Spanish UI would read
     as an oversight. Names are left alone because a name is not copy.

  2. The five LANDING-SCREEN QUOTATIONS (Will Durant, Robert Collier, Horace
     Mann, A. A. Milne, Confucius) and their attributions are deliberately NOT
     in this file. They are published quotations by real, named people; a
     translation of one is a new text that would still carry that person's
     name. Canonical published translations exist for some of them in some of
     these languages, but they cannot be verified from here, so the quotations
     stay in their original English. This is reversible — supply verified
     translations and add the keys. The full reasoning, and the reason not to
     replace them with authored copy instead, is at the use site in
     `LandingView.swift`.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Onboarding: step headers ----------------------------------------
    "What do you want to focus on?": [
        "你想专注于什么？", "आप किस पर फ़ोकस करना चाहते हैं?",
        "¿En qué quieres concentrarte?", "Sur quoi voulez-vous vous concentrer ?",
        "Worauf willst du dich fokussieren?", "На чём вы хотите сосредоточиться?",
        "No que você quer focar?", "Su cosa vuoi concentrarti?",
        "Pe ce vrei să te concentrezi?", "Waarop wil je focussen?",
    ],
    "How long is your first flight?": [
        "你的第一次飞行有多久？", "आपकी पहली फ़्लाइट कितनी लंबी है?",
        "¿Cuánto dura tu primer vuelo?", "Combien de temps dure votre premier vol ?",
        "Wie lang ist dein erster Flug?", "Сколько длится ваш первый полёт?",
        "Quanto dura seu primeiro voo?", "Quanto dura il tuo primo volo?",
        "Cât durează primul tău zbor?", "Hoe lang is je eerste vlucht?",
    ],
    "Not set yet": [
        "尚未设置", "अभी सेट नहीं", "Sin definir", "Pas encore défini",
        "Noch nicht festgelegt", "Ещё не задано", "Ainda não definido",
        "Non ancora impostato", "Încă nesetat", "Nog niet ingesteld",
    ],
    "First flight length": [
        "首次飞行时长", "पहली फ़्लाइट की लंबाई", "Duración del primer vuelo",
        "Durée du premier vol", "Länge des ersten Flugs",
        "Длительность первого полёта", "Duração do primeiro voo",
        "Durata del primo volo", "Durata primului zbor", "Lengte eerste vlucht",
    ],
    "Your first focus route": [
        "你的第一条专注航线", "आपका पहला फ़ोकस रूट", "Tu primera ruta de concentración",
        "Votre premier itinéraire de concentration", "Deine erste Fokus-Route",
        "Ваш первый маршрут фокуса", "Sua primeira rota de foco",
        "La tua prima rotta di concentrazione", "Prima ta rută de concentrare",
        "Je eerste focusroute",
    ],
    "Your preferred flight length": [
        "你偏好的飞行时长", "आपकी पसंदीदा फ़्लाइट लंबाई",
        "Tu duración de vuelo preferida", "Votre durée de vol préférée",
        "Deine bevorzugte Flugdauer", "Ваша предпочтительная длительность полёта",
        "Sua duração de voo preferida", "La tua durata di volo preferita",
        "Durata ta preferată de zbor", "Je favoriete vluchtduur",
    ],
    "Your focus atmosphere": [
        "你的专注氛围", "आपका फ़ोकस माहौल", "Tu ambiente de concentración",
        "Votre ambiance de concentration", "Deine Fokus-Atmosphäre",
        "Ваша атмосфера фокуса", "Sua atmosfera de foco",
        "La tua atmosfera di concentrazione", "Atmosfera ta de concentrare",
        "Je focussfeer",
    ],
    "A distraction-free session": [
        "无干扰的专注时段", "बिना ध्यान भटकाव वाला सत्र",
        "Una sesión sin distracciones", "Une session sans distraction",
        "Eine ablenkungsfreie Sitzung", "Сессия без отвлечений",
        "Uma sessão sem distrações", "Una sessione senza distrazioni",
        "O sesiune fără distrageri", "Een sessie zonder afleiding",
    ],
    "Your progress path": [
        "你的进阶之路", "आपकी प्रगति की राह", "Tu camino de progreso",
        "Votre parcours de progression", "Dein Fortschrittsweg",
        "Ваш путь прогресса", "Seu caminho de progresso",
        "Il tuo percorso di progressi", "Drumul tău de progres",
        "Je voortgangspad",
    ],
    "Your launch-ready Home": [
        "已准备就绪的首页", "उड़ान के लिए तैयार आपका होम",
        "Tu inicio listo para despegar", "Votre accueil prêt au décollage",
        "Dein abflugbereiter Startbildschirm", "Ваш главный экран готов к запуску",
        "Sua tela inicial pronta para decolar",
        "La tua Home pronta al decollo", "Ecranul tău principal, gata de decolare",
        "Je startklare beginscherm",
    ],

    # ---- Onboarding: sound descriptions ----------------------------------
    "The classic — a soft breeze at altitude.": [
        "经典之选——高空的微风。", "क्लासिक — ऊँचाई पर हल्की हवा।",
        "El clásico: una brisa suave en altura.",
        "Le classique — une brise douce en altitude.",
        "Der Klassiker — eine sanfte Brise in der Höhe.",
        "Классика — лёгкий ветер на высоте.",
        "O clássico — uma brisa suave nas alturas.",
        "Il classico: una brezza leggera in quota.",
        "Clasicul — o briză ușoară la înălțime.",
        "De klassieker — een zachte bries op hoogte.",
    ],
    "Warm, wordless music for deep work.": [
        "温暖的无词音乐，适合深度工作。", "गहरे काम के लिए गर्म, बिना बोल का संगीत।",
        "Música cálida y sin letra para el trabajo profundo.",
        "Une musique chaude et sans paroles pour le travail profond.",
        "Warme, wortlose Musik für tiefe Arbeit.",
        "Тёплая музыка без слов для глубокой работы.",
        "Música quente e sem letra para trabalho profundo.",
        "Musica calda e senza parole per il lavoro profondo.",
        "Muzică caldă, fără versuri, pentru muncă profundă.",
        "Warme, woordloze muziek voor diep werk.",
    ],
    "Gentle tones tuned for concentration.": [
        "为专注调校的柔和音色。", "एकाग्रता के लिए तैयार कोमल स्वर।",
        "Tonos suaves pensados para concentrarse.",
        "Des tons doux réglés pour la concentration.",
        "Sanfte Töne, auf Konzentration abgestimmt.",
        "Мягкие тона, настроенные на концентрацию.",
        "Tons suaves ajustados para concentração.",
        "Toni delicati pensati per la concentrazione.",
        "Tonuri blânde, potrivite pentru concentrare.",
        "Zachte tonen afgestemd op concentratie.",
    ],
    "Steady rain against the cabin window.": [
        "细雨稳稳落在舱窗上。", "केबिन की खिड़की पर लगातार बारिश।",
        "Lluvia constante contra la ventanilla de la cabina.",
        "Une pluie régulière sur le hublot de la cabine.",
        "Gleichmäßiger Regen am Kabinenfenster.",
        "Ровный дождь по окну кабины.",
        "Chuva constante na janela da cabine.",
        "Pioggia costante sul finestrino della cabina.",
        "Ploaie constantă pe geamul cabinei.",
        "Gestage regen tegen het cabineraam.",
    ],
    "Slow waves rolling far below.": [
        "远处下方缓缓翻涌的浪。", "बहुत नीचे धीरे-धीरे लुढ़कती लहरें।",
        "Olas lentas rompiendo muy abajo.",
        "Des vagues lentes qui roulent loin en contrebas.",
        "Langsame Wellen tief unter dir.",
        "Медленные волны далеко внизу.",
        "Ondas lentas rolando lá embaixo.",
        "Onde lente che scorrono molto più in basso.",
        "Valuri lente rostogolindu-se departe dedesubt.",
        "Trage golven diep beneden.",
    ],
    "Calm ambience to settle the mind.": [
        "宁静的环境音，让心静下来。", "मन को शांत करने वाला माहौल।",
        "Un ambiente en calma para asentar la mente.",
        "Une ambiance calme pour apaiser l’esprit.",
        "Ruhige Klänge, die den Kopf beruhigen.",
        "Спокойная атмосфера, чтобы утихомирить ум.",
        "Um ambiente calmo para assentar a mente.",
        "Un’atmosfera calma per placare la mente.",
        "O atmosferă calmă care liniștește mintea.",
        "Rustige sfeer om je hoofd tot rust te brengen.",
    ],
    "Easy late-night jazz for long flights.": [
        "适合长途飞行的深夜轻爵士。", "लंबी फ़्लाइट के लिए हल्का देर-रात का जैज़।",
        "Jazz suave de madrugada para vuelos largos.",
        "Un jazz tranquille de fin de soirée pour les longs vols.",
        "Entspannter Nacht-Jazz für lange Flüge.",
        "Спокойный ночной джаз для долгих полётов.",
        "Jazz tranquilo de madrugada para voos longos.",
        "Jazz rilassato a tarda notte per i voli lunghi.",
        "Jazz lejer de noapte târziu pentru zboruri lungi.",
        "Rustige nachtjazz voor lange vluchten.",
    ],
    "A calm atmosphere for focus.": [
        "为专注而生的宁静氛围。", "फ़ोकस के लिए एक शांत माहौल।",
        "Un ambiente sereno para concentrarte.",
        "Une atmosphère calme pour se concentrer.",
        "Eine ruhige Atmosphäre für den Fokus.",
        "Спокойная атмосфера для фокуса.",
        "Uma atmosfera calma para focar.",
        "Un’atmosfera calma per concentrarsi.",
        "O atmosferă calmă pentru concentrare.",
        "Een rustige sfeer om te focussen.",
    ],
    "Focus Music": [
        "专注音乐", "फ़ोकस संगीत", "Música para concentrarse",
        "Musique de concentration", "Fokus-Musik", "Музыка для фокуса",
        "Música de foco", "Musica per la concentrazione",
        "Muzică de concentrare", "Focusmuziek",
    ],
    "Alpha Waves": [
        "α 脑波", "अल्फ़ा वेव्स", "Ondas alfa", "Ondes alpha",
        "Alpha-Wellen", "Альфа-волны", "Ondas alfa", "Onde alfa",
        "Unde alfa", "Alfagolven",
    ],

    # ---- Onboarding: struggle options ------------------------------------
    "My phone pulls me in": [
        "手机总把我吸进去", "मेरा फ़ोन मुझे खींच लेता है",
        "El teléfono me absorbe", "Mon téléphone m’aspire",
        "Mein Handy zieht mich rein", "Телефон меня затягивает",
        "Meu celular me puxa", "Il telefono mi risucchia",
        "Telefonul mă absoarbe", "Mijn telefoon zuigt me op",
    ],
    "I put things off": [
        "我总是拖延", "मैं टालता रहता हूँ", "Lo dejo todo para después",
        "Je remets à plus tard", "Ich schiebe Dinge auf",
        "Я откладываю дела", "Eu deixo tudo para depois",
        "Rimando le cose", "Amân lucrurile", "Ik stel dingen uit",
    ],
    "I lose momentum partway": [
        "中途就没劲了", "बीच में रफ़्तार खो देता हूँ",
        "Pierdo el impulso a mitad", "Je perds mon élan en cours de route",
        "Mir geht auf halbem Weg der Schwung aus",
        "Я теряю разгон на полпути", "Perco o impulso no meio do caminho",
        "Perdo slancio a metà", "Îmi pierd avântul pe parcurs",
        "Ik verlies halverwege mijn vaart",
    ],
    "It all feels like a lot": [
        "感觉压力很大", "सब कुछ बहुत ज़्यादा लगता है",
        "Todo se me hace mucho", "Tout me paraît trop",
        "Es fühlt sich alles nach viel an", "Всего слишком много",
        "Tudo parece demais", "Mi sembra tutto troppo",
        "Totul mi se pare mult", "Het voelt allemaal veel",
    ],
    "I struggle to get started": [
        "很难开始", "शुरुआत करना मुश्किल लगता है", "Me cuesta empezar",
        "J’ai du mal à démarrer", "Mir fällt der Anfang schwer",
        "Мне трудно начать", "Tenho dificuldade para começar",
        "Faccio fatica a iniziare", "Îmi e greu să încep",
        "Ik kom moeilijk op gang",
    ],

    # ---- Onboarding: testimonials (illustrative; names stay) --------------
    "The flight idea completely changes how starting feels. I pick 45 minutes and I'm already in the right headspace before I can overthink it.": [
        "「飞行」这个设定彻底改变了开始的感觉。我选 45 分钟，还来不及想太多，心态就已经对了。",
        "फ़्लाइट का आइडिया शुरुआत का एहसास पूरी तरह बदल देता है। मैं 45 मिनट चुनता हूँ और ज़्यादा सोचने से पहले ही सही मानसिकता में आ जाता हूँ।",
        "La idea del vuelo cambia por completo cómo se siente empezar. Elijo 45 minutos y ya estoy en la mentalidad correcta antes de darle demasiadas vueltas.",
        "L’idée du vol change complètement la sensation de commencer. Je choisis 45 minutes et je suis déjà dans le bon état d’esprit avant même de trop réfléchir.",
        "Die Flug-Idee verändert komplett, wie sich das Anfangen anfühlt. Ich wähle 45 Minuten und bin im richtigen Kopf, bevor ich zu viel nachdenken kann.",
        "Идея полёта полностью меняет ощущение от начала. Я выбираю 45 минут и уже настроен как надо, ещё не успев всё передумать.",
        "A ideia do voo muda completamente a sensação de começar. Escolho 45 minutos e já estou na cabeça certa antes de pensar demais.",
        "L’idea del volo cambia completamente la sensazione di iniziare. Scelgo 45 minuti e sono già nella testa giusta prima di pensarci troppo.",
        "Ideea zborului schimbă complet cum se simte începutul. Aleg 45 de minute și sunt deja în starea potrivită înainte să gândesc prea mult.",
        "Het vluchtidee verandert compleet hoe beginnen voelt. Ik kies 45 minuten en zit al in de juiste mindset voordat ik erover kan doordenken.",
    ],
    "Focus Shield is the part I didn't know I needed. Once a flight starts, my phone finally stops feeling like the thing I'm fighting against.": [
        "专注护盾是我原本不知道自己需要的部分。飞行一开始，手机终于不再像是我要对抗的东西。",
        "फ़ोकस शील्ड वह हिस्सा है जिसकी ज़रूरत मुझे पता ही नहीं थी। फ़्लाइट शुरू होते ही मेरा फ़ोन आख़िरकार दुश्मन जैसा लगना बंद कर देता है।",
        "El Escudo de Concentración es la parte que no sabía que necesitaba. En cuanto empieza un vuelo, el móvil deja de parecer aquello contra lo que peleo.",
        "Le Bouclier de concentration, c’est ce dont j’ignorais avoir besoin. Dès qu’un vol commence, mon téléphone cesse enfin d’être ce que je combats.",
        "Das Fokus-Schild ist der Teil, von dem ich nicht wusste, dass ich ihn brauche. Sobald ein Flug startet, fühlt sich mein Handy endlich nicht mehr wie mein Gegner an.",
        "Щит фокуса — то, о необходимости чего я не догадывался. Как только начинается полёт, телефон перестаёт быть тем, с чем я борюсь.",
        "O Escudo de Foco é a parte que eu não sabia que precisava. Assim que um voo começa, meu celular finalmente para de parecer aquilo contra o que eu luto.",
        "Lo Scudo Concentrazione è la parte che non sapevo mi servisse. Appena parte un volo, il telefono smette finalmente di sembrare ciò contro cui combatto.",
        "Scutul de concentrare e partea de care nu știam că am nevoie. Odată ce începe un zbor, telefonul încetează în sfârșit să pară dușmanul meu.",
        "Het Focusschild is het deel waarvan ik niet wist dat ik het nodig had. Zodra een vlucht start, voelt mijn telefoon eindelijk niet meer als iets waartegen ik vecht.",
    ],
    "I've tried a lot of focus timers. This is the first one that feels like a place I actually want to come back to every day.": [
        "我试过很多专注计时器。这是第一个让我真心愿意每天回来的地方。",
        "मैंने कई फ़ोकस टाइमर आज़माए हैं। यह पहला है जो ऐसी जगह लगता है जहाँ मैं सच में रोज़ लौटना चाहता हूँ।",
        "He probado muchos temporizadores de concentración. Este es el primero que se siente como un sitio al que de verdad quiero volver cada día.",
        "J’ai essayé beaucoup de minuteurs de concentration. C’est le premier qui donne envie de revenir chaque jour.",
        "Ich habe viele Fokus-Timer ausprobiert. Das hier ist der erste, der sich wie ein Ort anfühlt, an den ich täglich zurück will.",
        "Я перепробовал много таймеров фокуса. Этот — первый, куда действительно хочется возвращаться каждый день.",
        "Já testei muitos timers de foco. Este é o primeiro que parece um lugar ao qual eu realmente quero voltar todo dia.",
        "Ho provato tanti timer per la concentrazione. Questo è il primo che sembra un posto in cui voglio davvero tornare ogni giorno.",
        "Am încercat multe cronometre de concentrare. Acesta e primul care pare un loc în care chiar vreau să revin zilnic.",
        "Ik heb veel focustimers geprobeerd. Dit is de eerste die voelt als een plek waar ik echt elke dag naar terug wil.",
    ],
    "The Skies, sounds and Passport make progress feel visible without turning productivity into pressure. It's calm, simple and genuinely motivating.": [
        "天空、声音和护照让进步变得可见，却没有把效率变成压力。它平静、简单，也真的能激励人。",
        "आकाश, ध्वनियाँ और पासपोर्ट प्रगति को दिखने लायक बना देते हैं, बिना उत्पादकता को दबाव में बदले। यह शांत, सरल और सच में प्रेरक है।",
        "Los cielos, los sonidos y el Pasaporte hacen visible el progreso sin convertir la productividad en presión. Es tranquilo, sencillo y realmente motivador.",
        "Les ciels, les sons et le Passeport rendent les progrès visibles sans transformer la productivité en pression. C’est calme, simple et vraiment motivant.",
        "Die Himmel, die Klänge und der Reisepass machen Fortschritt sichtbar, ohne Produktivität in Druck zu verwandeln. Ruhig, einfach und wirklich motivierend.",
        "Небеса, звуки и Паспорт делают прогресс видимым, не превращая продуктивность в давление. Спокойно, просто и по-настоящему мотивирует.",
        "Os céus, os sons e o Passaporte tornam o progresso visível sem transformar produtividade em pressão. É calmo, simples e genuinamente motivador.",
        "I cieli, i suoni e il Passaporto rendono i progressi visibili senza trasformare la produttività in pressione. È calmo, semplice e davvero motivante.",
        "Cerurile, sunetele și Pașaportul fac progresul vizibil fără să transforme productivitatea în presiune. E calm, simplu și chiar motivant.",
        "De luchten, geluiden en het Paspoort maken vooruitgang zichtbaar zonder productiviteit in druk te veranderen. Rustig, simpel en echt motiverend.",
    ],

    # ---- Store ------------------------------------------------------------
    "Checking access…": [
        "正在检查权限…", "एक्सेस जाँचा जा रहा है…", "Comprobando el acceso…",
        "Vérification de l’accès…", "Zugriff wird geprüft…",
        "Проверяем доступ…", "Verificando o acesso…", "Verifica dell’accesso…",
        "Se verifică accesul…", "Toegang controleren…",
    ],
    "Unlock with FocusGlobe PRO": [
        "使用 FocusGlobe PRO 解锁", "FocusGlobe PRO से अनलॉक करें",
        "Desbloquea con FocusGlobe PRO", "Débloquez avec FocusGlobe PRO",
        "Mit FocusGlobe PRO freischalten", "Откройте с FocusGlobe PRO",
        "Desbloqueie com o FocusGlobe PRO", "Sblocca con FocusGlobe PRO",
        "Deblochează cu FocusGlobe PRO", "Ontgrendel met FocusGlobe PRO",
    ],
    "Cabin full — remove one to place this": [
        "座舱已满——移除一件才能放置",
        "केबिन भरा है — इसे रखने के लिए एक हटाएँ",
        "Cabina llena: quita algo para colocar esto",
        "Cabine pleine — retirez un objet pour placer celui-ci",
        "Kabine voll — entferne etwas, um das hier zu platzieren",
        "Кабина заполнена — уберите один предмет, чтобы поставить этот",
        "Cabine cheia — remova um item para colocar este",
        "Cabina piena: rimuovi un oggetto per posizionare questo",
        "Cabina e plină — scoate un obiect ca să-l pui pe acesta",
        "Cabine vol — haal er één weg om dit te plaatsen",
    ],
    "In your cabin": [
        "在你的座舱中", "आपके केबिन में", "En tu cabina", "Dans votre cabine",
        "In deiner Kabine", "В вашей кабине", "Na sua cabine",
        "Nella tua cabina", "În cabina ta", "In je cabine",
    ],
    "In your cabin.": [
        "在你的座舱中。", "आपके केबिन में।", "En tu cabina.", "Dans votre cabine.",
        "In deiner Kabine.", "В вашей кабине.", "Na sua cabine.",
        "Nella tua cabina.", "În cabina ta.", "In je cabine.",
    ],
    "FocusGlobe PRO item.": [
        "FocusGlobe PRO 物品。", "FocusGlobe PRO सामान।",
        "Objeto FocusGlobe PRO.", "Objet FocusGlobe PRO.",
        "FocusGlobe PRO-Objekt.", "Предмет FocusGlobe PRO.",
        "Item FocusGlobe PRO.", "Oggetto FocusGlobe PRO.",
        "Obiect FocusGlobe PRO.", "FocusGlobe PRO-item.",
    ],
    "Move Here": [
        "移到这里", "यहाँ ले जाएँ", "Mover aquí", "Déplacer ici",
        "Hierher bewegen", "Переместить сюда", "Mover para cá",
        "Sposta qui", "Mută aici", "Verplaats hierheen",
    ],
    "Place Item": [
        "放置物品", "सामान रखें", "Colocar objeto", "Placer l’objet",
        "Objekt platzieren", "Разместить предмет", "Colocar item",
        "Posiziona oggetto", "Așază obiectul", "Plaats item",
    ],
    "Move to": [
        "移动到", "कहाँ ले जाएँ", "Mover a", "Déplacer vers",
        "Verschieben nach", "Переместить в", "Mover para", "Sposta in",
        "Mută la", "Verplaats naar",
    ],
    "Place in": [
        "放置于", "कहाँ रखें", "Colocar en", "Placer dans",
        "Platzieren in", "Разместить в", "Colocar em", "Posiziona in",
        "Așază în", "Plaats in",
    ],
    "Current position": [
        "当前位置", "मौजूदा जगह", "Posición actual", "Position actuelle",
        "Aktuelle Position", "Текущее место", "Posição atual",
        "Posizione attuale", "Poziția curentă", "Huidige positie",
    ],
    "Unlock with Pro": [
        "使用 Pro 解锁", "Pro से अनलॉक करें", "Desbloquea con Pro",
        "Débloquez avec Pro", "Mit Pro freischalten", "Откройте с Pro",
        "Desbloqueie com o Pro", "Sblocca con Pro", "Deblochează cu Pro",
        "Ontgrendel met Pro",
    ],
    "Prepare Expedition": [
        "准备远征", "एक्सपीडिशन तैयार करें", "Preparar expedición",
        "Préparer l’expédition", "Expedition vorbereiten", "Подготовить экспедицию",
        "Preparar expedição", "Prepara la spedizione", "Pregătește expediția",
        "Expeditie voorbereiden",
    ],

    # ---- Coin rewards -----------------------------------------------------
    "Loading ad…": [
        "正在加载广告…", "विज्ञापन लोड हो रहा है…", "Cargando anuncio…",
        "Chargement de la publicité…", "Werbung wird geladen…",
        "Загружаем рекламу…", "Carregando anúncio…", "Caricamento annuncio…",
        "Se încarcă reclama…", "Advertentie laden…",
    ],
    "Watch & Spin": [
        "观看并转动", "देखें और घुमाएँ", "Ver y girar", "Regarder et tourner",
        "Ansehen & drehen", "Смотреть и крутить", "Assistir e girar",
        "Guarda e gira", "Vezi și învârte", "Bekijk & draai",
    ],
    "Your next free spin is warming up. Try again in a moment.": [
        "下一次免费转盘正在预热。请稍后再试。",
        "आपका अगला फ़्री स्पिन तैयार हो रहा है। थोड़ी देर में फिर कोशिश करें।",
        "Tu próximo giro gratis se está preparando. Inténtalo de nuevo en un momento.",
        "Votre prochain tour gratuit se prépare. Réessayez dans un instant.",
        "Deine nächste Gratisdrehung wird vorbereitet. Versuch es gleich noch einmal.",
        "Ваш следующий бесплатный спин готовится. Попробуйте через мгновение.",
        "Seu próximo giro grátis está esquentando. Tente de novo em instantes.",
        "Il tuo prossimo giro gratis si sta preparando. Riprova tra un momento.",
        "Următoarea ta rotire gratuită se pregătește. Mai încearcă într-o clipă.",
        "Je volgende gratis draai wordt klaargezet. Probeer het zo nog eens.",
    ],
    "No spin yet — the video has to finish to earn your coins. If it didn't load, try again shortly.": [
        "还不能转——视频要看完才能拿到金币。如果没加载出来，请稍后再试。",
        "अभी स्पिन नहीं — सिक्के पाने के लिए वीडियो पूरा होना ज़रूरी है। अगर लोड नहीं हुआ, तो थोड़ी देर में फिर कोशिश करें।",
        "Todavía no hay giro: el vídeo tiene que terminar para conseguir tus monedas. Si no se cargó, inténtalo en un momento.",
        "Pas encore de tour — la vidéo doit se terminer pour gagner vos pièces. Si elle n’a pas chargé, réessayez bientôt.",
        "Noch keine Drehung — das Video muss zu Ende laufen, damit du deine Münzen bekommst. Falls es nicht geladen hat, versuch es gleich noch einmal.",
        "Спина пока нет — чтобы получить монеты, видео должно доиграть. Если оно не загрузилось, попробуйте чуть позже.",
        "Ainda sem giro — o vídeo precisa terminar para você ganhar suas moedas. Se não carregou, tente de novo em breve.",
        "Ancora nessun giro: il video deve finire per guadagnare le monete. Se non si è caricato, riprova tra poco.",
        "Încă nicio rotire — clipul trebuie să se termine ca să primești monedele. Dacă nu s-a încărcat, mai încearcă în scurt timp.",
        "Nog geen draai — de video moet aflopen om je munten te verdienen. Als hij niet laadde, probeer het straks opnieuw.",
    ],

    # ---- Focus Shield -----------------------------------------------------
    "Block distractions": [
        "屏蔽干扰", "ध्यान भटकाव रोकें", "Bloquea distracciones",
        "Bloquez les distractions", "Ablenkungen blockieren",
        "Блокируйте отвлечения", "Bloqueie distrações",
        "Blocca le distrazioni", "Blochează distragerile", "Blokkeer afleidingen",
    ],
    "Enable in Settings": [
        "在设置中启用", "सेटिंग्स में चालू करें", "Activar en Ajustes",
        "Activer dans Réglages", "In den Einstellungen aktivieren",
        "Включить в Настройках", "Ativar em Ajustes", "Attiva in Impostazioni",
        "Activează în Setări", "Inschakelen in Instellingen",
    ],
    "Focus Shield active": [
        "专注护盾已启用", "फ़ोकस शील्ड चालू", "Escudo de Concentración activo",
        "Bouclier de concentration actif", "Fokus-Schild aktiv",
        "Щит фокуса активен", "Escudo de Foco ativo", "Scudo Concentrazione attivo",
        "Scut de concentrare activ", "Focusschild actief",
    ],
    "Block apps until landing": [
        "在降落前屏蔽 App", "लैंडिंग तक ऐप ब्लॉक करें",
        "Bloquea apps hasta aterrizar", "Bloquez les apps jusqu’à l’atterrissage",
        "Apps bis zur Landung sperren", "Блокировать приложения до посадки",
        "Bloqueie apps até o pouso", "Blocca le app fino all’atterraggio",
        "Blochează aplicațiile până la aterizare", "Blokkeer apps tot de landing",
    ],
    "Change blocked apps": [
        "更改被屏蔽的 App", "ब्लॉक किए ऐप बदलें", "Cambiar apps bloqueadas",
        "Modifier les apps bloquées", "Gesperrte Apps ändern",
        "Изменить заблокированные приложения", "Alterar apps bloqueados",
        "Modifica le app bloccate", "Schimbă aplicațiile blocate",
        "Geblokkeerde apps wijzigen",
    ],
    "Shield is active": [
        "护盾已启用", "शील्ड चालू है", "El escudo está activo",
        "Le bouclier est actif", "Das Schild ist aktiv", "Щит активен",
        "O escudo está ativo", "Lo scudo è attivo", "Scutul e activ",
        "Het schild is actief",
    ],
    "Shield is off for this flight": [
        "本次飞行未启用护盾", "इस फ़्लाइट के लिए शील्ड बंद है",
        "El escudo está desactivado en este vuelo",
        "Le bouclier est désactivé pour ce vol",
        "Das Schild ist für diesen Flug aus", "Щит выключен на этот полёт",
        "O escudo está desligado neste voo",
        "Lo scudo è disattivato per questo volo",
        "Scutul e oprit pentru acest zbor", "Het schild staat uit voor deze vlucht",
    ],
    "Changes apply immediately.": [
        "更改将立即生效。", "बदलाव तुरंत लागू होंगे।",
        "Los cambios se aplican al instante.", "Les modifications s’appliquent immédiatement.",
        "Änderungen wirken sofort.", "Изменения применяются сразу.",
        "As alterações valem imediatamente.", "Le modifiche hanno effetto subito.",
        "Modificările se aplică imediat.", "Wijzigingen gaan meteen in.",
    ],
    "Apps aren't blocked right now.": [
        "目前没有屏蔽任何 App。", "अभी कोई ऐप ब्लॉक नहीं है।",
        "Ahora mismo no hay apps bloqueadas.",
        "Aucune app n’est bloquée pour l’instant.",
        "Gerade sind keine Apps gesperrt.", "Сейчас приложения не заблокированы.",
        "Nenhum app está bloqueado agora.", "Al momento nessuna app è bloccata.",
        "Momentan nu e blocată nicio aplicație.", "Er zijn nu geen apps geblokkeerd.",
    ],
    "None selected yet": [
        "尚未选择", "अभी कोई नहीं चुना", "Ninguna seleccionada",
        "Aucune sélection", "Noch nichts ausgewählt", "Пока ничего не выбрано",
        "Nada selecionado ainda", "Nessuna selezione", "Nimic selectat încă",
        "Nog niets geselecteerd",
    ],
    "No apps chosen yet": [
        "尚未选择任何 App", "अभी कोई ऐप नहीं चुना", "Aún no has elegido apps",
        "Aucune app choisie pour l’instant", "Noch keine Apps gewählt",
        "Приложения пока не выбраны", "Nenhum app escolhido ainda",
        "Nessuna app scelta finora", "Încă nu ai ales aplicații",
        "Nog geen apps gekozen",
    ],
    "Screen Time access needed": [
        "需要「屏幕使用时间」权限", "स्क्रीन टाइम एक्सेस चाहिए",
        "Se necesita acceso a Tiempo de uso",
        "Accès à Temps d’écran requis", "Bildschirmzeit-Zugriff erforderlich",
        "Нужен доступ к «Экранному времени»",
        "É preciso acesso ao Tempo de Uso",
        "Serve l’accesso a Tempo di utilizzo",
        "E nevoie de acces la Timp în fața ecranului",
        "Toegang tot Schermtijd nodig",
    ],
    "Tap to set up": [
        "点按进行设置", "सेट अप करने के लिए टैप करें", "Toca para configurar",
        "Touchez pour configurer", "Zum Einrichten tippen",
        "Нажмите, чтобы настроить", "Toque para configurar",
        "Tocca per configurare", "Atinge pentru configurare",
        "Tik om in te stellen",
    ],
    "Coming soon ✨": [
        "即将推出 ✨", "जल्द आ रहा है ✨", "Muy pronto ✨", "Bientôt ✨",
        "Demnächst ✨", "Скоро ✨", "Em breve ✨", "Presto ✨",
        "În curând ✨", "Binnenkort ✨",
    ],
    "Soon… keep social, video and games out of your focus flights": [
        "很快…… 让社交、视频和游戏远离你的专注飞行",
        "जल्द ही… सोशल, वीडियो और गेम को अपनी फ़ोकस फ़्लाइट से दूर रखें",
        "Pronto… mantén redes, vídeo y juegos fuera de tus vuelos de concentración",
        "Bientôt… gardez réseaux, vidéo et jeux hors de vos vols de concentration",
        "Bald… halte Social Media, Video und Spiele aus deinen Fokus-Flügen heraus",
        "Скоро… соцсети, видео и игры останутся вне ваших полётов фокуса",
        "Em breve… mantenha redes, vídeo e jogos fora dos seus voos de foco",
        "Presto… tieni social, video e giochi fuori dai tuoi voli di concentrazione",
        "În curând… ține rețelele, filmele și jocurile în afara zborurilor tale de concentrare",
        "Binnenkort… houd social, video en games buiten je focusvluchten",
    ],

    # ---- Settings ---------------------------------------------------------
    "Purchases restored.": [
        "购买已恢复。", "ख़रीदारी बहाल हो गई।", "Compras restauradas.",
        "Achats restaurés.", "Käufe wiederhergestellt.", "Покупки восстановлены.",
        "Compras restauradas.", "Acquisti ripristinati.", "Achiziții restaurate.",
        "Aankopen hersteld.",
    ],
    "Nothing to restore.": [
        "没有可恢复的内容。", "बहाल करने के लिए कुछ नहीं है।",
        "No hay nada que restaurar.", "Rien à restaurer.",
        "Nichts wiederherzustellen.", "Восстанавливать нечего.",
        "Nada a restaurar.", "Niente da ripristinare.", "Nimic de restaurat.",
        "Niets te herstellen.",
    ],
    "Your public profile & anonymous alias": [
        "你的公开资料与匿名代号", "आपकी सार्वजनिक प्रोफ़ाइल और गुमनाम उपनाम",
        "Tu perfil público y tu alias anónimo",
        "Votre profil public et votre pseudonyme anonyme",
        "Dein öffentliches Profil und dein anonymer Alias",
        "Ваш публичный профиль и анонимный псевдоним",
        "Seu perfil público e apelido anônimo",
        "Il tuo profilo pubblico e il tuo pseudonimo anonimo",
        "Profilul tău public și aliasul anonim",
        "Je openbare profiel en anonieme alias",
    ],
    "Your current live presence": [
        "你当前的实时在线状态", "आपकी मौजूदा लाइव उपस्थिति",
        "Tu presencia en directo", "Votre présence en direct",
        "Deine aktuelle Live-Präsenz", "Ваше текущее присутствие в эфире",
        "Sua presença ao vivo", "La tua presenza dal vivo",
        "Prezența ta live curentă", "Je huidige live-aanwezigheid",
    ],
    "Crew requests, responses & connections": [
        "机组请求、回应与连接", "क्रू अनुरोध, जवाब और कनेक्शन",
        "Solicitudes, respuestas y conexiones de tripulación",
        "Demandes, réponses et connexions d’équipage",
        "Crew-Anfragen, Antworten und Verbindungen",
        "Запросы, ответы и связи команды",
        "Pedidos, respostas e conexões da tripulação",
        "Richieste, risposte e collegamenti dell’equipaggio",
        "Cereri, răspunsuri și conexiuni de echipaj",
        "Crewverzoeken, reacties en connecties",
    ],
    "Rooms you own or have joined": [
        "你拥有或加入的房间", "आपके बनाए या जुड़े हुए रूम",
        "Salas que tienes o a las que te has unido",
        "Salles que vous possédez ou avez rejointes",
        "Räume, die dir gehören oder denen du beigetreten bist",
        "Комнаты, которыми вы владеете или в которые вошли",
        "Salas que você criou ou entrou",
        "Stanze che possiedi o a cui ti sei unito",
        "Camere pe care le deții sau în care ai intrat",
        "Ruimtes die je bezit of hebt betreden",
    ],
    "Cached online data on this device": [
        "本设备上缓存的在线数据", "इस डिवाइस पर कैश्ड ऑनलाइन डेटा",
        "Datos online guardados en este dispositivo",
        "Données en ligne mises en cache sur cet appareil",
        "Auf diesem Gerät zwischengespeicherte Online-Daten",
        "Кешированные онлайн-данные на этом устройстве",
        "Dados online em cache neste dispositivo",
        "Dati online nella cache di questo dispositivo",
        "Date online stocate pe acest dispozitiv",
        "Gecachete onlinegegevens op dit apparaat",
    ],
    "Delete Online Data": [
        "删除在线数据", "ऑनलाइन डेटा हटाएँ", "Eliminar datos online",
        "Supprimer les données en ligne", "Online-Daten löschen",
        "Удалить онлайн-данные", "Excluir dados online",
        "Elimina i dati online", "Șterge datele online",
        "Onlinegegevens verwijderen",
    ],

    # ---- Settings: language -----------------------------------------------
    # Settings → Experience → Language. The row's supporting line, kept in the
    # same register as its neighbours ("Ambient audio during your flights",
    # "Streak, focus & goal nudges") — a short noun phrase, not a sentence.
    "The language FocusGlobe uses": [
        "FocusGlobe 使用的语言", "FocusGlobe की भाषा",
        "El idioma de FocusGlobe", "La langue de FocusGlobe",
        "Die Sprache von FocusGlobe", "Язык FocusGlobe",
        "O idioma do FocusGlobe", "La lingua di FocusGlobe",
        "Limba folosită de FocusGlobe", "De taal van FocusGlobe",
    ],
    # Spoken only. VoiceOver reads the row as "Español, seleccionado", so this
    # is the state of a LANGUAGE row and takes the masculine/neutral form each
    # platform uses for a selected element.
    "Selected": [
        "已选择", "चुना गया", "Seleccionado", "Sélectionné",
        "Ausgewählt", "Выбрано", "Selecionado", "Selezionato",
        "Selectat", "Geselecteerd",
    ],

    # ---- Location picker --------------------------------------------------
    "Starting city": [
        "起始城市", "शुरुआती शहर", "Ciudad de partida", "Ville de départ",
        "Startstadt", "Город отправления", "Cidade de partida",
        "Città di partenza", "Orașul de plecare", "Vertrekstad",
    ],
    "Search city, country, or code": [
        "搜索城市、国家或代码", "शहर, देश या कोड खोजें",
        "Busca ciudad, país o código", "Rechercher une ville, un pays ou un code",
        "Stadt, Land oder Code suchen", "Поиск города, страны или кода",
        "Buscar cidade, país ou código", "Cerca città, paese o codice",
        "Caută oraș, țară sau cod", "Zoek stad, land of code",
    ],
    "No cities found": [
        "未找到城市", "कोई शहर नहीं मिला", "No se encontraron ciudades",
        "Aucune ville trouvée", "Keine Städte gefunden", "Города не найдены",
        "Nenhuma cidade encontrada", "Nessuna città trovata",
        "Niciun oraș găsit", "Geen steden gevonden",
    ],
    "Use my current location": [
        "使用我的当前位置", "मेरा मौजूदा स्थान इस्तेमाल करें",
        "Usar mi ubicación actual", "Utiliser ma position actuelle",
        "Meinen aktuellen Standort verwenden", "Использовать текущее местоположение",
        "Usar minha localização atual", "Usa la mia posizione attuale",
        "Folosește locația mea curentă", "Gebruik mijn huidige locatie",
    ],
    "Detect where you are": [
        "检测你所在的位置", "पता लगाएँ कि आप कहाँ हैं",
        "Detecta dónde estás", "Détecter où vous êtes",
        "Erkennen, wo du bist", "Определить, где вы находитесь",
        "Detectar onde você está", "Rileva dove ti trovi",
        "Detectează unde ești", "Bepaal waar je bent",
    ],
    "Locating…": [
        "定位中…", "स्थान खोजा जा रहा है…", "Localizando…", "Localisation…",
        "Standort wird ermittelt…", "Определяем местоположение…",
        "Localizando…", "Localizzazione…", "Se localizează…", "Locatie bepalen…",
    ],
    "Location access is off": [
        "位置权限已关闭", "स्थान एक्सेस बंद है", "El acceso a la ubicación está desactivado",
        "L’accès à la localisation est désactivé", "Standortzugriff ist aus",
        "Доступ к геопозиции выключен", "O acesso à localização está desativado",
        "L’accesso alla posizione è disattivato", "Accesul la locație e oprit",
        "Locatietoegang staat uit",
    ],
    "Current Location": [
        "当前位置", "मौजूदा स्थान", "Ubicación actual", "Position actuelle",
        "Aktueller Standort", "Текущее местоположение", "Localização atual",
        "Posizione attuale", "Locația curentă", "Huidige locatie",
    ],
    "Popular": [
        "热门", "लोकप्रिय", "Populares", "Populaires", "Beliebt",
        "Популярные", "Populares", "Popolari", "Populare", "Populair",
    ],

    # ---- Misc -------------------------------------------------------------
    "FocusGlobe PRO is active": [
        "FocusGlobe PRO 已启用", "FocusGlobe PRO चालू है",
        "FocusGlobe PRO está activo", "FocusGlobe PRO est actif",
        "FocusGlobe PRO ist aktiv", "FocusGlobe PRO активен",
        "O FocusGlobe PRO está ativo", "FocusGlobe PRO è attivo",
        "FocusGlobe PRO e activ", "FocusGlobe PRO is actief",
    ],
    "Products unavailable. Please try again later.": [
        "产品不可用。请稍后再试。", "उत्पाद उपलब्ध नहीं। कृपया बाद में कोशिश करें।",
        "Productos no disponibles. Inténtalo más tarde.",
        "Produits indisponibles. Réessayez plus tard.",
        "Produkte nicht verfügbar. Versuch es später noch einmal.",
        "Продукты недоступны. Попробуйте позже.",
        "Produtos indisponíveis. Tente mais tarde.",
        "Prodotti non disponibili. Riprova più tardi.",
        "Produse indisponibile. Încearcă mai târziu.",
        "Producten niet beschikbaar. Probeer het later opnieuw.",
    ],
    "Purchase couldn't be completed. Please try again.": [
        "购买未能完成。请再试一次。",
        "ख़रीद पूरी नहीं हो सकी। कृपया फिर कोशिश करें।",
        "No se pudo completar la compra. Inténtalo de nuevo.",
        "L’achat n’a pas pu aboutir. Réessayez.",
        "Der Kauf konnte nicht abgeschlossen werden. Versuch es noch einmal.",
        "Покупку не удалось завершить. Попробуйте снова.",
        "Não foi possível concluir a compra. Tente novamente.",
        "Non è stato possibile completare l’acquisto. Riprova.",
        "Achiziția nu a putut fi finalizată. Încearcă din nou.",
        "De aankoop kon niet worden voltooid. Probeer het opnieuw.",
    ],
    "No active purchases found to restore.": [
        "未找到可恢复的有效购买。",
        "बहाल करने के लिए कोई सक्रिय ख़रीद नहीं मिली।",
        "No se encontraron compras activas que restaurar.",
        "Aucun achat actif à restaurer.",
        "Keine aktiven Käufe zum Wiederherstellen gefunden.",
        "Активных покупок для восстановления не найдено.",
        "Nenhuma compra ativa encontrada para restaurar.",
        "Nessun acquisto attivo da ripristinare.",
        "Nu s-au găsit achiziții active de restaurat.",
        "Geen actieve aankopen gevonden om te herstellen.",
    ],
    "Restore couldn't be completed. Please try again.": [
        "恢复未能完成。请再试一次。",
        "बहाली पूरी नहीं हो सकी। कृपया फिर कोशिश करें।",
        "No se pudo completar la restauración. Inténtalo de nuevo.",
        "La restauration n’a pas pu aboutir. Réessayez.",
        "Die Wiederherstellung konnte nicht abgeschlossen werden. Versuch es noch einmal.",
        "Восстановление не удалось завершить. Попробуйте снова.",
        "Não foi possível concluir a restauração. Tente novamente.",
        "Non è stato possibile completare il ripristino. Riprova.",
        "Restaurarea nu a putut fi finalizată. Încearcă din nou.",
        "Herstellen kon niet worden voltooid. Probeer het opnieuw.",
    ],
    "Silent Dawn": [
        "静谧黎明", "ख़ामोश भोर", "Alba silenciosa", "Aube silencieuse",
        "Stille Dämmerung", "Тихий рассвет", "Amanhecer silencioso",
        "Alba silenziosa", "Zori tăcuți", "Stille dageraad",
    ],
    "Golden Hour": [
        "黄金时刻", "गोल्डन आवर", "Hora dorada", "Heure dorée",
        "Goldene Stunde", "Золотой час", "Hora dourada", "Ora d’oro",
        "Ora de aur", "Gouden uur",
    ],
    "Dark Earth": [
        "暗色地球", "गहरी पृथ्वी", "Tierra oscura", "Terre sombre",
        "Dunkle Erde", "Тёмная Земля", "Terra escura", "Terra scura",
        "Pământ întunecat", "Donkere aarde",
    ],
    "1 visit": [
        "1 次到访", "1 विज़िट", "1 visita", "1 visite", "1 Besuch",
        "1 посещение", "1 visita", "1 visita", "1 vizită", "1 bezoek",
    ],
}


# The Focus Shield card's app count. It used to be a three-way switch in Swift —
# "None selected yet", the hardcoded "1 selected", and `"\(n) selected"` for
# everything else. That last branch is an interpolated String, so it was neither
# a key nor translatable, and a Spanish pilot who blocked three apps read
# "3 selected". One plural replaces all three.
PLURALS: dict[str, dict[str, dict[str, str]]] = {
    "%lld selected": {
        "en":      {"one": "%lld selected", "other": "%lld selected"},
        "zh-Hans": {"other": "已选择 %lld 个"},
        "hi":      {"one": "%lld चुना गया", "other": "%lld चुने गए"},
        # Feminine throughout the Romance languages: the noun is the app —
        # aplicación, application, app, aplicație — and Romanian was agreeing
        # with nothing at all.
        "es":      {"one": "%lld seleccionada", "other": "%lld seleccionadas"},
        "fr":      {"one": "%lld sélectionnée", "other": "%lld sélectionnées"},
        "de":      {"one": "%lld ausgewählt", "other": "%lld ausgewählt"},
        "ru":      {"one": "Выбрано: %lld", "few": "Выбрано: %lld",
                    "many": "Выбрано: %lld", "other": "Выбрано: %lld"},
        # Brazilian Portuguese says "o app", masculine.
        "pt-BR":   {"one": "%lld selecionado", "other": "%lld selecionados"},
        "it":      {"one": "%lld selezionata", "other": "%lld selezionate"},
        "ro":      {"one": "%lld selectată", "few": "%lld selectate",
                    "other": "%lld selectate"},
        "nl":      {"one": "%lld geselecteerd", "other": "%lld geselecteerd"},
    },
}


COMMENTS: dict[str, str] = {
    "%lld selected": "How many apps Focus Shield is set to block, under the "
                     "'Blocked apps' row. The noun is 'apps' — agree with it.",
    "Move to": "Section header above the list of cabin slots an item can be "
               "MOVED to. A question of destination, not an instruction to "
               "move it here — that button is 'Move Here'.",
    "Place in": "Section header above the list of cabin slots an item can be "
                "placed in. See 'Move to'.",
    "Your launch-ready Home": "Setup-checklist line. 'Home' is FocusGlobe's "
                              "Home TAB — use the same word the tab uses, not "
                              "the word for a residence.",
    "The language FocusGlobe uses": "Supporting line under the Language row in "
                                    "Settings. A short noun phrase, like the "
                                    "Sound and Reminders lines beside it.",
    "Selected": "VoiceOver only, never drawn. The state of a language row in "
                "the Settings language list: 'Español, <this>'. Agree with a "
                "language name, or use your platform's standard wording for a "
                "selected element.",
}
