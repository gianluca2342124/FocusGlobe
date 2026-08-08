"""Tranche 7 — the keys Xcode's own extraction found that the regex sweep missed.

WHY THESE WERE INVISIBLE

    `Tools/localization_audit.py` reads literals out of the source with a
    regex. That finds `Text("Landed")` and misses three whole shapes:

      * interpolated literals — `Text("\\(count) focusing now")`, whose key is
        `%lld focusing now` and appears nowhere in the source as that string;
      * `Button("Applaud") { … }`, `Label("Share", …)` and friends, where the
        copy is the first positional argument of an initialiser the regex did
        not enumerate;
      * `.accessibilityLabel("Boarding pass. Focus flight to \\(a), \\(b). \\(c)")`
        and other modifiers taking a LocalizedStringKey.

    The compiler has no such blind spot. These 87 translatable keys came from a
    real build, and the audit has since been taught the same patterns.

CAPITALIZATION

    English UI title-cases; most of these languages do not. `Focus Coins` is
    "monedas de concentración" in Spanish, not "Monedas De Concentración".
    Only German capitalises nouns, and Chinese, Hindi and Russian follow their
    own conventions. That is applied here and re-applied in tranche 8.
"""

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Small status labels, chips, badges -------------------------------
    "Live": [
        "直播中", "लाइव", "En directo", "En direct", "Live", "В эфире",
        "Ao vivo", "In diretta", "În direct", "Live",
    ],
    "Flying": [
        "飞行中", "उड़ान में", "En vuelo", "En vol", "Unterwegs", "В полёте",
        "Em voo", "In volo", "În zbor", "Onderweg",
    ],
    "Landed": [
        "已降落", "लैंड हो गया", "Aterrizado", "Atterri", "Gelandet",
        "Приземлился", "Pousou", "Atterrato", "Aterizat", "Geland",
    ],
    "Ready": [
        "已就绪", "तैयार", "Listo", "Prêt", "Bereit", "Готов",
        "Pronto", "Pronto", "Gata", "Klaar",
    ],
    "READY": [
        "已就绪", "तैयार", "LISTO", "PRÊT", "BEREIT", "ГОТОВ",
        "PRONTO", "PRONTO", "GATA", "KLAAR",
    ],
    "Cancelled": [
        "已取消", "रद्द", "Cancelado", "Annulé", "Abgebrochen", "Отменён",
        "Cancelado", "Annullato", "Anulat", "Geannuleerd",
    ],
    "Current": [
        "当前", "मौजूदा", "Actual", "Actuelle", "Aktuell", "Текущая",
        "Atual", "Attuale", "Curentă", "Huidig",
    ],
    "Locked": [
        "已锁定", "लॉक", "Bloqueado", "Verrouillé", "Gesperrt", "Заблокировано",
        "Bloqueado", "Bloccato", "Blocat", "Vergrendeld",
    ],
    "Owned": [
        "已拥有", "आपके पास", "En tu colección", "Dans ta collection",
        "Im Besitz", "В коллекции", "Na sua coleção", "Nella collezione",
        "În colecție", "In bezit",
    ],
    "Occupied": [
        "已占用", "जगह भरी है", "Ocupado", "Occupé", "Belegt", "Занято",
        "Ocupado", "Occupato", "Ocupat", "Bezet",
    ],
    "Occupied by another item": [
        "已被其他物品占用", "यहाँ पहले से कोई सामान है",
        "Ocupado por otro objeto", "Occupé par un autre objet",
        "Von einem anderen Objekt belegt", "Занято другим предметом",
        "Ocupado por outro item", "Occupato da un altro oggetto",
        "Ocupat de alt obiect", "Bezet door een ander item",
    ],
    "Previewing": [
        "预览中", "प्रीव्यू चल रहा है", "Vista previa", "Aperçu en cours",
        "Vorschau läuft", "Предпросмотр", "Pré-visualizando",
        "Anteprima in corso", "Previzualizare", "Voorbeeld",
    ],
    "Earned": [
        "已获得", "अर्जित", "Ganado", "Gagné", "Verdient", "Заработано",
        "Ganho", "Guadagnato", "Câștigat", "Verdiend",
    ],
    "Deleting…": [
        "正在删除…", "हटाया जा रहा है…", "Eliminando…", "Suppression…",
        "Wird gelöscht…", "Удаление…", "Excluindo…", "Eliminazione…",
        "Se șterge…", "Verwijderen…",
    ],
    "NEW": [
        "新", "नया", "NUEVO", "NOUVEAU", "NEU", "НОВОЕ",
        "NOVO", "NUOVO", "NOU", "NIEUW",
    ],
    "AD": [
        "广告", "विज्ञापन", "ANUNCIO", "PUB", "WERBUNG", "РЕКЛАМА",
        "ANÚNCIO", "PUBBLICITÀ", "RECLAMĂ", "ADVERTENTIE",
    ],
    "PLAYING": [
        "播放中", "चल रहा है", "SONANDO", "EN LECTURE", "LÄUFT",
        "ИГРАЕТ", "TOCANDO", "IN RIPRODUZIONE", "SE AUDE", "SPEELT",
    ],
    "YOU": [
        "你", "आप", "TÚ", "VOUS", "DU", "ВЫ", "VOCÊ", "TU", "TU", "JIJ",
    ],
    "or": [
        "或", "या", "o", "ou", "oder", "или", "ou", "oppure", "sau", "of",
    ],
    "Infinity": [
        "无限", "अनंत", "Infinito", "Infini", "Unendlich", "Бесконечно",
        "Infinito", "Infinito", "Infinit", "Oneindig",
    ],
    "Globe": [
        "地球", "ग्लोब", "Globo terráqueo", "Globe", "Globus", "Глобус",
        "Globo", "Globo", "Glob", "Wereldbol",
    ],

    # ---- Boarding-pass / expedition stamps (uppercase by design) ----------
    "EXPEDITION": [
        "远征", "यात्रा", "EXPEDICIÓN", "EXPÉDITION", "EXPEDITION",
        "ЭКСПЕДИЦИЯ", "EXPEDIÇÃO", "SPEDIZIONE", "EXPEDIȚIE", "EXPEDITIE",
    ],
    "EARNINGS": [
        "收益", "कमाई", "GANANCIAS", "GAINS", "ERTRAG", "ЗАРАБОТОК",
        "GANHOS", "GUADAGNI", "CÂȘTIGURI", "OPBRENGST",
    ],
    "PASSPORT": [
        "护照", "पासपोर्ट", "PASAPORTE", "PASSEPORT", "REISEPASS", "ПАСПОРТ",
        "PASSAPORTE", "PASSAPORTO", "PAȘAPORT", "PASPOORT",
    ],
    "SOUNDSCAPE": [
        "音景", "साउंडस्केप", "AMBIENTE SONORO", "AMBIANCE SONORE",
        "KLANGKULISSE", "ЗВУКОВОЙ ФОН", "AMBIENTE SONORO", "PAESAGGIO SONORO",
        "PEISAJ SONOR", "GELUIDSSFEER",
    ],
    "RETURN": [
        "返回", "वापसी", "VUELTA", "RETOUR", "RÜCKFLUG", "ОБРАТНО",
        "VOLTA", "RITORNO", "RETUR", "TERUG",
    ],

    # ---- Actions ----------------------------------------------------------
    "Applaud": [
        "鼓掌", "सराहें", "Aplaudir", "Applaudir", "Applaudieren",
        "Поаплодировать", "Aplaudir", "Applaudi", "Aplaudă", "Applaudisseer",
    ],
    "Applauded": [
        "已鼓掌", "सराहा गया", "Aplaudido", "Applaudi", "Applaudiert",
        "Вы поаплодировали", "Aplaudido", "Applaudito", "Aplaudat",
        "Geapplaudisseerd",
    ],
    "Block": [
        "屏蔽", "ब्लॉक करें", "Bloquear", "Bloquer", "Blockieren",
        "Заблокировать", "Bloquear", "Blocca", "Blochează", "Blokkeren",
    ],
    "Report": [
        "举报", "रिपोर्ट करें", "Denunciar", "Signaler", "Melden",
        "Пожаловаться", "Denunciar", "Segnala", "Raportează", "Rapporteren",
    ],
    "Remove": [
        "移除", "हटाएँ", "Eliminar", "Retirer", "Entfernen", "Удалить",
        "Remover", "Rimuovi", "Elimină", "Verwijderen",
    ],
    "Share": [
        "分享", "शेयर करें", "Compartir", "Partager", "Teilen", "Поделиться",
        "Compartilhar", "Condividi", "Distribuie", "Delen",
    ],
    "Invite": [
        "邀请", "बुलाएँ", "Invitar", "Inviter", "Einladen", "Пригласить",
        "Convidar", "Invita", "Invită", "Uitnodigen",
    ],
    "Edit": [
        "编辑", "बदलें", "Editar", "Modifier", "Bearbeiten", "Изменить",
        "Editar", "Modifica", "Editează", "Bewerken",
    ],
    "Open": [
        "打开", "खोलें", "Abrir", "Ouvrir", "Öffnen", "Открыть",
        "Abrir", "Apri", "Deschide", "Openen",
    ],
    "Preview": [
        "预览", "प्रीव्यू", "Vista previa", "Aperçu", "Vorschau",
        "Предпросмотр", "Pré-visualizar", "Anteprima", "Previzualizare",
        "Voorbeeld",
    ],
    "Unequip": [
        "取消装备", "हटाएँ", "Quitar", "Retirer", "Ablegen", "Снять",
        "Tirar", "Rimuovi", "Scoate", "Afleggen",
    ],
    "View on the map": [
        "在地图上查看", "मानचित्र पर देखें", "Ver en el mapa",
        "Voir sur la carte", "Auf der Karte ansehen", "Показать на карте",
        "Ver no mapa", "Vedi sulla mappa", "Vezi pe hartă", "Bekijk op de kaart",
    ],

    # ---- Nouns and headers ------------------------------------------------
    "Coins": [
        "金币", "सिक्के", "Monedas", "Pièces", "Münzen", "Монеты",
        "Moedas", "Monete", "Monede", "Munten",
    ],
    "Destination": [
        "目的地", "मंज़िल", "Destino", "Destination", "Ziel", "Пункт назначения",
        "Destino", "Destinazione", "Destinație", "Bestemming",
    ],
    "Store": [
        "商店", "स्टोर", "Tienda", "Boutique", "Store", "Магазин",
        "Loja", "Negozio", "Magazin", "Winkel",
    ],

    # ---- Sentences and formats -------------------------------------------
    "A quiet flight is one tap away.": [
        "一次轻点，开启宁静飞行。", "एक टैप में शांत फ़्लाइट।",
        "Un vuelo tranquilo a un toque.", "Un vol paisible à un geste près.",
        "Ein ruhiger Flug ist einen Tipp entfernt.",
        "Тихий полёт — в одно касание.", "Um voo tranquilo a um toque.",
        "Un volo tranquillo a un tocco.", "Un zbor liniștit la o atingere.",
        "Een rustige vlucht is één tik weg.",
    ],
    "Your flight is ready to continue.": [
        "你的飞行可以继续了。", "आपकी फ़्लाइट जारी रखने के लिए तैयार है।",
        "Tu vuelo está listo para continuar.", "Votre vol est prêt à reprendre.",
        "Dein Flug kann fortgesetzt werden.", "Ваш полёт готов продолжиться.",
        "Seu voo está pronto para continuar.", "Il tuo volo è pronto a riprendere.",
        "Zborul tău e gata să continue.", "Je vlucht kan verder.",
    ],
    "%@ balloon preview": [
        "%@ 热气球预览", "%@ ग़ुब्बारे का प्रीव्यू", "Vista previa del globo %@",
        "Aperçu de la montgolfière %@", "Vorschau des Ballons %@",
        "Предпросмотр шара «%@»", "Pré-visualização do balão %@",
        "Anteprima della mongolfiera %@", "Previzualizarea balonului %@",
        "Voorbeeld van ballon %@",
    ],
    "%@ balloon skin. %@": [
        "%@ 热气球皮肤。%@", "%@ ग़ुब्बारा स्किन। %@",
        "Diseño de globo %@. %@", "Habillage de montgolfière %@. %@",
        "Ballon-Design %@. %@", "Оформление шара «%@». %@",
        "Skin de balão %@. %@", "Skin per mongolfiera %@. %@",
        "Skin de balon %@. %@", "Ballonskin %@. %@",
    ],
    "%@ collection": [
        "%@ 收藏", "%@ संग्रह", "Colección %@", "Collection %@",
        "Kollektion %@", "Коллекция «%@»", "Coleção %@", "Collezione %@",
        "Colecția %@", "Collectie %@",
    ],
    "%@ focused": [
        "已专注 %@", "%@ फ़ोकस", "%@ de concentración", "%@ de concentration",
        "%@ fokussiert", "%@ в фокусе", "%@ de foco", "%@ di concentrazione",
        "%@ de concentrare", "%@ gefocust",
    ],
    "%@ packed — taking off": [
        "%@ 已就绪 — 正在起飞", "%@ तैयार — उड़ान भर रहे हैं",
        "%@ listo: despegando", "%@ prêt — décollage",
        "%@ gepackt – Start", "%@ собрано — взлетаем",
        "%@ pronto — decolando", "%@ pronto: decollo",
        "%@ gata — decolăm", "%@ ingepakt — opstijgen",
    ],
    "Focus on %@": [
        "专注于%@", "%@ पर फ़ोकस", "Concéntrate en %@",
        "Concentre-toi sur %@", "Fokus auf %@", "Сосредоточьтесь на %@",
        "Foque em %@", "Concentrati su %@", "Concentrează-te pe %@",
        "Focus op %@",
    ],
    "Focusing now · %@": [
        "正在专注 · %@", "अभी फ़ोकस में · %@", "Concentrándose ahora · %@",
        "En concentration · %@", "Gerade im Fokus · %@", "Сейчас в фокусе · %@",
        "Focando agora · %@", "In concentrazione · %@",
        "Se concentrează acum · %@", "Nu aan het focussen · %@",
    ],
    "Estimated flight · %@": [
        "预计飞行 · %@", "अनुमानित फ़्लाइट · %@", "Vuelo estimado · %@",
        "Vol estimé · %@", "Voraussichtlicher Flug · %@",
        "Ожидаемый полёт · %@", "Voo estimado · %@", "Volo stimato · %@",
        "Zbor estimat · %@", "Geschatte vlucht · %@",
    ],
    "Gift expires in %@": [
        "礼物将在 %@ 后过期", "तोहफ़ा %@ में ख़त्म होगा",
        "El regalo caduca en %@", "Le cadeau expire dans %@",
        "Geschenk verfällt in %@", "Подарок истечёт через %@",
        "O presente expira em %@", "Il regalo scade tra %@",
        "Cadoul expiră în %@", "Cadeau verloopt over %@",
    ],
    "Try again in %@": [
        "%@ 后再试", "%@ में फिर कोशिश करें", "Inténtalo de nuevo en %@",
        "Réessayez dans %@", "In %@ erneut versuchen", "Повторите через %@",
        "Tente de novo em %@", "Riprova tra %@", "Încearcă din nou în %@",
        "Probeer het over %@ opnieuw",
    ],
    "Target %@": [
        "目标 %@", "लक्ष्य %@", "Objetivo: %@", "Objectif : %@",
        "Ziel: %@", "Цель: %@", "Meta: %@", "Obiettivo: %@",
        "Obiectiv: %@", "Doel: %@",
    ],
    "Edit %@": [
        "编辑%@", "%@ बदलें", "Editar %@", "Modifier %@", "%@ bearbeiten",
        "Изменить: %@", "Editar %@", "Modifica %@", "Editează %@",
        "%@ bewerken",
    ],
    "Preview %@": [
        "预览%@", "%@ का प्रीव्यू", "Vista previa de %@", "Aperçu de %@",
        "Vorschau von %@", "Предпросмотр: %@", "Pré-visualizar %@",
        "Anteprima di %@", "Previzualizează %@", "Voorbeeld van %@",
    ],
    "Version %@": [
        "版本 %@", "संस्करण %@", "Versión %@", "Version %@", "Version %@",
        "Версия %@", "Versão %@", "Versione %@", "Versiunea %@", "Versie %@",
    ],
    "from %@": [
        "来自%@", "%@ से", "desde %@", "depuis %@", "ab %@",
        "из %@", "de %@", "da %@", "din %@", "vanuit %@",
    ],
    "Join %@'s Flight": [
        "加入%@的飞行", "%@ की फ़्लाइट में शामिल हों",
        "Únete al vuelo de %@", "Rejoindre le vol de %@",
        "Dem Flug von %@ beitreten", "Присоединиться к полёту %@",
        "Entrar no voo de %@", "Unisciti al volo di %@",
        "Intră în zborul lui %@", "Doe mee met de vlucht van %@",
    ],
    "Buy %@ for %lld Focus Coins": [
        "用 %2$lld 枚专注金币购买%1$@",
        "%1$@ को %2$lld फ़ोकस सिक्कों में लें",
        "Compra %1$@ por %2$lld monedas de concentración",
        "Acheter %1$@ pour %2$lld pièces de concentration",
        "%1$@ für %2$lld Fokus-Münzen kaufen",
        "Купить «%1$@» за %2$lld монет фокуса",
        "Comprar %1$@ por %2$lld moedas de foco",
        "Acquista %1$@ per %2$lld monete di concentrazione",
        "Cumpără %1$@ cu %2$lld monede de concentrare",
        "Koop %1$@ voor %2$lld focusmunten",
    ],
    "Boarding pass. Focus flight to %@, %@. %@": [
        "登机牌。飞往%1$@的专注飞行，%2$@。%3$@",
        "बोर्डिंग पास। %1$@ के लिए फ़ोकस फ़्लाइट, %2$@। %3$@",
        "Tarjeta de embarque. Vuelo de concentración a %1$@, %2$@. %3$@",
        "Carte d’embarquement. Vol de concentration vers %1$@, %2$@. %3$@",
        "Bordkarte. Fokus-Flug nach %1$@, %2$@. %3$@",
        "Посадочный талон. Полёт фокуса в %1$@, %2$@. %3$@",
        "Cartão de embarque. Voo de foco para %1$@, %2$@. %3$@",
        "Carta d’imbarco. Volo di concentrazione per %1$@, %2$@. %3$@",
        "Card de îmbarcare. Zbor de concentrare spre %1$@, %2$@. %3$@",
        "Instapkaart. Focusvlucht naar %1$@, %2$@. %3$@",
    ],
    "Completed focus flights from now to %@": [
        "从现在到%@已完成的专注飞行",
        "अब से %@ तक पूरी हुई फ़ोकस फ़्लाइट",
        "Vuelos de concentración completados desde ahora hasta %@",
        "Vols de concentration terminés d’ici %@",
        "Abgeschlossene Fokus-Flüge von jetzt bis %@",
        "Завершённые полёты фокуса с настоящего момента до %@",
        "Voos de foco concluídos de agora até %@",
        "Voli di concentrazione completati da ora a %@",
        "Zboruri de concentrare încheiate de acum până la %@",
        "Voltooide focusvluchten van nu tot %@",
    ],
    "%lld Focus Coins. Opens the Store.": [
        "%lld 枚专注金币。打开商店。",
        "%lld फ़ोकस सिक्के। स्टोर खोलता है।",
        "%lld monedas de concentración. Abre la tienda.",
        "%lld pièces de concentration. Ouvre la boutique.",
        "%lld Fokus-Münzen. Öffnet den Store.",
        "%lld монет фокуса. Открывает магазин.",
        "%lld moedas de foco. Abre a loja.",
        "%lld monete di concentrazione. Apre il negozio.",
        "%lld monede de concentrare. Deschide magazinul.",
        "%lld focusmunten. Opent de winkel.",
    ],
    "Live. %lld focusing now": [
        "直播中。%lld 人正在专注",
        "लाइव। अभी %lld लोग फ़ोकस में",
        "En directo. %lld concentrándose ahora",
        "En direct. %lld personnes en concentration",
        "Live. %lld gerade im Fokus",
        "В эфире. Сейчас в фокусе: %lld",
        "Ao vivo. %lld focando agora",
        "In diretta. %lld in concentrazione ora",
        "În direct. %lld se concentrează acum",
        "Live. %lld nu aan het focussen",
    ],
    "No. %lld": [
        "第 %lld 号", "क्रमांक %lld", "N.º %lld", "N° %lld", "Nr. %lld",
        "№ %lld", "N.º %lld", "N. %lld", "Nr. %lld", "Nr. %lld",
    ],
    "Best %lld days": [
        "最佳 %lld 天", "सर्वश्रेष्ठ %lld दिन", "Récord: %lld días",
        "Record : %lld jours", "Rekord: %lld Tage", "Рекорд: %lld дн.",
        "Recorde: %lld dias", "Record: %lld giorni", "Record: %lld zile",
        "Record: %lld dagen",
    ],
    "View all %lld on the map": [
        "在地图上查看全部 %lld 个", "मानचित्र पर सभी %lld देखें",
        "Ver los %lld en el mapa", "Voir les %lld sur la carte",
        "Alle %lld auf der Karte ansehen", "Показать все %lld на карте",
        "Ver os %lld no mapa", "Vedi tutti e %lld sulla mappa",
        "Vezi toate cele %lld pe hartă", "Bekijk alle %lld op de kaart",
    ],
}


