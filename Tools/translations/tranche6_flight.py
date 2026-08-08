"""Tranche 6d — flight setup, the flight itself, landing and Home.

Includes the compact duration and distance formats. Those carry a number, so
each is a FORMAT: the digits come from the flight and only the unit around them
is translated. "%.1f km" keeps `%.1f` in every language and is resolved with the
locale, which is what turns "0.4 km" into "0,4 km" where that is correct.

Greeting lines and journey-phase lines are shown mid-flight, so they are short
by construction; the translations keep them short rather than explaining more
than the English does.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Compact formats --------------------------------------------------
    "%lldh %02lldm": [
        "%lld 时 %02lld 分", "%lld घं %02lld मि", "%lld h %02lld min",
        "%lld h %02lld min", "%lld Std %02lld Min", "%lld ч %02lld мин",
        "%lld h %02lld min", "%lld h %02lld min", "%lld h %02lld min",
        "%lld u %02lld min",
    ],
    "%.1f km": [
        "%.1f 公里", "%.1f किमी", "%.1f km", "%.1f km", "%.1f km", "%.1f км",
        "%.1f km", "%.1f km", "%.1f km", "%.1f km",
    ],

    # ---- Greetings --------------------------------------------------------
    "Good morning": [
        "早上好", "सुप्रभात", "Buenos días", "Bonjour", "Guten Morgen",
        "Доброе утро", "Bom dia", "Buongiorno", "Bună dimineața", "Goedemorgen",
    ],
    "Good afternoon": [
        "下午好", "नमस्कार", "Buenas tardes", "Bon après-midi", "Guten Tag",
        "Добрый день", "Boa tarde", "Buon pomeriggio", "Bună ziua", "Goedemiddag",
    ],
    "Good evening": [
        "晚上好", "शुभ संध्या", "Buenas noches", "Bonsoir", "Guten Abend",
        "Добрый вечер", "Boa noite", "Buonasera", "Bună seara", "Goedenavond",
    ],
    "Good night": [
        "晚安", "शुभ रात्रि", "Buenas noches", "Bonne nuit", "Gute Nacht",
        "Доброй ночи", "Boa noite", "Buonanotte", "Noapte bună", "Goedenacht",
    ],

    # ---- Journey phases ---------------------------------------------------
    "Taking off": [
        "正在起飞", "उड़ान भर रहे हैं", "Despegando", "Décollage",
        "Abheben", "Взлетаем", "Decolando", "In decollo", "Decolăm", "Opstijgen",
    ],
    "Settle in and breathe": [
        "坐稳，深呼吸", "आराम से बैठें और साँस लें", "Acomódate y respira",
        "Installez-vous et respirez", "Mach es dir bequem und atme",
        "Устройтесь удобно и дышите", "Acomode-se e respire",
        "Sistemati e respira", "Așază-te comod și respiră",
        "Ga zitten en adem",
    ],
    "Leaving distractions below": [
        "把干扰留在下方", "ध्यान भटकाने वाली चीज़ें नीचे छूट रही हैं",
        "Dejando las distracciones abajo", "On laisse les distractions en bas",
        "Ablenkungen bleiben unten", "Отвлечения остаются внизу",
        "Deixando as distrações lá embaixo",
        "Lasciamo le distrazioni in basso", "Lăsăm distragerile jos",
        "Afleidingen blijven beneden",
    ],
    "Stay with your focus": [
        "保持专注", "अपने फ़ोकस के साथ बने रहें", "Sigue con tu concentración",
        "Restez avec votre concentration", "Bleib bei deinem Fokus",
        "Оставайтесь в фокусе", "Continue no seu foco",
        "Resta con la tua concentrazione", "Rămâi în concentrare",
        "Blijf bij je focus",
    ],
    "Almost there — keep going": [
        "就快到了——继续", "लगभग पहुँच गए — जारी रखें", "Ya casi — sigue así",
        "On y est presque — continuez", "Fast da — weiter so",
        "Почти на месте — продолжайте", "Quase lá — continue",
        "Ci siamo quasi — continua", "Aproape gata — continuă",
        "Bijna daar — ga door",
    ],
    "Bringing you down gently": [
        "正在温柔降落", "आपको धीरे-धीरे नीचे ला रहे हैं", "Descendiendo con suavidad",
        "Descente en douceur", "Wir bringen dich sanft herunter",
        "Мягко снижаемся", "Descendo com suavidade",
        "Ti stiamo facendo scendere dolcemente", "Coborâm ușor",
        "We zetten je zacht aan de grond",
    ],
    "In flight": [
        "飞行中", "उड़ान में", "En vuelo", "En vol", "Im Flug", "В полёте",
        "Em voo", "In volo", "În zbor", "Onderweg",
    ],
    "Focus Flight": [
        "专注飞行", "फ़ोकस फ़्लाइट", "Vuelo de concentración", "Vol de concentration",
        "Fokus-Flug", "Полёт фокуса", "Voo de foco", "Volo di concentrazione",
        "Zbor de concentrare", "Focusvlucht",
    ],

    # ---- Flight setup -----------------------------------------------------
    "Choose your time": [
        "选择时长", "अपना समय चुनें", "Elige tu tiempo", "Choisissez votre durée",
        "Wähle deine Zeit", "Выберите время", "Escolha seu tempo",
        "Scegli il tuo tempo", "Alege-ți timpul", "Kies je tijd",
    ],
    "Pack your focus": [
        "整装专注", "अपना फ़ोकस पैक करें", "Prepara tu concentración",
        "Préparez votre concentration", "Pack deinen Fokus ein",
        "Соберите свой фокус", "Prepare seu foco",
        "Prepara la tua concentrazione", "Împachetează-ți concentrarea",
        "Pak je focus in",
    ],
    "Flight time": [
        "飞行时长", "फ़्लाइट समय", "Duración del vuelo", "Durée du vol",
        "Flugdauer", "Время полёта", "Duração do voo", "Durata del volo",
        "Durata zborului", "Vluchtduur",
    ],
    "FLIGHT TIME": [
        "飞行时长", "फ़्लाइट समय", "DURACIÓN", "DURÉE DU VOL",
        "FLUGDAUER", "ВРЕМЯ ПОЛЁТА", "DURAÇÃO", "DURATA VOLO",
        "DURATA ZBORULUI", "VLUCHTDUUR",
    ],
    "Endless flight": [
        "无尽飞行", "अनंत फ़्लाइट", "Vuelo sin fin", "Vol sans fin",
        "Endloser Flug", "Бесконечный полёт", "Voo sem fim", "Volo infinito",
        "Zbor fără sfârșit", "Eindeloze vlucht",
    ],
    "Infinity, FocusGlobe PRO": [
        "无限，FocusGlobe PRO", "अनंत, FocusGlobe PRO", "Infinito, FocusGlobe PRO",
        "Infini, FocusGlobe PRO", "Unendlich, FocusGlobe PRO",
        "Бесконечность, FocusGlobe PRO", "Infinito, FocusGlobe PRO",
        "Infinito, FocusGlobe PRO", "Infinit, FocusGlobe PRO",
        "Oneindig, FocusGlobe PRO",
    ],
    "Distractions grounded for the flight": [
        "整段飞行中，干扰停飞", "फ़्लाइट भर के लिए ध्यान भटकाना बंद",
        "Distracciones en tierra durante el vuelo",
        "Distractions clouées au sol pendant le vol",
        "Ablenkungen bleiben für den Flug am Boden",
        "Отвлечения остаются на земле весь полёт",
        "Distrações em terra durante o voo",
        "Distrazioni a terra per tutto il volo",
        "Distragerile rămân la sol pe durata zborului",
        "Afleidingen aan de grond tijdens de vlucht",
    ],
    "Notifications and apps stay on": [
        "通知与 App 保持开启", "नोटिफ़िकेशन और ऐप चालू रहेंगे",
        "Las notificaciones y las apps siguen activas",
        "Notifications et apps restent actives",
        "Mitteilungen und Apps bleiben an", "Уведомления и приложения останутся включёнными",
        "Notificações e apps continuam ativos",
        "Notifiche e app restano attive",
        "Notificările și aplicațiile rămân active",
        "Meldingen en apps blijven aan",
    ],
    "What's grounded": [
        "哪些被停飞", "क्या बंद रहेगा", "Qué queda en tierra",
        "Ce qui reste au sol", "Was am Boden bleibt", "Что остаётся на земле",
        "O que fica em terra", "Cosa resta a terra", "Ce rămâne la sol",
        "Wat aan de grond blijft",
    ],
    "Tap to choose apps": [
        "点按选择 App", "ऐप चुनने के लिए टैप करें", "Toca para elegir apps",
        "Touchez pour choisir les apps", "Zum Auswählen von Apps tippen",
        "Нажмите, чтобы выбрать приложения", "Toque para escolher apps",
        "Tocca per scegliere le app", "Atinge pentru a alege aplicații",
        "Tik om apps te kiezen",
    ],
    "Crew flight": [
        "机组飞行", "क्रू फ़्लाइट", "Vuelo con tripulación", "Vol en équipage",
        "Crew-Flug", "Полёт с командой", "Voo com tripulação",
        "Volo con equipaggio", "Zbor cu echipaj", "Crewvlucht",
    ],
    "Checked in.": [
        "已登记。", "चेक-इन हो गया।", "Check-in hecho.", "Enregistré.",
        "Eingecheckt.", "Регистрация пройдена.", "Check-in feito.",
        "Check-in effettuato.", "Check-in făcut.", "Ingecheckt.",
    ],
    "Not checked in.": [
        "尚未登记。", "चेक-इन नहीं हुआ।", "Sin check-in.", "Non enregistré.",
        "Nicht eingecheckt.", "Регистрация не пройдена.", "Sem check-in.",
        "Check-in non effettuato.", "Fără check-in.", "Niet ingecheckt.",
    ],
    "FLIGHT ID": [
        "航班号", "फ़्लाइट आईडी", "ID DE VUELO", "N° DE VOL",
        "FLUG-ID", "НОМЕР РЕЙСА", "ID DO VOO", "ID VOLO",
        "ID ZBOR", "VLUCHT-ID",
    ],
    "CHECK IN": [
        "登机", "चेक-इन", "CHECK-IN", "ENREGISTREMENT",
        "EINCHECKEN", "РЕГИСТРАЦИЯ", "CHECK-IN", "CHECK-IN",
        "CHECK-IN", "INCHECKEN",
    ],
    "My Expedition Page": [
        "我的远征页", "मेरा यात्रा पेज", "Mi página de expedición",
        "Ma page d’expédition", "Meine Expeditionsseite", "Моя страница экспедиции",
        "Minha página de expedição", "La mia pagina di spedizione",
        "Pagina mea de expediție", "Mijn expeditiepagina",
    ],

    # ---- In-flight controls ----------------------------------------------
    "Flight controls": [
        "飞行控制", "फ़्लाइट कंट्रोल", "Controles de vuelo", "Commandes de vol",
        "Flugsteuerung", "Управление полётом", "Controles de voo",
        "Comandi di volo", "Comenzi de zbor", "Vluchtbediening",
    ],
    "Show flight controls": [
        "显示飞行控制", "फ़्लाइट कंट्रोल दिखाएँ", "Mostrar controles de vuelo",
        "Afficher les commandes de vol", "Flugsteuerung anzeigen",
        "Показать управление полётом", "Mostrar controles de voo",
        "Mostra i comandi di volo", "Arată comenzile de zbor",
        "Toon vluchtbediening",
    ],
    "Time Focused": [
        "已专注时长", "फ़ोकस समय", "Tiempo de concentración", "Temps de concentration",
        "Fokuszeit", "Время в фокусе", "Tempo de foco",
        "Tempo di concentrazione", "Timp de concentrare", "Focustijd",
    ],
    "Time Remaining": [
        "剩余时间", "बचा समय", "Tiempo restante", "Temps restant",
        "Verbleibende Zeit", "Осталось времени", "Tempo restante",
        "Tempo rimanente", "Timp rămas", "Resterende tijd",
    ],
    "Exterior view": [
        "外景视角", "बाहरी दृश्य", "Vista exterior", "Vue extérieure",
        "Außenansicht", "Вид снаружи", "Vista externa", "Vista esterna",
        "Vedere exterioară", "Buitenaanzicht",
    ],
    "Cabin view": [
        "座舱视角", "केबिन दृश्य", "Vista de cabina", "Vue de la cabine",
        "Kabinenansicht", "Вид кабины", "Vista da cabine", "Vista della cabina",
        "Vedere din cabină", "Cabineaanzicht",
    ],
    "Look out at the Sky": [
        "眺望天空", "आकाश को निहारें", "Contempla el cielo",
        "Contemplez le ciel", "Blick hinaus in den Himmel",
        "Взгляните на небо", "Contemple o céu", "Guarda il cielo",
        "Privește cerul", "Kijk uit over de lucht",
    ],
    "Cozy up inside": [
        "在舱内窝着", "अंदर आराम से बैठें", "Acomódate dentro",
        "Installez-vous à l’intérieur", "Mach es dir drinnen gemütlich",
        "Устройтесь уютно внутри", "Fique à vontade lá dentro",
        "Sistemati dentro", "Așază-te comod înăuntru",
        "Kruip lekker naar binnen",
    ],
    "Sound on": [
        "声音开启", "आवाज़ चालू", "Sonido activado", "Son activé",
        "Ton an", "Звук включён", "Som ligado", "Audio attivo",
        "Sunet pornit", "Geluid aan",
    ],
    "Names and times stay visible": [
        "姓名与时间保持可见", "नाम और समय दिखते रहेंगे",
        "Los nombres y los tiempos siguen visibles",
        "Les noms et les durées restent visibles",
        "Namen und Zeiten bleiben sichtbar", "Имена и время остаются видимыми",
        "Nomes e tempos continuam visíveis",
        "Nomi e tempi restano visibili", "Numele și timpii rămân vizibili",
        "Namen en tijden blijven zichtbaar",
    ],
    "Names and times are hidden": [
        "姓名与时间已隐藏", "नाम और समय छिपे हैं",
        "Los nombres y los tiempos están ocultos",
        "Les noms et les durées sont masqués",
        "Namen und Zeiten sind ausgeblendet", "Имена и время скрыты",
        "Nomes e tempos estão ocultos", "Nomi e tempi sono nascosti",
        "Numele și timpii sunt ascunși", "Namen en tijden zijn verborgen",
    ],

    # ---- Leave-flight confirmation ---------------------------------------
    "This flight’s progress and rewards will be lost, and you’ll leave the Sky you’re flying in.": [
        "本次飞行的进度与奖励将会丢失，你也会离开当前所在的天空。",
        "इस फ़्लाइट की प्रगति और इनाम चले जाएँगे, और आप जिस आकाश में हैं उसे छोड़ देंगे।",
        "Perderás el progreso y las recompensas de este vuelo, y abandonarás el cielo en el que vuelas.",
        "La progression et les récompenses de ce vol seront perdues, et vous quitterez le ciel où vous volez.",
        "Fortschritt und Belohnungen dieses Flugs gehen verloren, und du verlässt den Himmel, in dem du fliegst.",
        "Прогресс и награды этого полёта будут потеряны, и вы покинете небо, в котором летите.",
        "O progresso e as recompensas deste voo serão perdidos, e você sairá do céu em que está voando.",
        "I progressi e le ricompense di questo volo andranno persi, e lascerai il cielo in cui stai volando.",
        "Progresul și recompensele acestui zbor se vor pierde, iar tu vei părăsi cerul în care zbori.",
        "De voortgang en beloningen van deze vlucht gaan verloren, en je verlaat de lucht waarin je vliegt.",
    ],
    "This open-ended flight will end here. Its progress and rewards will be lost.": [
        "这次无限时飞行将在此结束。其进度与奖励将会丢失。",
        "यह असीमित फ़्लाइट यहीं ख़त्म हो जाएगी। इसकी प्रगति और इनाम चले जाएँगे।",
        "Este vuelo sin límite acabará aquí. Se perderán su progreso y sus recompensas.",
        "Ce vol sans limite s’arrêtera ici. Sa progression et ses récompenses seront perdues.",
        "Dieser offene Flug endet hier. Fortschritt und Belohnungen gehen verloren.",
        "Этот бессрочный полёт закончится здесь. Его прогресс и награды будут потеряны.",
        "Este voo sem limite vai terminar aqui. Seu progresso e recompensas serão perdidos.",
        "Questo volo senza limite finirà qui. I suoi progressi e le ricompense andranno persi.",
        "Acest zbor fără limită se va încheia aici. Progresul și recompensele se vor pierde.",
        "Deze open vlucht eindigt hier. De voortgang en beloningen gaan verloren.",
    ],
    "This flight’s progress and rewards will be lost.": [
        "本次飞行的进度与奖励将会丢失。",
        "इस फ़्लाइट की प्रगति और इनाम चले जाएँगे।",
        "Se perderán el progreso y las recompensas de este vuelo.",
        "La progression et les récompenses de ce vol seront perdues.",
        "Fortschritt und Belohnungen dieses Flugs gehen verloren.",
        "Прогресс и награды этого полёта будут потеряны.",
        "O progresso e as recompensas deste voo serão perdidos.",
        "I progressi e le ricompense di questo volo andranno persi.",
        "Progresul și recompensele acestui zbor se vor pierde.",
        "De voortgang en beloningen van deze vlucht gaan verloren.",
    ],
    "Flight progress": [
        "飞行进度", "फ़्लाइट प्रगति", "Progreso del vuelo", "Progression du vol",
        "Flugfortschritt", "Прогресс полёта", "Progresso do voo",
        "Progressi del volo", "Progresul zborului", "Vluchtvoortgang",
    ],
    "Mission credit": [
        "任务积分", "मिशन क्रेडिट", "Crédito de misión", "Crédit de mission",
        "Missions-Gutschrift", "Зачёт задания", "Crédito da missão",
        "Credito missione", "Credit de misiune", "Missiecredit",
    ],
    "Today’s goals": [
        "今日目标", "आज के लक्ष्य", "Objetivos de hoy", "Objectifs du jour",
        "Ziele für heute", "Задачи на сегодня", "Objetivos de hoje",
        "Obiettivi di oggi", "Obiectivele de azi", "Doelen van vandaag",
    ],
    "Streak progress": [
        "连续记录进度", "स्ट्रीक प्रगति", "Progreso de la racha",
        "Progression de la série", "Serien-Fortschritt", "Прогресс серии",
        "Progresso da sequência", "Progressi della serie",
        "Progresul seriei", "Reeksvoortgang",
    ],
    "Grows on landing": [
        "着陆后增长", "लैंडिंग पर बढ़ेगा", "Crece al aterrizar",
        "Augmente à l’atterrissage", "Wächst bei der Landung",
        "Растёт при посадке", "Cresce ao pousar", "Cresce all’atterraggio",
        "Crește la aterizare", "Groeit bij de landing",
    ],
    "Your place in the Sky": [
        "你在天空中的位置", "आकाश में आपकी जगह", "Tu lugar en el cielo",
        "Votre place dans le ciel", "Dein Platz am Himmel", "Ваше место в небе",
        "Seu lugar no céu", "Il tuo posto nel cielo", "Locul tău pe cer",
        "Jouw plek in de lucht",
    ],
    "You’ll leave the room": [
        "你将离开房间", "आप रूम छोड़ देंगे", "Saldrás de la sala",
        "Vous quitterez le salon", "Du verlässt den Raum", "Вы покинете комнату",
        "Você sairá da sala", "Uscirai dalla stanza", "Vei părăsi camera",
        "Je verlaat de ruimte",
    ],
    "2× PRO": [
        "2× PRO", "2× PRO", "2× PRO", "2× PRO", "2× PRO", "2× PRO",
        "2× PRO", "2× PRO", "2× PRO", "2× PRO",
    ],

    # ---- Home -------------------------------------------------------------
    "Previous Sky": [
        "上一片天空", "पिछला आकाश", "Cielo anterior", "Ciel précédent",
        "Vorheriger Himmel", "Предыдущее небо", "Céu anterior",
        "Cielo precedente", "Cerul anterior", "Vorige lucht",
    ],
    "Next Sky": [
        "下一片天空", "अगला आकाश", "Cielo siguiente", "Ciel suivant",
        "Nächster Himmel", "Следующее небо", "Próximo céu",
        "Cielo successivo", "Cerul următor", "Volgende lucht",
    ],
    "Unlock this Sky to fly here": [
        "解锁这片天空即可在此飞行", "यहाँ उड़ने के लिए यह आकाश अनलॉक करें",
        "Desbloquea este cielo para volar aquí",
        "Débloquez ce ciel pour y voler", "Schalte diesen Himmel frei, um hier zu fliegen",
        "Откройте это небо, чтобы летать здесь",
        "Desbloqueie este céu para voar aqui",
        "Sblocca questo cielo per volarci", "Deblochează acest cer ca să zbori aici",
        "Ontgrendel deze lucht om hier te vliegen",
    ],
    "Ready to drift?": [
        "准备好漂流了吗？", "बहने के लिए तैयार?", "¿Te dejas llevar?",
        "Envie de vous laisser porter ?", "Bereit zum Dahingleiten?",
        "Готовы отправиться в дрейф?", "Que tal flutuar?",
        "Ti va di lasciarti andare?", "Gata să plutești?", "Klaar om te zweven?",
    ],
    "Pick a route. Stay focused until you land.": [
        "选一条航线，专注到降落为止。",
        "एक रास्ता चुनें। लैंडिंग तक फ़ोकस बनाए रखें।",
        "Elige una ruta. Mantén la concentración hasta aterrizar.",
        "Choisissez un itinéraire. Gardez la concentration jusqu’à l’atterrissage.",
        "Wähle eine Route. Bleib fokussiert bis zur Landung.",
        "Выберите маршрут. Оставайтесь в фокусе до посадки.",
        "Escolha uma rota. Mantenha o foco até pousar.",
        "Scegli una rotta. Mantieni la concentrazione fino all’atterraggio.",
        "Alege o rută. Menține concentrarea până aterizezi.",
        "Kies een route. Blijf gefocust tot je landt.",
    ],
    "Leave distractions below.": [
        "把干扰留在下方。", "ध्यान भटकाने वाली चीज़ें नीचे छोड़ दें।",
        "Deja las distracciones abajo.", "Laissez les distractions en bas.",
        "Lass Ablenkungen unter dir.", "Оставьте отвлечения внизу.",
        "Deixe as distrações lá embaixo.", "Lascia le distrazioni in basso.",
        "Lasă distragerile jos.", "Laat afleidingen beneden.",
    ],

    # ---- Streak details ---------------------------------------------------
    "Land a journey today to start your streak.": [
        "今天完成一次旅程，开启你的连续记录。",
        "अपनी स्ट्रीक शुरू करने के लिए आज एक यात्रा पूरी करें।",
        "Aterriza un viaje hoy para empezar tu racha.",
        "Terminez un voyage aujourd’hui pour lancer votre série.",
        "Lande heute eine Reise, um deine Serie zu starten.",
        "Завершите путешествие сегодня, чтобы начать серию.",
        "Pouse uma viagem hoje para começar sua sequência.",
        "Atterra oggi per iniziare la tua serie.",
        "Aterizează o călătorie azi ca să-ți începi seria.",
        "Land vandaag een reis om je reeks te starten.",
    ],
    "Great start — come back tomorrow to keep it alive.": [
        "开局很好——明天再来延续它。",
        "बढ़िया शुरुआत — कल फिर आकर इसे बनाए रखें।",
        "Buen comienzo: vuelve mañana para mantenerla.",
        "Bon début — revenez demain pour la faire vivre.",
        "Guter Start — komm morgen wieder, um sie zu halten.",
        "Отличное начало — вернитесь завтра, чтобы её сохранить.",
        "Ótimo começo — volte amanhã para mantê-la viva.",
        "Ottimo inizio: torna domani per tenerla viva.",
        "Început bun — revino mâine ca s-o ții vie.",
        "Goede start — kom morgen terug om je reeks te behouden.",
    ],
    "You're building momentum. Keep flying daily.": [
        "你正在积累势头。每天都飞。",
        "आप रफ़्तार बना रहे हैं। रोज़ उड़ते रहें।",
        "Estás ganando impulso. Sigue volando a diario.",
        "Vous prenez de l’élan. Continuez à voler chaque jour.",
        "Du baust Schwung auf. Flieg weiter, jeden Tag.",
        "Вы набираете темп. Летайте каждый день.",
        "Você está ganhando impulso. Continue voando todo dia.",
        "Stai prendendo slancio. Continua a volare ogni giorno.",
        "Prinzi avânt. Continuă să zbori zilnic.",
        "Je bouwt vaart op. Blijf dagelijks vliegen.",
    ],
    "Incredible focus. Protect your streak today.": [
        "了不起的专注。今天守住你的连续记录。",
        "ज़बरदस्त फ़ोकस। आज अपनी स्ट्रीक बचाएँ।",
        "Concentración increíble. Protege tu racha hoy.",
        "Une concentration remarquable. Protégez votre série aujourd’hui.",
        "Unglaublicher Fokus. Schütze deine Serie heute.",
        "Невероятный фокус. Сохраните серию сегодня.",
        "Foco incrível. Proteja sua sequência hoje.",
        "Concentrazione incredibile. Proteggi la tua serie oggi.",
        "Concentrare incredibilă. Apără-ți seria azi.",
        "Ongelooflijke focus. Bescherm je reeks vandaag.",
    ],
    "Landed today — your streak is safe": [
        "今天已降落——连续记录安全了",
        "आज लैंड कर लिया — आपकी स्ट्रीक सुरक्षित है",
        "Aterrizaste hoy: tu racha está a salvo",
        "Vol atterri aujourd’hui — votre série est sauve",
        "Heute gelandet — deine Serie ist sicher",
        "Сегодня приземлились — серия в безопасности",
        "Pousou hoje — sua sequência está segura",
        "Volo atterrato oggi: la tua serie è al sicuro",
        "Ai aterizat azi — seria ta e în siguranță",
        "Vandaag geland — je reeks is veilig",
    ],
    "Land a flight today to keep the streak alive": [
        "今天完成一次飞行，延续连续记录",
        "स्ट्रीक बनाए रखने के लिए आज एक फ़्लाइट पूरी करें",
        "Aterriza un vuelo hoy para mantener la racha",
        "Terminez un vol aujourd’hui pour garder la série",
        "Lande heute einen Flug, um die Serie zu halten",
        "Завершите полёт сегодня, чтобы сохранить серию",
        "Pouse um voo hoje para manter a sequência",
        "Atterra oggi per tenere viva la serie",
        "Aterizează un zbor azi ca să păstrezi seria",
        "Land vandaag een vlucht om de reeks te behouden",
    ],

    # ---- Daily goals ------------------------------------------------------
    "Complete one flight": [
        "完成一次飞行", "एक फ़्लाइट पूरी करें", "Completa un vuelo",
        "Terminez un vol", "Schließe einen Flug ab", "Завершите один полёт",
        "Conclua um voo", "Completa un volo", "Încheie un zbor",
        "Voltooi één vlucht",
    ],
    "Focus 30 minutes": [
        "专注 30 分钟", "30 मिनट फ़ोकस करें", "Concéntrate 30 minutos",
        "Concentrez-vous 30 minutes", "30 Minuten fokussieren",
        "Сфокусируйтесь 30 минут", "Foque 30 minutos",
        "Concentrati 30 minuti", "Concentrează-te 30 de minute",
        "Focus 30 minuten",
    ],
    "Spin the Free Coin Spin": [
        "转动免费金币轮盘", "फ़्री कॉइन स्पिन घुमाएँ",
        "Gira la ruleta de monedas gratis", "Lancez le tour de pièces gratuit",
        "Dreh am kostenlosen Münzen-Rad", "Крутите бесплатное колесо монет",
        "Gire o giro de moedas grátis", "Gira la ruota delle monete gratis",
        "Învârte roata gratuită de monede", "Draai aan de gratis muntenspin",
    ],
    "Earn 10 Focus Coins": [
        "赚取 10 枚专注金币", "10 फ़ोकस सिक्के कमाएँ",
        "Consigue 10 monedas de concentración", "Gagnez 10 pièces de concentration",
        "Verdiene 10 Fokus-Münzen", "Заработайте 10 монет фокуса",
        "Ganhe 10 moedas de foco", "Guadagna 10 monete di concentrazione",
        "Câștigă 10 monede de concentrare", "Verdien 10 focusmunten",
    ],

    # ---- Landing ----------------------------------------------------------
    "Coins ×2": [
        "金币 ×2", "सिक्के ×2", "Monedas ×2", "Pièces ×2", "Münzen ×2",
        "Монеты ×2", "Moedas ×2", "Monete ×2", "Monede ×2", "Munten ×2",
    ],
}
