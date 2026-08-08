"""Tranche 5a — the Screen Time shield, in the shield extension's own catalog.

A shield extension is a separate process with its own bundle, so these strings
cannot live in the app's catalog: it never loads one.

TONE, WHICH THE TRANSLATIONS HAD TO PRESERVE
    These lines appear on a screen the pilot cannot dismiss, at the moment they
    reached for a distraction. The English is encouraging and never scolding —
    no "you failed", no guilt, no fake urgency. Several languages default to a
    sterner register in the imperative; each line here was chosen to stay warm.

    They are also all FocusGlobe's own words: no quotations, no attribution, no
    borrowed slogans. Nothing in this file may become one in translation.
"""

CATALOG = "shield"

# key -> [zh-Hans, hi, es, fr, de, ru, pt-BR, it, ro, nl]
TRANSLATIONS: dict[str, list[str]] = {

    # ---- Buttons ----------------------------------------------------------
    "Return to FocusGlobe": [
        "返回 FocusGlobe", "FocusGlobe पर लौटें", "Volver a FocusGlobe",
        "Revenir à FocusGlobe", "Zurück zu FocusGlobe", "Вернуться в FocusGlobe",
        "Voltar ao FocusGlobe", "Torna a FocusGlobe", "Înapoi la FocusGlobe",
        "Terug naar FocusGlobe",
    ],
    "Close": [
        "关闭", "बंद करें", "Cerrar", "Fermer", "Schließen", "Закрыть",
        "Fechar", "Chiudi", "Închide", "Sluiten",
    ],

    # ---- The eight lines --------------------------------------------------
    "That scroll can wait": [
        "刷一刷可以等等", "यह स्क्रॉल इंतज़ार कर सकता है", "Ese scroll puede esperar",
        "Ce scroll peut attendre", "Das Scrollen kann warten",
        "Лента подождёт", "Essa rolagem pode esperar",
        "Quello scroll può aspettare", "Scrollul mai poate aștepta",
        "Dat scrollen kan wachten",
    ],
    "Your goal can’t. Keep flying.": [
        "但你的目标不能。继续飞行。", "आपका लक्ष्य नहीं। उड़ते रहें।",
        "Tu objetivo no. Sigue volando.", "Pas votre objectif. Continuez à voler.",
        "Dein Ziel nicht. Flieg weiter.", "А ваша цель — нет. Продолжайте полёт.",
        "Seu objetivo não. Continue voando.", "Il tuo obiettivo no. Continua a volare.",
        "Obiectivul tău, nu. Continuă zborul.", "Je doel niet. Blijf vliegen.",
    ],
    "Don’t trade your goal": [
        "别拿目标去交换", "अपना लक्ष्य मत बदलिए", "No cambies tu objetivo",
        "N’échangez pas votre objectif", "Tausch dein Ziel nicht ein",
        "Не меняйте свою цель", "Não troque seu objetivo",
        "Non barattare il tuo obiettivo", "Nu-ți da obiectivul la schimb",
        "Ruil je doel niet in",
    ],
    "A distraction is a poor exchange rate.": [
        "分心是一笔很差的交易。", "ध्यान भटकाना बहुत महँगा सौदा है।",
        "Una distracción es un mal cambio.",
        "Une distraction, c’est un mauvais taux de change.",
        "Eine Ablenkung ist ein schlechter Tausch.",
        "Отвлечение — невыгодный обмен.",
        "Uma distração é uma troca ruim.",
        "Una distrazione è un pessimo cambio.",
        "O distragere e un schimb prost.",
        "Een afleiding is een slechte ruil.",
    ],
    "Protect who you’re becoming": [
        "守护正在成为的自己", "आप जो बन रहे हैं, उसकी रक्षा करें",
        "Protege a quien estás llegando a ser",
        "Protégez celui ou celle que vous devenez",
        "Schütze, wer du gerade wirst", "Берегите того, кем становитесь",
        "Proteja quem você está se tornando",
        "Proteggi la persona che stai diventando",
        "Protejează-l pe cel care devii",
        "Bescherm wie je aan het worden bent",
    ],
    "This is the part that builds them.": [
        "正是这一刻在塑造他。", "यही वह हिस्सा है जो उसे बनाता है।",
        "Esta es la parte que lo construye.",
        "C’est ce moment qui le construit.",
        "Genau das baut ihn auf.", "Именно это его и создаёт.",
        "É esta parte que o constrói.",
        "È questa la parte che lo costruisce.",
        "Aceasta e partea care îl clădește.",
        "Dit is het deel dat hem opbouwt.",
    ],
    "The urge will pass": [
        "这股冲动会过去", "यह इच्छा गुज़र जाएगी", "El impulso pasará",
        "L’envie va passer", "Der Drang geht vorbei", "Это желание пройдёт",
        "A vontade vai passar", "L’impulso passerà", "Impulsul va trece",
        "De drang gaat voorbij",
    ],
    "It always does. Stay in the air.": [
        "它总会过去。留在空中。", "हमेशा गुज़रती है। हवा में बने रहें।",
        "Siempre pasa. Sigue en el aire.", "Elle passe toujours. Restez en l’air.",
        "Das tut er immer. Bleib in der Luft.", "Оно всегда проходит. Оставайтесь в небе.",
        "Sempre passa. Fique no ar.", "Passa sempre. Resta in volo.",
        "Întotdeauna trece. Rămâi în aer.", "Dat gaat altijd voorbij. Blijf in de lucht.",
    ],
    "Your future deserves this": [
        "你的未来值得这一刻", "आपका भविष्य इसका हक़दार है",
        "Tu futuro se merece esto", "Votre avenir mérite ce moment",
        "Deine Zukunft hat das verdient", "Ваше будущее этого заслуживает",
        "Seu futuro merece isso", "Il tuo futuro se lo merita",
        "Viitorul tău merită asta", "Je toekomst verdient dit",
    ],
    "So does the hour you already committed.": [
        "你已经投入的这一小时也是。", "और वह घंटा भी जो आप पहले ही लगा चुके हैं।",
        "Y también la hora que ya has invertido.",
        "Et l’heure que vous y avez déjà consacrée aussi.",
        "Und die Stunde, die du schon investiert hast, auch.",
        "И тот час, что вы уже вложили, — тоже.",
        "E a hora que você já dedicou também.",
        "E anche l’ora che hai già investito.",
        "La fel și ora pe care ai investit-o deja.",
        "En het uur dat je er al in stak ook.",
    ],
    "Five focused minutes": [
        "五分钟的专注", "पाँच फ़ोकस्ड मिनट", "Cinco minutos de concentración",
        "Cinq minutes de concentration", "Fünf fokussierte Minuten",
        "Пять минут фокуса", "Cinco minutos de foco",
        "Cinque minuti di concentrazione", "Cinci minute de concentrare",
        "Vijf minuten focus",
    ],
    "That’s all it takes to change your day.": [
        "就足以改变你的一天。", "आपका दिन बदलने के लिए बस इतना ही काफ़ी है।",
        "Es todo lo que hace falta para cambiar tu día.",
        "C’est tout ce qu’il faut pour changer votre journée.",
        "Mehr braucht es nicht, um deinen Tag zu ändern.",
        "Этого достаточно, чтобы изменить день.",
        "É só o que basta para mudar seu dia.",
        "È tutto ciò che serve per cambiare la giornata.",
        "Atât e nevoie ca să-ți schimbi ziua.",
        "Meer heb je niet nodig om je dag te veranderen.",
    ],
    "Stay on course": [
        "保持航向", "अपनी राह पर बने रहें", "Mantén el rumbo", "Gardez le cap",
        "Bleib auf Kurs", "Держите курс", "Mantenha o rumo", "Mantieni la rotta",
        "Rămâi pe traseu", "Blijf op koers",
    ],
    "Finish what you started.": [
        "完成你已开始的事。", "जो शुरू किया है, उसे पूरा करें।",
        "Termina lo que empezaste.", "Terminez ce que vous avez commencé.",
        "Bring zu Ende, was du begonnen hast.", "Закончите начатое.",
        "Termine o que começou.", "Finisci ciò che hai iniziato.",
        "Termină ce ai început.", "Maak af waar je aan begon.",
    ],
    "Not worth your momentum": [
        "不值得你的势头", "आपकी रफ़्तार इसके लायक नहीं",
        "No vale tu impulso", "Ça ne vaut pas votre élan",
        "Deinen Schwung nicht wert", "Не стоит вашего разгона",
        "Não vale seu impulso", "Non vale il tuo slancio",
        "Nu merită avântul tău", "Je vaart niet waard",
    ],
    "You’ve built something. Don’t spend it here.": [
        "你已经积累了一些。别花在这里。",
        "आपने कुछ बनाया है। इसे यहाँ ख़र्च मत कीजिए।",
        "Has construido algo. No lo gastes aquí.",
        "Vous avez construit quelque chose. Ne le dépensez pas ici.",
        "Du hast dir etwas aufgebaut. Gib es nicht hier aus.",
        "Вы кое-что построили. Не тратьте это здесь.",
        "Você construiu algo. Não gaste isso aqui.",
        "Hai costruito qualcosa. Non spenderlo qui.",
        "Ai construit ceva. Nu-l cheltui aici.",
        "Je hebt iets opgebouwd. Geef het hier niet uit.",
    ],
}