# Counts. Every one of these is a complete sentence per plural category, so no
# language has to fit a noun the English shape chose for it.
#
# key -> locale -> CLDR plural category -> value
PLURALS: dict[str, dict[str, dict[str, str]]] = {
    "%lld Focus Coins": {
        "en": {"one": "%lld Focus Coin", "other": "%lld Focus Coins"},
        "zh-Hans": {"other": "%lld 枚专注金币"},
        "hi": {"one": "%lld फ़ोकस सिक्का", "other": "%lld फ़ोकस सिक्के"},
        "es": {"one": "%lld moneda de concentración",
               "other": "%lld monedas de concentración"},
        "fr": {"one": "%lld pièce de concentration",
               "other": "%lld pièces de concentration"},
        "de": {"one": "%lld Fokus-Münze", "other": "%lld Fokus-Münzen"},
        "ru": {"one": "%lld монета фокуса", "few": "%lld монеты фокуса",
               "many": "%lld монет фокуса", "other": "%lld монеты фокуса"},
        "pt-BR": {"one": "%lld moeda de foco", "other": "%lld moedas de foco"},
        "it": {"one": "%lld moneta di concentrazione",
               "other": "%lld monete di concentrazione"},
        "ro": {"one": "%lld monedă de concentrare",
               "few": "%lld monede de concentrare",
               "other": "%lld de monede de concentrare"},
        "nl": {"one": "%lld focusmunt", "other": "%lld focusmunten"},
    },
    "%lld Coins": {
        "en": {"one": "%lld Coin", "other": "%lld Coins"},
        "zh-Hans": {"other": "%lld 枚金币"},
        "hi": {"one": "%lld सिक्का", "other": "%lld सिक्के"},
        "es": {"one": "%lld moneda", "other": "%lld monedas"},
        "fr": {"one": "%lld pièce", "other": "%lld pièces"},
        "de": {"one": "%lld Münze", "other": "%lld Münzen"},
        "ru": {"one": "%lld монета", "few": "%lld монеты",
               "many": "%lld монет", "other": "%lld монеты"},
        "pt-BR": {"one": "%lld moeda", "other": "%lld moedas"},
        "it": {"one": "%lld moneta", "other": "%lld monete"},
        "ro": {"one": "%lld monedă", "few": "%lld monede",
               "other": "%lld de monede"},
        "nl": {"one": "%lld munt", "other": "%lld munten"},
    },
    "+%lld Coins": {
        "en": {"one": "+%lld Coin", "other": "+%lld Coins"},
        "zh-Hans": {"other": "+%lld 枚金币"},
        "hi": {"one": "+%lld सिक्का", "other": "+%lld सिक्के"},
        "es": {"one": "+%lld moneda", "other": "+%lld monedas"},
        "fr": {"one": "+%lld pièce", "other": "+%lld pièces"},
        "de": {"one": "+%lld Münze", "other": "+%lld Münzen"},
        "ru": {"one": "+%lld монета", "few": "+%lld монеты",
               "many": "+%lld монет", "other": "+%lld монеты"},
        "pt-BR": {"one": "+%lld moeda", "other": "+%lld moedas"},
        "it": {"one": "+%lld moneta", "other": "+%lld monete"},
        "ro": {"one": "+%lld monedă", "few": "+%lld monede",
               "other": "+%lld de monede"},
        "nl": {"one": "+%lld munt", "other": "+%lld munten"},
    },
    "Claim +%lld Focus Coins": {
        "en": {"one": "Claim +%lld Focus Coin", "other": "Claim +%lld Focus Coins"},
        "zh-Hans": {"other": "领取 +%lld 枚专注金币"},
        "hi": {"one": "+%lld फ़ोकस सिक्का लें", "other": "+%lld फ़ोकस सिक्के लें"},
        "es": {"one": "Recoger +%lld moneda de concentración",
               "other": "Recoger +%lld monedas de concentración"},
        "fr": {"one": "Récupérer +%lld pièce de concentration",
               "other": "Récupérer +%lld pièces de concentration"},
        "de": {"one": "+%lld Fokus-Münze einsammeln",
               "other": "+%lld Fokus-Münzen einsammeln"},
        "ru": {"one": "Забрать +%lld монету фокуса",
               "few": "Забрать +%lld монеты фокуса",
               "many": "Забрать +%lld монет фокуса",
               "other": "Забрать +%lld монеты фокуса"},
        "pt-BR": {"one": "Resgatar +%lld moeda de foco",
                  "other": "Resgatar +%lld moedas de foco"},
        "it": {"one": "Riscuoti +%lld moneta di concentrazione",
               "other": "Riscuoti +%lld monete di concentrazione"},
        "ro": {"one": "Ia +%lld monedă de concentrare",
               "few": "Ia +%lld monede de concentrare",
               "other": "Ia +%lld de monede de concentrare"},
        "nl": {"one": "+%lld focusmunt ophalen", "other": "+%lld focusmunten ophalen"},
    },
    "%lld minutes": {
        "en": {"one": "%lld minute", "other": "%lld minutes"},
        "zh-Hans": {"other": "%lld 分钟"},
        "hi": {"one": "%lld मिनट", "other": "%lld मिनट"},
        "es": {"one": "%lld minuto", "other": "%lld minutos"},
        "fr": {"one": "%lld minute", "other": "%lld minutes"},
        "de": {"one": "%lld Minute", "other": "%lld Minuten"},
        "ru": {"one": "%lld минута", "few": "%lld минуты",
               "many": "%lld минут", "other": "%lld минуты"},
        "pt-BR": {"one": "%lld minuto", "other": "%lld minutos"},
        "it": {"one": "%lld minuto", "other": "%lld minuti"},
        "ro": {"one": "%lld minut", "few": "%lld minute",
               "other": "%lld de minute"},
        "nl": {"one": "%lld minuut", "other": "%lld minuten"},
    },
    "%lld focusing now": {
        "en": {"one": "%lld focusing now", "other": "%lld focusing now"},
        "zh-Hans": {"other": "%lld 人正在专注"},
        "hi": {"one": "अभी %lld फ़ोकस में", "other": "अभी %lld फ़ोकस में"},
        "es": {"one": "%lld concentrándose ahora",
               "other": "%lld concentrándose ahora"},
        "fr": {"one": "%lld personne en concentration",
               "other": "%lld personnes en concentration"},
        "de": {"one": "%lld gerade im Fokus", "other": "%lld gerade im Fokus"},
        "ru": {"one": "Сейчас в фокусе: %lld", "few": "Сейчас в фокусе: %lld",
               "many": "Сейчас в фокусе: %lld", "other": "Сейчас в фокусе: %lld"},
        "pt-BR": {"one": "%lld focando agora", "other": "%lld focando agora"},
        "it": {"one": "%lld in concentrazione ora",
               "other": "%lld in concentrazione ora"},
        "ro": {"one": "%lld se concentrează acum",
               "few": "%lld se concentrează acum",
               "other": "%lld se concentrează acum"},
        "nl": {"one": "%lld nu aan het focussen", "other": "%lld nu aan het focussen"},
    },
    "%lld day streak": {
        "en": {"one": "%lld day streak", "other": "%lld day streak"},
        "zh-Hans": {"other": "连续 %lld 天"},
        "hi": {"one": "%lld दिन की स्ट्रीक", "other": "%lld दिन की स्ट्रीक"},
        "es": {"one": "racha de %lld día", "other": "racha de %lld días"},
        "fr": {"one": "série de %lld jour", "other": "série de %lld jours"},
        "de": {"one": "%lld-Tage-Serie", "other": "%lld-Tage-Serie"},
        "ru": {"one": "серия %lld день", "few": "серия %lld дня",
               "many": "серия %lld дней", "other": "серия %lld дня"},
        "pt-BR": {"one": "sequência de %lld dia", "other": "sequência de %lld dias"},
        "it": {"one": "serie di %lld giorno", "other": "serie di %lld giorni"},
        "ro": {"one": "serie de %lld zi", "few": "serie de %lld zile",
               "other": "serie de %lld de zile"},
        "nl": {"one": "reeks van %lld dag", "other": "reeks van %lld dagen"},
    },
}


