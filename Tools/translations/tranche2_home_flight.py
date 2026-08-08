"""Tranche 2 — Home, the flight-setup ritual, the active flight, and landing.

Glossary applied here (see build_string_catalog.py for the full table):
Flight · Sky · Streak · Coins · Cabin · Focus Shield — one term per language,
reused. `FocusGlobe`, `FocusGlobe PRO` and `PRO` are never translated.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Home: rewards, coin spin ---------------------------------------
    "Free Coin Spin": [
        "免费转盘", "फ़्री कॉइन स्पिन", "Giro de monedas gratis", "Tour de pièces gratuit",
        "Gratis-Münzendreh", "Бесплатный спин", "Giro de moedas grátis",
        "Giro monete gratis", "Rotire gratuită de monede", "Gratis muntendraai"],
    "Free Coin Spin. Watch a video to spin for Focus Coins.": [
        "免费转盘。观看视频即可转出专注金币。",
        "फ़्री कॉइन स्पिन। फ़ोकस सिक्कों के लिए वीडियो देखें।",
        "Giro de monedas gratis. Mira un video para girar y ganar monedas de concentración.",
        "Tour de pièces gratuit. Regardez une vidéo pour tenter de gagner des pièces.",
        "Gratis-Münzendreh. Sieh ein Video und drehe um Fokus-Münzen.",
        "Бесплатный спин. Посмотрите видео и крутите ради монет фокуса.",
        "Giro de moedas grátis. Assista a um vídeo para girar e ganhar moedas de foco.",
        "Giro monete gratis. Guarda un video per girare e vincere monete.",
        "Rotire gratuită de monede. Vezi un clip ca să rotești pentru monede.",
        "Gratis muntendraai. Bekijk een video om te draaien voor focusmunten."],
    "WIN UP TO 25 COINS!": [
        "最高可赢 25 金币！", "25 सिक्के तक जीतें!", "¡GANA HASTA 25 MONEDAS!",
        "GAGNEZ JUSQU’À 25 PIÈCES !", "GEWINNE BIS ZU 25 MÜNZEN!",
        "ВЫИГРАЙТЕ ДО 25 МОНЕТ!", "GANHE ATÉ 25 MOEDAS!", "VINCI FINO A 25 MONETE!",
        "CÂȘTIGĂ PÂNĂ LA 25 DE MONEDE!", "WIN TOT 25 MUNTEN!"],
    "Spinning…": ["转动中…", "घूम रहा है…", "Girando…", "Rotation…", "Dreht…",
                  "Крутится…", "Girando…", "In rotazione…", "Se rotește…", "Draait…"],
    "You won": ["你赢得了", "आपने जीते", "Ganaste", "Vous avez gagné", "Du hast gewonnen",
                "Вы выиграли", "Você ganhou", "Hai vinto", "Ai câștigat", "Je hebt gewonnen"],
    "Coins Boost Gifted": [
        "已赠送金币加成", "कॉइन बूस्ट उपहार में मिला", "Impulso de monedas regalado",
        "Bonus de pièces offert", "Münzen-Boost geschenkt", "Подарен бустер монет",
        "Impulso de moedas presenteado", "Boost monete regalato",
        "Impuls de monede oferit", "Muntenboost cadeau"],
    "Double your Coins for your next study hour once equipped.": [
        "装备后，下一小时学习的金币翻倍。",
        "लैस करने पर आपके अगले अध्ययन घंटे के सिक्के दोगुने।",
        "Duplica tus monedas en tu próxima hora de estudio al equiparlo.",
        "Doublez vos pièces sur votre prochaine heure d’étude une fois équipé.",
        "Verdopple deine Münzen in der nächsten Lernstunde, sobald es ausgerüstet ist.",
        "Удвойте монеты за следующий час занятий после экипировки.",
        "Dobre suas moedas na próxima hora de estudo depois de equipar.",
        "Raddoppia le monete nella prossima ora di studio una volta equipaggiato.",
        "Dublează-ți monedele în următoarea oră de studiu după echipare.",
        "Verdubbel je munten in je volgende studie-uur zodra het uitgerust is."],
    "Awesome, thanks": [
        "太好了，谢谢", "बढ़िया, धन्यवाद", "Genial, gracias", "Super, merci",
        "Super, danke", "Отлично, спасибо", "Ótimo, obrigado", "Fantastico, grazie",
        "Super, mulțumesc", "Top, bedankt"],
    "1h Max Duration": [
        "最长 1 小时", "अधिकतम 1 घंटा", "Duración máx. 1 h", "Durée max. 1 h",
        "Max. 1 Std. Dauer", "Макс. 1 час", "Duração máx. 1 h", "Durata max 1 h",
        "Durată max. 1 h", "Max. duur 1 u"],
    "Coins Boost active: double coins on your next flight.": [
        "金币加成已激活：下次飞行金币翻倍。",
        "कॉइन बूस्ट सक्रिय: आपकी अगली फ़्लाइट पर दोगुने सिक्के।",
        "Impulso de monedas activo: monedas dobles en tu próximo vuelo.",
        "Bonus de pièces actif : pièces doublées sur votre prochain vol.",
        "Münzen-Boost aktiv: doppelte Münzen beim nächsten Flug.",
        "Бустер монет активен: двойные монеты в следующем полёте.",
        "Impulso de moedas ativo: moedas em dobro no próximo voo.",
        "Boost monete attivo: monete doppie nel prossimo volo.",
        "Impuls de monede activ: monede duble la următorul zbor.",
        "Muntenboost actief: dubbele munten bij je volgende vlucht."],

    # ---- Home: journey grid ---------------------------------------------
    "YOUR FOCUS JOURNEY": [
        "你的专注旅程", "आपकी फ़ोकस यात्रा", "TU VIAJE DE CONCENTRACIÓN",
        "VOTRE PARCOURS DE CONCENTRATION", "DEINE FOKUS-REISE", "ВАШ ПУТЬ ФОКУСА",
        "SUA JORNADA DE FOCO", "IL TUO PERCORSO DI CONCENTRAZIONE",
        "CĂLĂTORIA TA DE CONCENTRARE", "JOUW FOCUSREIS"],
    "Share your focus grid": [
        "分享你的专注格图", "अपना फ़ोकस ग्रिड शेयर करें", "Comparte tu cuadrícula de concentración",
        "Partagez votre grille de concentration", "Teile dein Fokus-Raster",
        "Поделиться сеткой фокуса", "Compartilhe sua grade de foco",
        "Condividi la tua griglia di concentrazione", "Distribuie grila ta de concentrare",
        "Deel je focusraster"],
    "Every gold square is a day you truly focused. Keep the sky lit.": [
        "每个金色方块都是你真正专注的一天。让天空持续点亮。",
        "हर सुनहरा वर्ग वह दिन है जब आपने सचमुच फ़ोकस किया। आकाश को जगमगाता रखें।",
        "Cada cuadro dorado es un día en el que te concentraste de verdad. Mantén el cielo encendido.",
        "Chaque carré doré est un jour où vous vous êtes vraiment concentré. Gardez le ciel allumé.",
        "Jedes goldene Feld ist ein Tag mit echtem Fokus. Halte den Himmel erleuchtet.",
        "Каждый золотой квадрат — день настоящего фокуса. Пусть небо горит.",
        "Cada quadrado dourado é um dia em que você realmente focou. Mantenha o céu aceso.",
        "Ogni quadrato dorato è un giorno di vera concentrazione. Tieni il cielo acceso.",
        "Fiecare pătrat auriu e o zi în care chiar te-ai concentrat. Ține cerul aprins.",
        "Elk gouden vakje is een dag waarop je echt focuste. Houd de lucht verlicht."],
    "day streak": [
        "天连续记录", "दिन की स्ट्रीक", "días de racha", "jours de série",
        "Tage Serie", "дней подряд", "dias de sequência", "giorni di serie",
        "zile la rând", "dagen op rij"],
    "THIS WEEK": ["本周", "इस सप्ताह", "ESTA SEMANA", "CETTE SEMAINE", "DIESE WOCHE",
                  "НА ЭТОЙ НЕДЕЛЕ", "ESTA SEMANA", "QUESTA SETTIMANA",
                  "SĂPTĂMÂNA ACEASTA", "DEZE WEEK"],
    "TODAY'S GOALS": [
        "今日目标", "आज के लक्ष्य", "OBJETIVOS DE HOY", "OBJECTIFS DU JOUR",
        "HEUTIGE ZIELE", "ЦЕЛИ НА СЕГОДНЯ", "METAS DE HOJE", "OBIETTIVI DI OGGI",
        "OBIECTIVELE DE AZI", "DOELEN VAN VANDAAG"],

    # ---- Home: primary controls -----------------------------------------
    "Start Focus": [
        "开始专注", "फ़ोकस शुरू करें", "Empezar a concentrarte", "Commencer à se concentrer",
        "Fokus starten", "Начать фокус", "Começar a focar", "Inizia a concentrarti",
        "Începe concentrarea", "Start focus"],
    "Checking PRO access…": [
        "正在检查 PRO 权限…", "PRO एक्सेस जाँच रहे हैं…", "Comprobando el acceso PRO…",
        "Vérification de l’accès PRO…", "PRO-Zugriff wird geprüft…",
        "Проверяем доступ PRO…", "Verificando o acesso PRO…",
        "Verifica dell’accesso PRO…", "Verificăm accesul PRO…", "PRO-toegang controleren…"],
    "Checking FocusGlobe PRO access": [
        "正在检查 FocusGlobe PRO 权限", "FocusGlobe PRO एक्सेस जाँच रहे हैं",
        "Comprobando el acceso a FocusGlobe PRO", "Vérification de l’accès à FocusGlobe PRO",
        "FocusGlobe PRO-Zugriff wird geprüft", "Проверяем доступ к FocusGlobe PRO",
        "Verificando o acesso ao FocusGlobe PRO", "Verifica dell’accesso a FocusGlobe PRO",
        "Verificăm accesul la FocusGlobe PRO", "FocusGlobe PRO-toegang controleren"],
    "Resume your flight": [
        "继续你的飞行", "अपनी फ़्लाइट फिर से शुरू करें", "Reanuda tu vuelo",
        "Reprenez votre vol", "Setze deinen Flug fort", "Продолжите полёт",
        "Retome seu voo", "Riprendi il volo", "Reia-ți zborul", "Hervat je vlucht"],
    "Resume your unfinished flight": [
        "继续未完成的飞行", "अपनी अधूरी फ़्लाइट फिर से शुरू करें",
        "Reanuda tu vuelo sin terminar", "Reprenez votre vol inachevé",
        "Setze deinen unbeendeten Flug fort", "Продолжите незавершённый полёт",
        "Retome seu voo não concluído", "Riprendi il volo non completato",
        "Reia zborul neterminat", "Hervat je onafgemaakte vlucht"],
    "Resume your flight?": [
        "继续你的飞行？", "अपनी फ़्लाइट फिर से शुरू करें?", "¿Reanudar tu vuelo?",
        "Reprendre votre vol ?", "Flug fortsetzen?", "Продолжить полёт?",
        "Retomar seu voo?", "Riprendere il volo?", "Reiei zborul?", "Vlucht hervatten?"],
    "Continue flight": [
        "继续飞行", "फ़्लाइट जारी रखें", "Continuar el vuelo", "Continuer le vol",
        "Flug fortsetzen", "Продолжить полёт", "Continuar o voo", "Continua il volo",
        "Continuă zborul", "Vlucht voortzetten"],
    "Continue flying": [
        "继续飞行", "उड़ान जारी रखें", "Seguir volando", "Continuer à voler",
        "Weiterfliegen", "Продолжать полёт", "Continuar voando", "Continua a volare",
        "Continuă să zbori", "Blijf vliegen"],
    "Start a new Focus": [
        "开始新的专注", "नया फ़ोकस शुरू करें", "Empezar una nueva concentración",
        "Démarrer une nouvelle session", "Neuen Fokus starten", "Начать новый фокус",
        "Começar um novo foco", "Inizia una nuova concentrazione",
        "Începe o concentrare nouă", "Nieuwe focus starten"],
    "Keep focusing": [
        "继续专注", "फ़ोकस बनाए रखें", "Sigue concentrado", "Restez concentré",
        "Bleib fokussiert", "Продолжайте фокус", "Continue focado",
        "Resta concentrato", "Rămâi concentrat", "Blijf gefocust"],
    "Unlock FocusGlobe PRO": [
        "解锁 FocusGlobe PRO", "FocusGlobe PRO अनलॉक करें", "Desbloquea FocusGlobe PRO",
        "Débloquez FocusGlobe PRO", "FocusGlobe PRO freischalten",
        "Откройте FocusGlobe PRO", "Desbloqueie o FocusGlobe PRO",
        "Sblocca FocusGlobe PRO", "Deblochează FocusGlobe PRO", "Ontgrendel FocusGlobe PRO"],
    "Maybe later": [
        "以后再说", "बाद में", "Quizá más tarde", "Peut-être plus tard",
        "Vielleicht später", "Может быть, позже", "Talvez depois", "Forse più tardi",
        "Poate mai târziu", "Misschien later"],

    # ---- Active flight ---------------------------------------------------
    "Reconnecting…": [
        "正在重新连接…", "फिर से कनेक्ट हो रहे हैं…", "Reconectando…", "Reconnexion…",
        "Verbindung wird wiederhergestellt…", "Переподключение…", "Reconectando…",
        "Riconnessione…", "Se reconectează…", "Opnieuw verbinden…"],
    "Paused. Tap to resume.": [
        "已暂停。点按继续。", "रुका हुआ। जारी रखने के लिए टैप करें।",
        "En pausa. Toca para reanudar.", "En pause. Touchez pour reprendre.",
        "Pausiert. Zum Fortsetzen tippen.", "Пауза. Нажмите, чтобы продолжить.",
        "Pausado. Toque para retomar.", "In pausa. Tocca per riprendere.",
        "În pauză. Atinge pentru a relua.", "Gepauzeerd. Tik om te hervatten."],
    "Land now": ["立即降落", "अभी लैंड करें", "Aterrizar ahora", "Atterrir maintenant",
                 "Jetzt landen", "Приземлиться", "Pousar agora", "Atterra ora",
                 "Aterizează acum", "Nu landen"],
    "Hold to leave": [
        "长按以离开", "छोड़ने के लिए दबाए रखें", "Mantén pulsado para salir",
        "Maintenez pour quitter", "Zum Verlassen halten", "Удерживайте, чтобы выйти",
        "Segure para sair", "Tieni premuto per uscire", "Ține apăsat pentru a ieși",
        "Houd vast om te verlaten"],
    "Leave flight": [
        "离开飞行", "फ़्लाइट छोड़ें", "Salir del vuelo", "Quitter le vol",
        "Flug verlassen", "Покинуть полёт", "Sair do voo", "Esci dal volo",
        "Părăsește zborul", "Vlucht verlaten"],
    "Leave Flight": [
        "离开飞行", "फ़्लाइट छोड़ें", "Salir del vuelo", "Quitter le vol",
        "Flug verlassen", "Покинуть полёт", "Sair do voo", "Esci dal volo",
        "Părăsește zborul", "Vlucht verlaten"],
    "Leave this flight?": [
        "离开这次飞行？", "यह फ़्लाइट छोड़ें?", "¿Salir de este vuelo?",
        "Quitter ce vol ?", "Diesen Flug verlassen?", "Покинуть этот полёт?",
        "Sair deste voo?", "Uscire da questo volo?", "Părăsești acest zbor?",
        "Deze vlucht verlaten?"],
    "Keep Focusing": [
        "继续专注", "फ़ोकस बनाए रखें", "Seguir concentrado", "Rester concentré",
        "Fokussiert bleiben", "Продолжить фокус", "Continuar focado",
        "Resta concentrato", "Rămâi concentrat", "Blijf gefocust"],
    "Ends this flight now. Its progress and rewards are not kept.": [
        "立即结束本次飞行。其进度与奖励不会保留。",
        "यह फ़्लाइट अभी समाप्त होगी। इसकी प्रगति और इनाम सुरक्षित नहीं रहेंगे।",
        "Termina este vuelo ahora. Su progreso y recompensas no se conservan.",
        "Met fin au vol maintenant. Sa progression et ses récompenses ne sont pas conservées.",
        "Beendet diesen Flug sofort. Fortschritt und Belohnungen bleiben nicht erhalten.",
        "Завершает полёт сейчас. Прогресс и награды не сохраняются.",
        "Encerra este voo agora. O progresso e as recompensas não são mantidos.",
        "Termina subito questo volo. Progressi e ricompense non vengono conservati.",
        "Încheie acest zbor acum. Progresul și recompensele nu se păstrează.",
        "Beëindigt deze vlucht nu. Voortgang en beloningen blijven niet bewaard."],
    "Press and hold to open the leave confirmation.": [
        "长按以打开离开确认。", "छोड़ने की पुष्टि खोलने के लिए दबाए रखें।",
        "Mantén pulsado para abrir la confirmación de salida.",
        "Appuyez longuement pour ouvrir la confirmation de sortie.",
        "Gedrückt halten, um die Verlassen-Bestätigung zu öffnen.",
        "Нажмите и удерживайте, чтобы открыть подтверждение выхода.",
        "Pressione e segure para abrir a confirmação de saída.",
        "Tieni premuto per aprire la conferma di uscita.",
        "Apasă lung pentru a deschide confirmarea de ieșire.",
        "Houd ingedrukt om de bevestiging te openen."],
    "FLIGHT CONTROLS": [
        "飞行控制", "फ़्लाइट कंट्रोल", "CONTROLES DE VUELO", "COMMANDES DE VOL",
        "FLUGSTEUERUNG", "УПРАВЛЕНИЕ ПОЛЁТОМ", "CONTROLES DE VOO",
        "COMANDI DI VOLO", "COMENZI DE ZBOR", "VLUCHTBEDIENING"],
    "Show pilot labels": [
        "显示飞行员标签", "पायलट लेबल दिखाएँ", "Mostrar etiquetas de pilotos",
        "Afficher les noms des pilotes", "Pilotennamen anzeigen",
        "Показывать имена пилотов", "Mostrar nomes dos pilotos",
        "Mostra i nomi dei piloti", "Afișează numele piloților", "Pilootlabels tonen"],
    "Clean mode": [
        "简洁模式", "क्लीन मोड", "Modo limpio", "Mode épuré", "Klarer Modus",
        "Чистый режим", "Modo limpo", "Modalità essenziale", "Mod curat", "Schone modus"],
    "Hide controls, keep a tiny timer": [
        "隐藏控件，仅保留小计时器", "कंट्रोल छिपाएँ, छोटा टाइमर रखें",
        "Oculta los controles y deja un temporizador pequeño",
        "Masque les commandes, garde un minuteur discret",
        "Bedienelemente ausblenden, kleinen Timer behalten",
        "Скрыть элементы управления, оставить маленький таймер",
        "Oculta os controles e mantém um cronômetro pequeno",
        "Nascondi i comandi, lascia un piccolo timer",
        "Ascunde comenzile, păstrează un cronometru mic",
        "Verberg bediening, houd een kleine timer"],
    "See who's flying with you": [
        "查看谁在与你同飞", "देखें कौन आपके साथ उड़ रहा है",
        "Mira quién vuela contigo", "Voyez qui vole avec vous",
        "Sieh, wer mit dir fliegt", "Посмотрите, кто летит с вами",
        "Veja quem está voando com você", "Guarda chi vola con te",
        "Vezi cine zboară cu tine", "Zie wie er met je meevliegt"],
    "Invite Friends": [
        "邀请好友", "दोस्तों को आमंत्रित करें", "Invitar a amigos", "Inviter des amis",
        "Freunde einladen", "Пригласить друзей", "Convidar amigos", "Invita amici",
        "Invită prieteni", "Vrienden uitnodigen"],
    "Add Friend": [
        "添加好友", "दोस्त जोड़ें", "Añadir amigo", "Ajouter un ami",
        "Freund hinzufügen", "Добавить друга", "Adicionar amigo", "Aggiungi amico",
        "Adaugă prieten", "Vriend toevoegen"],
    "View profile": [
        "查看资料", "प्रोफ़ाइल देखें", "Ver perfil", "Voir le profil",
        "Profil ansehen", "Открыть профиль", "Ver perfil", "Vedi profilo",
        "Vezi profilul", "Profiel bekijken"],
    "Hide this pilot": [
        "隐藏该飞行员", "इस पायलट को छिपाएँ", "Ocultar a este piloto",
        "Masquer ce pilote", "Diesen Piloten ausblenden", "Скрыть этого пилота",
        "Ocultar este piloto", "Nascondi questo pilota", "Ascunde acest pilot",
        "Deze piloot verbergen"],
    "Flight Mode": [
        "飞行模式", "फ़्लाइट मोड", "Modo vuelo", "Mode vol", "Flugmodus",
        "Режим полёта", "Modo voo", "Modalità volo", "Mod zbor", "Vluchtmodus"],
    "Protected flights ground your chosen apps for the whole journey, so the sky stays yours.": [
        "受保护的飞行会在整个旅程中停用你选择的应用，让天空只属于你。",
        "सुरक्षित फ़्लाइट पूरी यात्रा के दौरान आपके चुने ऐप्स को रोक देती है, ताकि आकाश आपका ही रहे।",
        "Los vuelos protegidos dejan en tierra las apps que elijas durante todo el trayecto, para que el cielo siga siendo tuyo.",
        "Les vols protégés clouent au sol les applis que vous choisissez pendant tout le trajet, pour que le ciel reste le vôtre.",
        "Geschützte Flüge legen deine gewählten Apps für die ganze Reise still, damit der Himmel dir gehört.",
        "Защищённые полёты отключают выбранные приложения на всё путешествие, чтобы небо осталось вашим.",
        "Voos protegidos deixam os apps escolhidos em terra durante toda a viagem, para o céu continuar sendo seu.",
        "I voli protetti tengono a terra le app che scegli per tutto il viaggio, così il cielo resta tuo.",
        "Zborurile protejate țin la sol aplicațiile alese pe toată durata călătoriei, ca cerul să rămână al tău.",
        "Beschermde vluchten houden je gekozen apps aan de grond tijdens de hele reis, zodat de lucht van jou blijft."],
    "Focus started": [
        "专注已开始", "फ़ोकस शुरू हुआ", "Concentración iniciada", "Concentration lancée",
        "Fokus gestartet", "Фокус начат", "Foco iniciado", "Concentrazione avviata",
        "Concentrarea a început", "Focus gestart"],

    # ---- Boarding ritual -------------------------------------------------
    "BOARDING PASS": [
        "登机牌", "बोर्डिंग पास", "TARJETA DE EMBARQUE", "CARTE D’EMBARQUEMENT",
        "BORDKARTE", "ПОСАДОЧНЫЙ ТАЛОН", "CARTÃO DE EMBARQUE", "CARTA D’IMBARCO",
        "TICHET DE ÎMBARCARE", "INSTAPKAART"],
    "Tear the barcode across to board": [
        "横向撕开条码即可登机", "बोर्ड करने के लिए बारकोड को आर-पार फाड़ें",
        "Rasga el código de barras para embarcar",
        "Déchirez le code-barres pour embarquer",
        "Reiße den Barcode quer ein, um einzusteigen",
        "Порвите штрихкод поперёк, чтобы сесть на борт",
        "Rasgue o código de barras para embarcar",
        "Strappa il codice a barre per imbarcarti",
        "Rupe codul de bare ca să te îmbarci",
        "Scheur de streepjescode door om in te stappen"],
    "Check in": ["办理登机", "चेक इन", "Facturación", "Enregistrement", "Check-in",
                 "Регистрация", "Check-in", "Check-in", "Check-in", "Inchecken"],
    "Ready to fly": [
        "准备起飞", "उड़ान के लिए तैयार", "Listo para volar", "Prêt à décoller",
        "Startbereit", "Готов к полёту", "Pronto para voar", "Pronto al decollo",
        "Gata de zbor", "Klaar om te vliegen"],
    "What are you bringing aboard?": [
        "你要带什么上机？", "आप क्या साथ ले जा रहे हैं?", "¿Qué llevas a bordo?",
        "Qu’emportez-vous à bord ?", "Was nimmst du an Bord?",
        "Что вы берёте на борт?", "O que você está levando a bordo?",
        "Cosa porti a bordo?", "Ce iei la bord?", "Wat neem je mee aan boord?"],
    "Bringing aboard": [
        "正在带上机", "साथ ले जा रहे हैं", "Llevando a bordo", "Embarquement en cours",
        "Wird an Bord gebracht", "Берём на борт", "Levando a bordo",
        "Portando a bordo", "Se ia la bord", "Aan boord brengen"],
    "Board the balloon": [
        "登上热气球", "गुब्बारे पर सवार हों", "Sube al globo", "Montez dans la montgolfière",
        "Steig in den Ballon", "Поднимитесь на борт шара", "Embarque no balão",
        "Sali sulla mongolfiera", "Urcă în balon", "Stap in de ballon"],
    "Set Off": ["出发", "प्रस्थान करें", "Partir", "Partir", "Losfliegen",
                "Отправиться", "Partir", "Parti", "Pornește", "Vertrekken"],
    "Wax seal — set off": [
        "火漆封印 — 出发", "मोम की मुहर — प्रस्थान", "Sello de cera: partir",
        "Sceau de cire — partir", "Wachssiegel – losfliegen", "Восковая печать — отправиться",
        "Selo de cera — partir", "Sigillo di cera — parti", "Sigiliu de ceară — pornește",
        "Lakzegel — vertrekken"],
    "Double-tap to seal the page and begin the expedition": [
        "双击封印此页并开始远征。", "पेज पर मुहर लगाकर अभियान शुरू करने के लिए डबल-टैप करें",
        "Toca dos veces para sellar la página y empezar la expedición",
        "Touchez deux fois pour sceller la page et commencer l’expédition",
        "Doppeltippen, um die Seite zu siegeln und die Expedition zu starten",
        "Дважды коснитесь, чтобы запечатать страницу и начать экспедицию",
        "Toque duas vezes para selar a página e iniciar a expedição",
        "Tocca due volte per sigillare la pagina e iniziare la spedizione",
        "Atinge de două ori ca să sigilezi pagina și să începi expediția",
        "Dubbeltik om de pagina te verzegelen en de expeditie te starten"],
    "hold to seal": [
        "长按以封印", "मुहर के लिए दबाए रखें", "mantén pulsado para sellar",
        "maintenez pour sceller", "zum Siegeln halten", "удерживайте для печати",
        "segure para selar", "tieni premuto per sigillare", "ține apăsat pentru sigiliu",
        "houd vast om te verzegelen"],

    # ---- Landing ---------------------------------------------------------
    "Success!": ["成功！", "सफलता!", "¡Conseguido!", "Réussi !", "Geschafft!",
                 "Готово!", "Conseguiu!", "Riuscito!", "Reușit!", "Gelukt!"],
    "Focus Type": [
        "专注类型", "फ़ोकस प्रकार", "Tipo de concentración", "Type de concentration",
        "Fokus-Art", "Тип фокуса", "Tipo de foco", "Tipo di concentrazione",
        "Tipul concentrării", "Focustype"],
    "2× PRO Coins": [
        "2 倍 PRO 金币", "2× PRO सिक्के", "Monedas PRO ×2", "Pièces PRO ×2",
        "2× PRO-Münzen", "2× PRO-монеты", "Moedas PRO 2×", "Monete PRO 2×",
        "Monede PRO 2×", "2× PRO-munten"],
    "Coins doubled": [
        "金币已翻倍", "सिक्के दोगुने", "Monedas duplicadas", "Pièces doublées",
        "Münzen verdoppelt", "Монеты удвоены", "Moedas dobradas", "Monete raddoppiate",
        "Monede dublate", "Munten verdubbeld"],
    "Double to": ["翻倍至", "दोगुना करके", "Duplicar a", "Doubler à", "Verdoppeln auf",
                  "Удвоить до", "Dobrar para", "Raddoppia a", "Dublează la", "Verdubbelen naar"],
    "Playing…": ["播放中…", "चल रहा है…", "Reproduciendo…", "Lecture…", "Wird abgespielt…",
                 "Воспроизведение…", "Reproduzindo…", "In riproduzione…", "Se redă…", "Speelt af…"],

    # ---- Route selection + history --------------------------------------
    "Chart your course": [
        "规划你的航线", "अपना मार्ग तय करें", "Traza tu rumbo", "Tracez votre route",
        "Plane deine Route", "Проложите курс", "Trace sua rota",
        "Traccia la tua rotta", "Trasează-ți traseul", "Zet je koers uit"],
    "No destinations in this range": [
        "该范围内没有目的地", "इस रेंज में कोई गंतव्य नहीं", "No hay destinos en este rango",
        "Aucune destination dans cette plage", "Keine Ziele in diesem Bereich",
        "Нет пунктов назначения в этом диапазоне", "Nenhum destino nesta faixa",
        "Nessuna destinazione in questo intervallo", "Nicio destinație în acest interval",
        "Geen bestemmingen in dit bereik"],
    "Try another category — nearby places appear under Short.": [
        "试试其他类别 — 附近地点在“短途”中。",
        "दूसरी श्रेणी आज़माएँ — पास की जगहें “छोटी” में दिखती हैं।",
        "Prueba otra categoría: los lugares cercanos aparecen en Corto.",
        "Essayez une autre catégorie — les lieux proches sont dans Court.",
        "Probier eine andere Kategorie – Orte in der Nähe stehen unter Kurz.",
        "Попробуйте другую категорию — близкие места находятся в «Короткие».",
        "Tente outra categoria — lugares próximos aparecem em Curto.",
        "Prova un’altra categoria: i luoghi vicini sono sotto Breve.",
        "Încearcă altă categorie — locurile apropiate apar la Scurt.",
        "Probeer een andere categorie — plekken dichtbij staan onder Kort."],
    "Expeditions are being charted for your region": [
        "正在为你所在区域规划远征", "आपके क्षेत्र के लिए अभियान तैयार किए जा रहे हैं",
        "Se están trazando expediciones para tu región",
        "Des expéditions sont en préparation pour votre région",
        "Expeditionen für deine Region werden geplant",
        "Экспедиции для вашего региона прокладываются",
        "Expedições estão sendo traçadas para sua região",
        "Stiamo tracciando spedizioni per la tua regione",
        "Se trasează expediții pentru regiunea ta",
        "Er worden expedities uitgezet voor jouw regio"],
    "Choose a starting city to begin exploring.": [
        "选择一个出发城市开始探索。", "खोज शुरू करने के लिए एक प्रारंभिक शहर चुनें।",
        "Elige una ciudad de partida para empezar a explorar.",
        "Choisissez une ville de départ pour commencer à explorer.",
        "Wähle eine Startstadt, um loszuerkunden.",
        "Выберите город отправления, чтобы начать исследовать.",
        "Escolha uma cidade de partida para começar a explorar.",
        "Scegli una città di partenza per iniziare a esplorare.",
        "Alege un oraș de plecare ca să începi explorarea.",
        "Kies een startstad om te beginnen met verkennen."],
    "Choose starting city": [
        "选择出发城市", "प्रारंभिक शहर चुनें", "Elegir ciudad de partida",
        "Choisir la ville de départ", "Startstadt wählen", "Выбрать город отправления",
        "Escolher cidade de partida", "Scegli città di partenza",
        "Alege orașul de plecare", "Startstad kiezen"],
    "Every expedition you've taken": [
        "你完成过的每一次远征", "आपके द्वारा की गई हर यात्रा",
        "Todas las expediciones que has hecho", "Toutes vos expéditions",
        "Jede Expedition, die du unternommen hast", "Все ваши экспедиции",
        "Todas as expedições que você fez", "Tutte le spedizioni che hai fatto",
        "Toate expedițiile pe care le-ai făcut", "Elke expeditie die je hebt gemaakt"],
    "No expeditions yet": [
        "还没有远征", "अभी कोई यात्रा नहीं", "Aún no hay expediciones",
        "Aucune expédition pour l’instant", "Noch keine Expeditionen",
        "Пока нет экспедиций", "Ainda não há expedições",
        "Nessuna spedizione ancora", "Încă nicio expediție", "Nog geen expedities"],
    "Complete your first expedition and it will appear here.": [
        "完成第一次远征后会显示在这里。", "अपनी पहली यात्रा पूरी करें, वह यहाँ दिखेगी।",
        "Completa tu primera expedición y aparecerá aquí.",
        "Terminez votre première expédition et elle apparaîtra ici.",
        "Schließe deine erste Expedition ab, dann erscheint sie hier.",
        "Завершите первую экспедицию — она появится здесь.",
        "Conclua sua primeira expedição e ela aparecerá aqui.",
        "Completa la tua prima spedizione e comparirà qui.",
        "Finalizează prima expediție și va apărea aici.",
        "Voltooi je eerste expeditie en hij verschijnt hier."],
}
