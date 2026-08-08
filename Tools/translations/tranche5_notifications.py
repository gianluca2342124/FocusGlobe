"""Tranche 5c — scheduled notifications (app catalog).

WHY THESE ARE NOT ORDINARY STRINGS

    A notification's title and body are plain `String`s composed when it is
    SCHEDULED — up to fourteen days before it is shown. Nothing in the SwiftUI
    environment reaches them, and `Locale.current` is the DEVICE's language, so
    a pilot running FocusGlobe in French on an English phone used to get English
    reminders. `NotificationService` now resolves every one through
    `FocusLocalization`, against the language the pilot chose IN FocusGlobe.

TONE
    Warm, concise, personal. No guilt, no "you failed", no fake urgency — and
    the English never scolds, so neither may any translation. Several of these
    languages default to a sterner imperative; each line was chosen to stay
    encouraging.

PRIVACY
    No city, coordinate, route or other location detail appears in any of this
    copy. The one exception is `Continue your expedition from %@ to %@.`, whose
    two arguments are the pilot's OWN route as they already saw it in the app;
    both stay arguments and are never translated.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Today: unfinished journey ---------------------------------------
    "Your balloon is still waiting": [
        "你的热气球还在等你", "आपका ग़ुब्बारा अब भी इंतज़ार कर रहा है",
        "Tu globo sigue esperando", "Votre montgolfière vous attend toujours",
        "Dein Ballon wartet noch", "Ваш шар всё ещё ждёт",
        "Seu balão ainda está esperando", "La tua mongolfiera ti aspetta ancora",
        "Balonul tău încă te așteaptă", "Je ballon wacht nog steeds",
    ],
    "Continue your expedition from %@ to %@.": [
        "继续你从 %@ 到 %@ 的远征。",
        "%@ से %@ तक की अपनी यात्रा जारी रखें।",
        "Continúa tu expedición de %@ a %@.",
        "Poursuivez votre expédition de %@ à %@.",
        "Setze deine Expedition von %@ nach %@ fort.",
        "Продолжите маршрут %@ — %@.",
        "Continue sua expedição de %@ para %@.",
        "Continua la tua spedizione da %@ a %@.",
        "Continuă-ți expediția de la %@ la %@.",
        "Zet je expeditie van %@ naar %@ voort.",
    ],
    "Pick up the route you started whenever you're ready.": [
        "准备好了就接着走你开始的航线。",
        "जब तैयार हों, शुरू किया हुआ रास्ता फिर से पकड़ें।",
        "Retoma la ruta que empezaste cuando quieras.",
        "Reprenez l’itinéraire commencé quand vous voulez.",
        "Nimm die begonnene Route auf, wann immer du bereit bist.",
        "Вернитесь к начатому маршруту, когда будете готовы.",
        "Retome a rota que começou quando quiser.",
        "Riprendi la rotta che hai iniziato quando vuoi.",
        "Reia ruta începută când ești gata.",
        "Pak de route die je begon weer op wanneer je wilt.",
    ],

    # ---- Today: daily gift ------------------------------------------------
    "A gift is waiting in FocusGlobe": [
        "FocusGlobe 里有一份礼物", "FocusGlobe में एक तोहफ़ा इंतज़ार कर रहा है",
        "Te espera un regalo en FocusGlobe", "Un cadeau vous attend dans FocusGlobe",
        "In FocusGlobe wartet ein Geschenk", "В FocusGlobe вас ждёт подарок",
        "Um presente espera por você no FocusGlobe",
        "Un regalo ti aspetta in FocusGlobe",
        "Un cadou te așteaptă în FocusGlobe",
        "Er wacht een cadeau in FocusGlobe",
    ],
    "Open your daily gift before it flies away.": [
        "在每日礼物飞走前打开它。", "रोज़ का तोहफ़ा उड़ जाने से पहले खोलें।",
        "Abre tu regalo diario antes de que salga volando.",
        "Ouvrez votre cadeau du jour avant qu’il ne s’envole.",
        "Öffne dein Tagesgeschenk, bevor es davonfliegt.",
        "Откройте ежедневный подарок, пока он не улетел.",
        "Abra seu presente diário antes que ele voe.",
        "Apri il regalo del giorno prima che voli via.",
        "Deschide-ți cadoul zilnic înainte să zboare.",
        "Open je dagelijkse cadeau voor het wegvliegt.",
    ],

    # ---- Today: goal still open ------------------------------------------
    "One calm flight can finish today": [
        "一次平静的飞行就能完成今天",
        "एक शांत फ़्लाइट आज पूरा कर सकती है",
        "Un vuelo tranquilo puede cerrar el día",
        "Un vol paisible peut boucler la journée",
        "Ein ruhiger Flug kann den Tag abschließen",
        "Один спокойный полёт завершит день",
        "Um voo tranquilo pode fechar o dia",
        "Un volo tranquillo può chiudere la giornata",
        "Un zbor liniștit poate încheia ziua",
        "Eén rustige vlucht maakt vandaag af",
    ],

    # ---- Reactivation titles ---------------------------------------------
    "The sky is still here": [
        "天空一直都在", "आकाश अब भी यहीं है", "El cielo sigue aquí",
        "Le ciel est toujours là", "Der Himmel ist noch da", "Небо всё ещё здесь",
        "O céu continua aqui", "Il cielo è ancora qui", "Cerul e tot aici",
        "De lucht is er nog steeds",
    ],
    "Ready for another quiet flight?": [
        "准备好再来一次宁静飞行了吗？", "एक और शांत फ़्लाइट के लिए तैयार?",
        "¿Te apetece otro vuelo tranquilo?", "Envie d’un autre vol paisible ?",
        "Bereit für einen weiteren ruhigen Flug?",
        "Готовы к ещё одному тихому полёту?",
        "Que tal outro voo tranquilo?",
        "Ti va un altro volo tranquillo?",
        "Gata pentru încă un zbor liniștit?",
        "Klaar voor nog een rustige vlucht?",
    ],
    "A new expedition is waiting": [
        "一场新的远征在等你", "एक नई यात्रा इंतज़ार कर रही है",
        "Te espera una nueva expedición", "Une nouvelle expédition vous attend",
        "Eine neue Expedition wartet", "Вас ждёт новая экспедиция",
        "Uma nova expedição espera por você", "Ti aspetta una nuova spedizione",
        "Te așteaptă o nouă expediție", "Er wacht een nieuwe expeditie",
    ],

    # ---- Daily titles -----------------------------------------------------
    "Ready for one focused expedition?": [
        "准备好一次专注的远征了吗？", "एक फ़ोकस वाली यात्रा के लिए तैयार?",
        "¿Una expedición para concentrarte?",
        "Une expédition pour vous concentrer ?",
        "Bereit für eine fokussierte Expedition?",
        "Готовы к одной сосредоточенной экспедиции?",
        "Uma expedição para focar?",
        "Una spedizione per concentrarti?",
        "Gata pentru o expediție concentrată?",
        "Klaar voor één gefocuste expeditie?",
    ],
    "One focused drift before the day ends?": [
        "在今天结束前，来一次专注的飞行？",
        "दिन ख़त्म होने से पहले एक फ़ोकस वाली उड़ान?",
        "¿Un vuelo concentrado antes de que acabe el día?",
        "Un vol concentré avant la fin de la journée ?",
        "Ein fokussierter Flug, bevor der Tag endet?",
        "Один сосредоточенный полёт до конца дня?",
        "Um voo focado antes de o dia acabar?",
        "Un volo concentrato prima che finisca la giornata?",
        "Un zbor concentrat înainte să se termine ziua?",
        "Nog één gefocuste zweefvlucht voor de dag om is?",
    ],
    "Your next deep-work block awaits": [
        "下一段深度工作在等你", "आपका अगला डीप-वर्क ब्लॉक तैयार है",
        "Tu próximo bloque de trabajo profundo te espera",
        "Votre prochaine session de travail profond vous attend",
        "Dein nächster Deep-Work-Block wartet",
        "Вас ждёт следующий блок глубокой работы",
        "Seu próximo bloco de trabalho profundo te espera",
        "Ti aspetta il prossimo blocco di lavoro profondo",
        "Te așteaptă următorul bloc de muncă profundă",
        "Je volgende deep-workblok wacht",
    ],

    # ---- Streak bodies ----------------------------------------------------
    "One short expedition keeps your focus streak alive.": [
        "一次短途远征就能延续你的专注连续天数。",
        "एक छोटी यात्रा आपकी फ़ोकस स्ट्रीक बनाए रखेगी।",
        "Una expedición corta mantiene viva tu racha de concentración.",
        "Une courte expédition fait vivre votre série de concentration.",
        "Eine kurze Expedition hält deine Fokus-Serie am Leben.",
        "Одна короткая экспедиция сохранит серию фокуса.",
        "Uma expedição curta mantém sua sequência de foco viva.",
        "Una breve spedizione tiene viva la tua serie di concentrazione.",
        "O expediție scurtă îți ține vie seria de concentrare.",
        "Eén korte expeditie houdt je focusreeks in leven.",
    ],
    "Your streak is too good to lose now.": [
        "你的连续天数太可惜了，别断在这里。",
        "आपकी स्ट्रीक अभी खोने के लिए बहुत अच्छी है।",
        "Tu racha es demasiado buena para perderla ahora.",
        "Votre série est trop belle pour la perdre maintenant.",
        "Deine Serie ist zu gut, um sie jetzt zu verlieren.",
        "Ваша серия слишком хороша, чтобы прерваться сейчас.",
        "Sua sequência está boa demais para perder agora.",
        "La tua serie è troppo bella per perderla ora.",
        "Seria ta e prea bună ca s-o pierzi acum.",
        "Je reeks is te mooi om nu te verliezen.",
    ],
    "A 20-minute expedition is enough to protect your streak.": [
        "20 分钟的远征就足以守住你的连续天数。",
        "20 मिनट की यात्रा आपकी स्ट्रीक बचाने के लिए काफ़ी है।",
        "Una expedición de 20 minutos basta para proteger tu racha.",
        "Une expédition de 20 minutes suffit à protéger votre série.",
        "Eine 20-minütige Expedition reicht, um deine Serie zu schützen.",
        "Экспедиции на 20 минут хватит, чтобы сохранить серию.",
        "Uma expedição de 20 minutos basta para proteger sua sequência.",
        "Una spedizione di 20 minuti basta a proteggere la tua serie.",
        "O expediție de 20 de minute e destul ca să-ți aperi seria.",
        "Een expeditie van 20 minuten is genoeg om je reeks te beschermen.",
    ],
    "Set off on one short session and keep your streak alive.": [
        "来一段短暂的专注，延续你的连续天数。",
        "एक छोटा सेशन शुरू करें और अपनी स्ट्रीक बनाए रखें।",
        "Haz una sesión corta y mantén viva tu racha.",
        "Partez pour une courte session et faites vivre votre série.",
        "Starte eine kurze Sitzung und halte deine Serie am Leben.",
        "Отправьтесь в короткую сессию и сохраните серию.",
        "Faça uma sessão curta e mantenha sua sequência viva.",
        "Parti per una sessione breve e tieni viva la tua serie.",
        "Pornește într-o sesiune scurtă și ține-ți seria vie.",
        "Vertrek voor een korte sessie en houd je reeks in leven.",
    ],

    # ---- Focus bodies -----------------------------------------------------
    "Pick a destination and give yourself 25 minutes.": [
        "选一个目的地，给自己 25 分钟。",
        "एक मंज़िल चुनें और ख़ुद को 25 मिनट दें।",
        "Elige un destino y date 25 minutos.",
        "Choisissez une destination et offrez-vous 25 minutes.",
        "Wähl ein Ziel und schenk dir 25 Minuten.",
        "Выберите пункт назначения и дайте себе 25 минут.",
        "Escolha um destino e se dê 25 minutos.",
        "Scegli una destinazione e concediti 25 minuti.",
        "Alege o destinație și acordă-ți 25 de minute.",
        "Kies een bestemming en gun jezelf 25 minuten.",
    ],
    "Your balloon hasn't taken off yet today.": [
        "你的热气球今天还没起飞。",
        "आपका ग़ुब्बारा आज अब तक उड़ा नहीं है।",
        "Tu globo aún no ha despegado hoy.",
        "Votre montgolfière n’a pas encore décollé aujourd’hui.",
        "Dein Ballon ist heute noch nicht gestartet.",
        "Ваш шар сегодня ещё не взлетал.",
        "Seu balão ainda não decolou hoje.",
        "La tua mongolfiera oggi non è ancora decollata.",
        "Balonul tău încă n-a decolat azi.",
        "Je ballon is vandaag nog niet opgestegen.",
    ],
    "Complete one expedition today and keep your momentum.": [
        "今天完成一次远征，保持你的势头。",
        "आज एक यात्रा पूरी करें और रफ़्तार बनाए रखें।",
        "Completa una expedición hoy y mantén tu impulso.",
        "Terminez une expédition aujourd’hui et gardez votre élan.",
        "Schließ heute eine Expedition ab und halte deinen Schwung.",
        "Завершите одну экспедицию сегодня и сохраните набранный темп.",
        "Conclua uma expedição hoje e mantenha seu impulso.",
        "Completa una spedizione oggi e mantieni il tuo slancio.",
        "Încheie o expediție azi și păstrează-ți avântul.",
        "Voltooi vandaag één expeditie en houd je vaart.",
    ],
    "Your journal is missing today's stamp.": [
        "你的日志还缺今天的印章。",
        "आपकी डायरी में आज की मुहर नहीं लगी है।",
        "A tu diario le falta el sello de hoy.",
        "Il manque le tampon du jour à votre carnet.",
        "In deinem Journal fehlt der heutige Stempel.",
        "В вашем журнале не хватает сегодняшнего штампа.",
        "Falta o carimbo de hoje no seu diário.",
        "Al tuo diario manca il timbro di oggi.",
        "Jurnalului tău îi lipsește ștampila de azi.",
        "In je logboek ontbreekt de stempel van vandaag.",
    ],

    # ---- Study bodies -----------------------------------------------------
    "Need to study? Start with one calm expedition.": [
        "需要学习？先来一次平静的远征。",
        "पढ़ाई करनी है? एक शांत यात्रा से शुरू करें।",
        "¿Necesitas estudiar? Empieza con una expedición tranquila.",
        "Besoin de réviser ? Commencez par une expédition paisible.",
        "Lernen? Fang mit einer ruhigen Expedition an.",
        "Нужно позаниматься? Начните со спокойной экспедиции.",
        "Precisa estudar? Comece com uma expedição tranquila.",
        "Devi studiare? Comincia con una spedizione tranquilla.",
        "Trebuie să înveți? Începe cu o expediție liniștită.",
        "Moet je studeren? Begin met één rustige expeditie.",
    ],
    "One focused session before distractions win.": [
        "在分心占上风前，来一段专注时间。",
        "ध्यान भटकने से पहले एक फ़ोकस सेशन।",
        "Una sesión concentrada antes de que ganen las distracciones.",
        "Une session concentrée avant que les distractions ne gagnent.",
        "Eine fokussierte Sitzung, bevor die Ablenkungen gewinnen.",
        "Одна сосредоточенная сессия, пока отвлечения не победили.",
        "Uma sessão focada antes que as distrações vençam.",
        "Una sessione concentrata prima che vincano le distrazioni.",
        "O sesiune concentrată înainte să câștige distragerile.",
        "Eén gefocuste sessie voor de afleiding wint.",
    ],
    "Turn your next destination into a deep-work block.": [
        "把下一个目的地变成一段深度工作。",
        "अपनी अगली मंज़िल को डीप-वर्क ब्लॉक बनाएँ।",
        "Convierte tu próximo destino en un bloque de trabajo profundo.",
        "Faites de votre prochaine destination une session de travail profond.",
        "Mach dein nächstes Ziel zu einem Deep-Work-Block.",
        "Превратите следующий пункт назначения в блок глубокой работы.",
        "Transforme seu próximo destino num bloco de trabalho profundo.",
        "Trasforma la prossima destinazione in un blocco di lavoro profondo.",
        "Transformă următoarea destinație într-un bloc de muncă profundă.",
        "Maak van je volgende bestemming een deep-workblok.",
    ],

    # ---- Comeback bodies --------------------------------------------------
    "The globe is ready when you are.": [
        "你准备好，地球就准备好了。",
        "जब आप तैयार हों, दुनिया तैयार है।",
        "El globo está listo cuando tú lo estés.",
        "Le globe est prêt quand vous l’êtes.",
        "Der Globus ist bereit, sobald du es bist.",
        "Глобус готов, когда готовы вы.",
        "O globo está pronto quando você estiver.",
        "Il globo è pronto quando lo sei tu.",
        "Globul e gata când ești și tu.",
        "De wereldbol is klaar wanneer jij dat bent.",
    ],
    "Your balloon is ready whenever you are.": [
        "你的热气球随时等你。",
        "आपका ग़ुब्बारा जब चाहें तैयार है।",
        "Tu globo está listo cuando tú quieras.",
        "Votre montgolfière est prête quand vous voulez.",
        "Dein Ballon ist bereit, wann immer du willst.",
        "Ваш шар готов в любой момент.",
        "Seu balão está pronto quando você quiser.",
        "La tua mongolfiera è pronta quando vuoi.",
        "Balonul tău e gata oricând vrei.",
        "Je ballon staat klaar wanneer jij wilt.",
    ],
    "Come back for one calm focus trip.": [
        "回来做一次平静的专注旅程。",
        "एक शांत फ़ोकस यात्रा के लिए लौट आइए।",
        "Vuelve para un viaje de concentración tranquilo.",
        "Revenez pour un voyage de concentration paisible.",
        "Komm zurück für eine ruhige Fokus-Reise.",
        "Возвращайтесь за спокойным полётом.",
        "Volte para uma viagem de foco tranquila.",
        "Torna per un viaggio di concentrazione tranquillo.",
        "Întoarce-te pentru o călătorie de concentrare liniștită.",
        "Kom terug voor één rustige focusreis.",
    ],
    "A new expedition is waiting when you are.": [
        "你准备好时，新的远征就在那里。",
        "जब आप तैयार हों, एक नई यात्रा इंतज़ार में है।",
        "Una nueva expedición te espera cuando quieras.",
        "Une nouvelle expédition vous attend quand vous voulez.",
        "Eine neue Expedition wartet, sobald du bereit bist.",
        "Новая экспедиция ждёт, когда вы будете готовы.",
        "Uma nova expedição espera quando você quiser.",
        "Una nuova spedizione ti aspetta quando vuoi.",
        "O nouă expediție așteaptă când ești gata.",
        "Een nieuwe expeditie wacht wanneer jij zover bent.",
    ],
}


# The streak-at-risk title. The number is the pilot's real streak, so the word
# around it has to agree with it in every language that inflects.
#
# key -> locale -> CLDR plural category -> value
PLURALS: dict[str, dict[str, dict[str, str]]] = {
    "Your %lld-day streak is waiting 🔥": {
        "en": {"one": "Your %lld-day streak is waiting 🔥",
               "other": "Your %lld-day streak is waiting 🔥"},
        "zh-Hans": {"other": "你连续 %lld 天的记录在等你 🔥"},
        "hi": {"one": "आपकी %lld दिन की स्ट्रीक इंतज़ार में है 🔥",
               "other": "आपकी %lld दिन की स्ट्रीक इंतज़ार में है 🔥"},
        "es": {"one": "Tu racha de %lld día te espera 🔥",
               "other": "Tu racha de %lld días te espera 🔥"},
        "fr": {"one": "Votre série de %lld jour vous attend 🔥",
               "other": "Votre série de %lld jours vous attend 🔥"},
        "de": {"one": "Deine %lld-Tag-Serie wartet 🔥",
               "other": "Deine %lld-Tage-Serie wartet 🔥"},
        "ru": {"one": "Ваша серия из %lld дня ждёт 🔥",
               "few": "Ваша серия из %lld дней ждёт 🔥",
               "many": "Ваша серия из %lld дней ждёт 🔥",
               "other": "Ваша серия из %lld дня ждёт 🔥"},
        "pt-BR": {"one": "Sua sequência de %lld dia está esperando 🔥",
                  "other": "Sua sequência de %lld dias está esperando 🔥"},
        "it": {"one": "La tua serie di %lld giorno ti aspetta 🔥",
               "other": "La tua serie di %lld giorni ti aspetta 🔥"},
        "ro": {"one": "Seria ta de %lld zi te așteaptă 🔥",
               "few": "Seria ta de %lld zile te așteaptă 🔥",
               "other": "Seria ta de %lld de zile te așteaptă 🔥"},
        "nl": {"one": "Je reeks van %lld dag wacht 🔥",
               "other": "Je reeks van %lld dagen wacht 🔥"},
    },
}