# Translator context for keys whose English is too short to disambiguate.
COMMENTS: dict[str, str] = {
    "Landed": "A FocusGlobe focus flight that finished successfully — not an aircraft.",
    "Flying": "A FocusGlobe focus session that is currently running.",
    "Open": "Verb on a button that opens a screen. Not the adjective.",
    "Current": "The streak running right now, as opposed to the all-time best.",
    "Owned": "A Store item the pilot already has in their collection.",
    "Occupied": "A Cabin placement slot that already holds another item.",
    "Coins": "Focus Coins — FocusGlobe's in-app currency. Never real money.",
    "Store": "FocusGlobe's in-app shop for Cabin items and balloon skins.",
    "Globe": "The rotating world on Home, not a lamp.",
    "Infinity": "An open-ended focus flight with no set duration. FocusGlobe PRO.",
    "RETURN": "The return leg of a boarding pass. Not the keyboard key.",
    "YOU": "Marks the pilot's own balloon among other pilots'.",
    "Block": "Block another pilot in Online, not blocking apps.",
    "Remove": "Remove a friend from the crew list.",
    "Share": "Share a result or an invite link.",
    "Preview": "Look at a balloon skin or Cabin item before buying it.",
    "Unequip": "Take an equipped balloon skin off.",
    "Destination": "The city a focus flight is heading to.",
    "or": "Separator between two sign-in options.",
}


# Nothing to translate: pure punctuation, bare format specifiers, the product
# name. Marked `shouldTranslate: false` so Xcode's editor stops asking for
# eleven identical copies and the audit stops counting them as gaps.
DO_NOT_TRANSLATE = {
    "", " ", "·", "•", "👏", "2×", "-60%", "∞",
    "%@  %@", "%@ / %@", "%@ · %@", "%@ · %@ · %@", "%@ → %@", "%@%@",
    "%lld", "%lld%%", "%lld/%lld", "×%lld", "— %@",
    "FocusGlobe", "FOCUSGLOBE", "PRO",
}

# Sentence joiners and quotation marks ARE locale-dependent typography, so they
# are translated rather than marked verbatim: Chinese ends a clause with 。,
# French quotes with « », German with „ ".
TRANSLATIONS.update({
    "%@. %@": [
        "%@。%@", "%@। %@", "%@. %@", "%@. %@", "%@. %@", "%@. %@",
        "%@. %@", "%@. %@", "%@. %@", "%@. %@",
    ],
    "%@. %@. %@": [
        "%@。%@。%@", "%@। %@। %@", "%@. %@. %@", "%@. %@. %@", "%@. %@. %@",
        "%@. %@. %@", "%@. %@. %@", "%@. %@. %@", "%@. %@. %@", "%@. %@. %@",
    ],
    "“%@”": [
        "「%@」", "“%@”", "«%@»", "« %@ »", "„%@“", "«%@»",
        "“%@”", "«%@»", "„%@”", "‘%@’",
    ],
    # Present in the widget catalog too; the app renders them as well.
    "Resume": [
        "继续", "जारी रखें", "Reanudar", "Reprendre", "Fortsetzen",
        "Продолжить", "Retomar", "Riprendi", "Reia", "Hervatten",
    ],
})

PLURALS.update({
    "%lld focus days": {
        "en": {"one": "%lld focus day", "other": "%lld focus days"},
        "zh-Hans": {"other": "%lld 个专注日"},
        "hi": {"one": "%lld फ़ोकस दिन", "other": "%lld फ़ोकस दिन"},
        "es": {"one": "%lld día de concentración",
               "other": "%lld días de concentración"},
        "fr": {"one": "%lld jour de concentration",
               "other": "%lld jours de concentration"},
        "de": {"one": "%lld Fokus-Tag", "other": "%lld Fokus-Tage"},
        "ru": {"one": "%lld день фокуса", "few": "%lld дня фокуса",
               "many": "%lld дней фокуса", "other": "%lld дня фокуса"},
        "pt-BR": {"one": "%lld dia de foco", "other": "%lld dias de foco"},
        "it": {"one": "%lld giorno di concentrazione",
               "other": "%lld giorni di concentrazione"},
        "ro": {"one": "%lld zi de concentrare", "few": "%lld zile de concentrare",
               "other": "%lld de zile de concentrare"},
        "nl": {"one": "%lld focusdag", "other": "%lld focusdagen"},
    },
    "%lld-day streak": {
        "en": {"one": "%lld-day streak", "other": "%lld-day streak"},
        "zh-Hans": {"other": "连续 %lld 天"},
        "hi": {"one": "%lld दिन की स्ट्रीक", "other": "%lld दिन की स्ट्रीक"},
        "es": {"one": "racha de %lld día", "other": "racha de %lld días"},
        "fr": {"one": "série de %lld jour", "other": "série de %lld jours"},
        "de": {"one": "%lld-Tage-Serie", "other": "%lld-Tage-Serie"},
        "ru": {"one": "серия %lld день", "few": "серия %lld дня",
               "many": "серия %lld дней", "other": "серия %lld дня"},
        "pt-BR": {"one": "sequência de %lld dia", "other": "sequência de %lld dias"},
        "it": {"one": "serie di %lld giorno", "other": "serie di %lld giorni"},
        "ro": {"one": "serie de %lld zi", "few": "serie de %lld zile",
               "other": "serie de %lld de zile"},
        "nl": {"one": "reeks van %lld dag", "other": "reeks van %lld dagen"},
    },
})
