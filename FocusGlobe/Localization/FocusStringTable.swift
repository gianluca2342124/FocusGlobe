import Foundation

/// The string tables, compiled in.
///
/// Deliberately NOT `.lproj` bundles or a String Catalog. Two reasons, both
/// about honesty rather than convenience:
///
/// 1. Adding `es`/`it` to the project's `knownRegions` publishes the app to the
///    App Store as *available in Spanish and Italian*. Until every surface is
///    translated that is a claim the binary cannot keep, and a store listing is
///    not something a runtime feature flag can take back.
/// 2. A missing key in a `.strings` file renders the KEY on screen. Here a
///    missing key falls back to English, and `missingKeys(for:)` turns "is this
///    language finished?" into something the app computes at launch instead of
///    something a person remembers to check.
///
/// When every surface routes through this table, moving to a String Catalog is
/// a mechanical export — the keys, the placeholder contracts and the coverage
/// gate all survive it. See LOCALIZATION.md.
enum FocusStringTable {

    /// Look a key up in a language, falling back to English.
    ///
    /// English is the source language and is asserted complete at launch, so
    /// this cannot return nil and cannot return a raw key.
    static func string(_ key: FocusStringKey, language: AppLanguage) -> String {
        if let value = table(for: language.resolved)[key], !value.isEmpty { return value }
        return english[key] ?? key.rawValue
    }

    static func table(for language: AppLanguage) -> [FocusStringKey: String] {
        switch language.resolved {
        case .english: return english
        case .spanish: return spanish
        case .italian: return italian
        case .system:  return english   // unreachable: `.resolved` never returns `.system`
        }
    }

    /// Keys this language does not supply, optionally narrowed to one surface.
    /// This is the input to `LocalizationCoverage`, and therefore to whether the
    /// language is offered at all.
    static func missingKeys(for language: AppLanguage,
                            surface: LocalizationSurface?) -> [FocusStringKey] {
        let language = language.resolved
        guard language != .english else { return [] }
        let table = table(for: language)
        return FocusStringKey.allCases.filter { key in
            if let surface, key.surface != surface { return false }
            guard let value = table[key] else { return true }
            return value.isEmpty
        }
    }

    // MARK: - English (source language)

    static let english: [FocusStringKey: String] = [
        // Chrome
        .obContinue:                "Continue",
        .obBack:                    "Back",
        .obSkip:                    "Skip",
        .obNotNow:                  "Not now",
        .obRecommended:             "Recommended",
        .obStepOfFormat:            "Step %1$d of %2$d",

        // Sections
        .obSectionAbout:            "About you",
        .obSectionRhythm:           "Your rhythm",
        .obSectionAtmosphere:       "Your atmosphere",
        .obSectionPlan:             "Your plan",
        .obSectionOffer:            "FocusGlobe PRO",
        .obSectionFinish:           "Ready",

        // Welcome
        .obWelcomeTitle:            "Welcome to FocusGlobe",
        .obWelcomeSubtitle:         "Focused time becomes a journey. Answer a few questions and we'll set up your first flight.",
        .obWelcomeCTA:              "Get started",
        .obWelcomeLanguage:         "Language",
        .obLanguageSystem:          "System",

        // Goal
        .obGoalTitle:               "What do you want more focus for?",
        .obGoalSubtitle:            "This shapes your first flight.",
        .obGoalStudy:               "Studying and exams",
        .obGoalDeepWork:            "Deep work",
        .obGoalBuildProject:        "Building a project",
        .obGoalReadLearn:           "Reading and learning",
        .obGoalReduceScreenTime:    "Reducing screen time",
        .obGoalConsistency:         "Building daily consistency",

        // Obstacle
        .obObstacleTitle:           "What usually gets in the way?",
        .obObstacleSubtitle:        "Pick the one that happens most.",
        .obObstacleApps:            "I reach for distracting apps",
        .obObstacleProcrastination: "I put off starting",
        .obObstacleMomentum:        "I lose momentum partway",
        .obObstacleOverwhelm:       "It all feels like a lot",
        .obObstacleEnvironment:     "My surroundings interrupt me",
        .obObstacleUnsure:          "I don't know how long to focus",

        // Duration + commitment line
        .obDurationTitle:           "How long is your first flight?",
        .obDurationSubtitle:        "You can change this before every flight.",
        .obDurationBridgeStudy:     "You're here to make studying easier.",
        .obDurationBridgeDeepWork:  "You're here to protect real deep work.",
        .obDurationBridgeBuild:     "You're here to keep building your project.",
        .obDurationBridgeRead:      "You're here to read and learn more.",
        .obDurationBridgeScreen:    "You're here to spend less time on your phone.",
        .obDurationBridgeConsistency: "You're here to show up more often.",
        .obDurationReasonApps:      "Because apps are what pull you away, a shorter first flight is easier to protect.",
        .obDurationReasonProcrast:  "Because starting is the hard part, a shorter first flight is easier to begin.",
        .obDurationReasonMomentum:  "Because momentum is what slips, a flight you finish is worth more than a long one.",
        .obDurationReasonOverwhelm: "Because it can feel like a lot, we'll start small on purpose.",
        .obDurationReasonEnvironment: "Because your surroundings interrupt you, a shorter flight is easier to defend.",
        .obDurationReasonUnsure:    "Because the right length isn't obvious yet, we'll suggest one you can adjust.",
        .obDurationMinutesFormat:   "%d min",
        .obDurationChooseForMe:     "Choose for me",

        // Cadence
        .obCadenceTitle:            "How often do you want to fly?",
        .obCadenceSubtitle:         "A target you'll actually keep beats an ambitious one.",
        .obCadenceThree:            "3 days a week",
        .obCadenceFive:             "5 days a week",
        .obCadenceEvery:            "Every day",
        .obCadenceFlexible:         "Keep it flexible",

        // Company
        .obCompanyTitle:            "How do you focus best?",
        .obCompanySubtitle:         "We'll pre-select your flight mode. Nothing is shared until you fly.",
        .obCompanyAlone:            "On my own",
        .obCompanyFriends:          "With friends",
        .obCompanyOthers:           "Around other focused people",
        .obCompanyMixed:            "A mix of both",

        // Shield preference
        .obShieldTitle:             "Should we block distracting apps while you fly?",
        .obShieldSubtitle:          "This only sets a preference. iOS asks for Screen Time permission later, and only if you say yes.",
        .obShieldYes:               "Yes — block selected apps during flights",
        .obShieldLater:             "Maybe later",

        // Sky
        .obSkyTitle:                "Choose your Sky",
        .obSkySubtitle:             "The world your balloon flies through. More unlock as you go.",
        .obSkyLocked:               "PRO",

        // Sound
        .obSoundTitle:              "Pick your soundscape",
        .obSoundSubtitle:           "Plays quietly while you fly. Change it any time.",
        .obSoundSilence:            "Silence",

        // Plan preparation
        .obPlanBuildingTitle:       "Building your plan",
        .obPlanBuildingGoal:        "Matching your goal",
        .obPlanBuildingLength:      "Setting your first flight",
        .obPlanBuildingAtmosphere:  "Preparing your Sky and sound",

        // Plan reveal
        .obPlanTitle:               "Your focus plan",
        .obPlanRowFlight:           "First flight",
        .obPlanRowWeekly:           "Weekly target",
        .obPlanRowMode:             "Flight mode",
        .obPlanRowSky:              "Sky",
        .obPlanRowSound:            "Sound",
        .obPlanRowShield:           "Focus Shield",
        .obPlanMinutesFormat:       "%d minutes",
        .obPlanDaysFormat:          "%d days a week",
        .obPlanFlexible:            "Flexible",
        .obPlanShieldOn:            "Recommended",
        .obPlanShieldOff:           "Off for now",
        .obPlanModeSolo:            "Solo",
        .obPlanModePrivate:         "With friends",
        .obPlanModePublic:          "Online",
        .obPlanRationaleApps:       "Built to be easier to protect from the apps that pull you away.",
        .obPlanRationaleProcrast:   "Built to be easy to start on the days you don't feel like it.",
        .obPlanRationaleMomentum:   "Built to be easy to come back to.",
        .obPlanRationaleOverwhelm:  "Built to feel like less, not more.",
        .obPlanRationaleEnvironment: "Built to hold up when your surroundings don't.",
        .obPlanRationaleUnsure:     "Built around a length that fits, which you can change any time.",
        .obPlanCTA:                 "Looks good",
        .obPlanAdjust:              "Adjust",

        // Flight preview
        .obPreviewTitle:            "This is a flight",
        .obPreviewSubtitle:         "Your balloon travels while you focus. This is only a preview — nothing is being counted yet.",
        .obPreviewCTA:              "Got it",
        .obPreviewSkip:             "Skip preview",

        // Reminder warm-up
        .obNotifyTitle:             "A nudge on your focus days",
        .obNotifySubtitle:          "One quiet reminder on the days you chose. No marketing, ever, and you can turn it off in Settings.",
        .obNotifyCTA:               "Turn on reminders",

        // Shield warm-up
        .obShieldWarmTitle:         "Block distracting apps while you fly",
        .obShieldWarmSubtitle:      "You pick the apps. They're blocked only while a flight is in the air, and never at any other time.",
        .obShieldWarmCTA:           "Choose apps to block",

        // Completion
        .obDoneTitle:               "Your plan is ready",
        .obDoneSubtitle:            "Your first flight is set up and waiting.",
        .obDoneCTA:                 "Start my first flight",
        .obDoneSignIn:              "Sign in with Apple",
        .obDoneSignInDetail:        "Optional. Keeps your progress if you change device.",

        // Paywall headlines
        .paywallHeadShield:         "Keep the apps out of your flights",
        .paywallHeadTime:           "Fly for as long as the work takes",
        .paywallHeadOnline:         "Focus alongside other pilots",
        .paywallHeadSkies:          "Fly Skies only PRO pilots reach",
        .paywallHeadSkins:          "Make the balloon and Cabin yours",
        .paywallHeadWidgets:        "Your streak, one tap from the Home Screen",
        .paywallHeadCoins:          "Earn twice the Coins on every journey",
        .paywallSubhead:            "Your whole plan works without PRO. This removes the limits.",
        .paywallFreePath:           "Continue without PRO",

        // Benefits
        .benefitShieldTitle:        "Focus Shield",
        .benefitShieldDetail:       "Block the apps that pull you away, for the length of a flight.",
        .benefitTimeTitle:          "Unlimited focus time",
        .benefitTimeDetail:         "Fly for as long as the work takes.",
        .benefitOnlineTitle:        "Online & Friends",
        .benefitOnlineDetail:       "Focus alongside other pilots, or invite your own.",
        .benefitSkiesTitle:         "Exclusive Skies",
        .benefitSkiesDetail:        "Four Skies only PRO pilots can fly.",
        .benefitSkinsTitle:         "Exclusive skins & Cabin items",
        .benefitSkinsDetail:        "Make the balloon and the Cabin yours.",
        .benefitWidgetsTitle:       "Widgets & Passport",
        .benefitWidgetsDetail:      "Your streak and next flight, one tap from the Home Screen.",
        .benefitCoinsTitle:         "2× Coins in journeys",
        .benefitCoinsDetail:        "Every completed journey pays twice as much.",

        // Paywall chrome
        .paywallRestore:            "Restore Purchases",
        .paywallTerms:              "Terms of Use",
        .paywallPrivacy:            "Privacy Policy",
        .paywallBestValue:          "Best value",
    ]

    // MARK: - Español

    static let spanish: [FocusStringKey: String] = [
        .obContinue:                "Continuar",
        .obBack:                    "Atrás",
        .obSkip:                    "Omitir",
        .obNotNow:                  "Ahora no",
        .obRecommended:             "Recomendado",
        .obStepOfFormat:            "Paso %1$d de %2$d",

        .obSectionAbout:            "Sobre ti",
        .obSectionRhythm:           "Tu ritmo",
        .obSectionAtmosphere:       "Tu ambiente",
        .obSectionPlan:             "Tu plan",
        .obSectionOffer:            "FocusGlobe PRO",
        .obSectionFinish:           "Listo",

        .obWelcomeTitle:            "Te damos la bienvenida a FocusGlobe",
        .obWelcomeSubtitle:         "El tiempo de concentración se convierte en un viaje. Responde unas preguntas y preparamos tu primer vuelo.",
        .obWelcomeCTA:              "Empezar",
        .obWelcomeLanguage:         "Idioma",
        .obLanguageSystem:          "Sistema",

        .obGoalTitle:               "¿Para qué quieres concentrarte más?",
        .obGoalSubtitle:            "Esto define tu primer vuelo.",
        .obGoalStudy:               "Estudiar y exámenes",
        .obGoalDeepWork:            "Trabajo profundo",
        .obGoalBuildProject:        "Sacar adelante un proyecto",
        .obGoalReadLearn:           "Leer y aprender",
        .obGoalReduceScreenTime:    "Reducir el tiempo de pantalla",
        .obGoalConsistency:         "Crear constancia diaria",

        .obObstacleTitle:           "¿Qué suele interponerse?",
        .obObstacleSubtitle:        "Elige lo que te pasa más a menudo.",
        .obObstacleApps:            "Acabo en apps que me distraen",
        .obObstacleProcrastination: "Me cuesta empezar",
        .obObstacleMomentum:        "Pierdo el ritmo a medias",
        .obObstacleOverwhelm:       "Se me hace demasiado",
        .obObstacleEnvironment:     "Mi entorno me interrumpe",
        .obObstacleUnsure:          "No sé cuánto tiempo concentrarme",

        .obDurationTitle:           "¿Cuánto durará tu primer vuelo?",
        .obDurationSubtitle:        "Puedes cambiarlo antes de cada vuelo.",
        .obDurationBridgeStudy:     "Estás aquí para que estudiar te cueste menos.",
        .obDurationBridgeDeepWork:  "Estás aquí para proteger el trabajo profundo de verdad.",
        .obDurationBridgeBuild:     "Estás aquí para seguir avanzando con tu proyecto.",
        .obDurationBridgeRead:      "Estás aquí para leer y aprender más.",
        .obDurationBridgeScreen:    "Estás aquí para pasar menos tiempo con el móvil.",
        .obDurationBridgeConsistency: "Estás aquí para aparecer más a menudo.",
        .obDurationReasonApps:      "Como son las apps las que te apartan, un primer vuelo corto es más fácil de proteger.",
        .obDurationReasonProcrast:  "Como lo difícil es empezar, un primer vuelo corto cuesta menos de arrancar.",
        .obDurationReasonMomentum:  "Como lo que se pierde es el ritmo, vale más un vuelo que terminas que uno largo.",
        .obDurationReasonOverwhelm: "Como puede hacerse cuesta arriba, empezamos poco a poco a propósito.",
        .obDurationReasonEnvironment: "Como tu entorno te interrumpe, un vuelo corto es más fácil de defender.",
        .obDurationReasonUnsure:    "Como aún no está claro cuánto, te proponemos una duración y la ajustas.",
        .obDurationMinutesFormat:   "%d min",
        .obDurationChooseForMe:     "Elige por mí",

        .obCadenceTitle:            "¿Con qué frecuencia quieres volar?",
        .obCadenceSubtitle:         "Un objetivo que cumplas vale más que uno ambicioso.",
        .obCadenceThree:            "3 días a la semana",
        .obCadenceFive:             "5 días a la semana",
        .obCadenceEvery:            "Todos los días",
        .obCadenceFlexible:         "Sin fijar días",

        .obCompanyTitle:            "¿Cómo te concentras mejor?",
        .obCompanySubtitle:         "Preseleccionamos tu modo de vuelo. No se comparte nada hasta que vueles.",
        .obCompanyAlone:            "Por mi cuenta",
        .obCompanyFriends:          "Con amigos",
        .obCompanyOthers:           "Rodeado de gente concentrada",
        .obCompanyMixed:            "Un poco de cada",

        .obShieldTitle:             "¿Bloqueamos las apps que distraen mientras vuelas?",
        .obShieldSubtitle:          "Esto solo marca una preferencia. iOS pedirá el permiso de Tiempo de uso más adelante, y solo si dices que sí.",
        .obShieldYes:               "Sí, bloquea las apps que elija durante los vuelos",
        .obShieldLater:             "Quizá más adelante",

        .obSkyTitle:                "Elige tu Cielo",
        .obSkySubtitle:             "El mundo por el que vuela tu globo. Desbloquearás más sobre la marcha.",
        .obSkyLocked:               "PRO",

        .obSoundTitle:              "Elige tu ambiente sonoro",
        .obSoundSubtitle:           "Suena bajito mientras vuelas. Cámbialo cuando quieras.",
        .obSoundSilence:            "Silencio",

        .obPlanBuildingTitle:       "Preparando tu plan",
        .obPlanBuildingGoal:        "Ajustando tu objetivo",
        .obPlanBuildingLength:      "Fijando tu primer vuelo",
        .obPlanBuildingAtmosphere:  "Preparando tu Cielo y tu sonido",

        .obPlanTitle:               "Tu plan de concentración",
        .obPlanRowFlight:           "Primer vuelo",
        .obPlanRowWeekly:           "Objetivo semanal",
        .obPlanRowMode:             "Modo de vuelo",
        .obPlanRowSky:              "Cielo",
        .obPlanRowSound:            "Sonido",
        .obPlanRowShield:           "Escudo de concentración",
        .obPlanMinutesFormat:       "%d minutos",
        .obPlanDaysFormat:          "%d días a la semana",
        .obPlanFlexible:            "Flexible",
        .obPlanShieldOn:            "Recomendado",
        .obPlanShieldOff:           "De momento no",
        .obPlanModeSolo:            "En solitario",
        .obPlanModePrivate:         "Con amigos",
        .obPlanModePublic:          "En línea",
        .obPlanRationaleApps:       "Pensado para protegerte mejor de las apps que te apartan.",
        .obPlanRationaleProcrast:   "Pensado para arrancar fácil los días que no te apetece.",
        .obPlanRationaleMomentum:   "Pensado para que retomarlo sea sencillo.",
        .obPlanRationaleOverwhelm:  "Pensado para que sea menos, no más.",
        .obPlanRationaleEnvironment: "Pensado para aguantar cuando tu entorno no acompaña.",
        .obPlanRationaleUnsure:     "Pensado con una duración que encaja y que puedes cambiar cuando quieras.",
        .obPlanCTA:                 "Me convence",
        .obPlanAdjust:              "Ajustar",

        .obPreviewTitle:            "Así es un vuelo",
        .obPreviewSubtitle:         "Tu globo viaja mientras te concentras. Esto es solo una vista previa: todavía no cuenta nada.",
        .obPreviewCTA:              "Entendido",
        .obPreviewSkip:             "Saltar la vista previa",

        .obNotifyTitle:             "Un aviso en tus días de concentración",
        .obNotifySubtitle:          "Un recordatorio discreto en los días que elegiste. Nunca publicidad, y puedes desactivarlo en Ajustes.",
        .obNotifyCTA:               "Activar recordatorios",

        .obShieldWarmTitle:         "Bloquea las apps que distraen mientras vuelas",
        .obShieldWarmSubtitle:      "Tú eliges las apps. Se bloquean solo mientras hay un vuelo en el aire, nunca en otro momento.",
        .obShieldWarmCTA:           "Elegir apps para bloquear",

        .obDoneTitle:               "Tu plan está listo",
        .obDoneSubtitle:            "Tu primer vuelo ya está preparado y esperando.",
        .obDoneCTA:                 "Empezar mi primer vuelo",
        .obDoneSignIn:              "Iniciar sesión con Apple",
        .obDoneSignInDetail:        "Opcional. Conserva tu progreso si cambias de dispositivo.",

        .paywallHeadShield:         "Mantén las apps fuera de tus vuelos",
        .paywallHeadTime:           "Vuela todo lo que dure el trabajo",
        .paywallHeadOnline:         "Concéntrate junto a otros pilotos",
        .paywallHeadSkies:          "Vuela Cielos que solo alcanzan los pilotos PRO",
        .paywallHeadSkins:          "Haz tuyos el globo y la Cabina",
        .paywallHeadWidgets:        "Tu racha, a un toque desde la pantalla de inicio",
        .paywallHeadCoins:          "Gana el doble de Monedas en cada viaje",
        .paywallSubhead:            "Tu plan funciona entero sin PRO. Esto solo quita los límites.",
        .paywallFreePath:           "Continuar sin PRO",

        .benefitShieldTitle:        "Escudo de concentración",
        .benefitShieldDetail:       "Bloquea las apps que te apartan mientras dura un vuelo.",
        .benefitTimeTitle:          "Tiempo de concentración ilimitado",
        .benefitTimeDetail:         "Vuela todo lo que dure el trabajo.",
        .benefitOnlineTitle:        "En línea y Amigos",
        .benefitOnlineDetail:       "Concéntrate junto a otros pilotos o invita a los tuyos.",
        .benefitSkiesTitle:         "Cielos exclusivos",
        .benefitSkiesDetail:        "Cuatro Cielos que solo pueden volar los pilotos PRO.",
        .benefitSkinsTitle:         "Diseños y objetos de Cabina exclusivos",
        .benefitSkinsDetail:        "Haz tuyos el globo y la Cabina.",
        .benefitWidgetsTitle:       "Widgets y Pasaporte",
        .benefitWidgetsDetail:      "Tu racha y tu próximo vuelo, a un toque desde la pantalla de inicio.",
        .benefitCoinsTitle:         "2× Monedas en los viajes",
        .benefitCoinsDetail:        "Cada viaje completado paga el doble.",

        .paywallRestore:            "Restaurar compras",
        .paywallTerms:              "Términos de uso",
        .paywallPrivacy:            "Política de privacidad",
        .paywallBestValue:          "Mejor precio",
    ]

    // MARK: - Italiano

    static let italian: [FocusStringKey: String] = [
        .obContinue:                "Continua",
        .obBack:                    "Indietro",
        .obSkip:                    "Salta",
        .obNotNow:                  "Non ora",
        .obRecommended:             "Consigliato",
        .obStepOfFormat:            "Passo %1$d di %2$d",

        .obSectionAbout:            "Su di te",
        .obSectionRhythm:           "Il tuo ritmo",
        .obSectionAtmosphere:       "La tua atmosfera",
        .obSectionPlan:             "Il tuo piano",
        .obSectionOffer:            "FocusGlobe PRO",
        .obSectionFinish:           "Pronto",

        .obWelcomeTitle:            "Benvenuto su FocusGlobe",
        .obWelcomeSubtitle:         "Il tempo di concentrazione diventa un viaggio. Rispondi a poche domande e prepariamo il tuo primo volo.",
        .obWelcomeCTA:              "Iniziamo",
        .obWelcomeLanguage:         "Lingua",
        .obLanguageSystem:          "Sistema",

        .obGoalTitle:               "Per cosa vuoi più concentrazione?",
        .obGoalSubtitle:            "Questo definisce il tuo primo volo.",
        .obGoalStudy:               "Studio ed esami",
        .obGoalDeepWork:            "Lavoro profondo",
        .obGoalBuildProject:        "Portare avanti un progetto",
        .obGoalReadLearn:           "Leggere e imparare",
        .obGoalReduceScreenTime:    "Ridurre il tempo davanti allo schermo",
        .obGoalConsistency:         "Costruire costanza quotidiana",

        .obObstacleTitle:           "Cosa ti si mette di mezzo di solito?",
        .obObstacleSubtitle:        "Scegli quello che ti capita più spesso.",
        .obObstacleApps:            "Finisco sulle app che mi distraggono",
        .obObstacleProcrastination: "Rimando sempre l'inizio",
        .obObstacleMomentum:        "Perdo il ritmo a metà",
        .obObstacleOverwhelm:       "Mi sembra tutto troppo",
        .obObstacleEnvironment:     "L'ambiente attorno mi interrompe",
        .obObstacleUnsure:          "Non so per quanto concentrarmi",

        .obDurationTitle:           "Quanto dura il tuo primo volo?",
        .obDurationSubtitle:        "Puoi cambiarlo prima di ogni volo.",
        .obDurationBridgeStudy:     "Sei qui per rendere lo studio più semplice.",
        .obDurationBridgeDeepWork:  "Sei qui per proteggere il lavoro profondo vero.",
        .obDurationBridgeBuild:     "Sei qui per continuare a far crescere il tuo progetto.",
        .obDurationBridgeRead:      "Sei qui per leggere e imparare di più.",
        .obDurationBridgeScreen:    "Sei qui per passare meno tempo al telefono.",
        .obDurationBridgeConsistency: "Sei qui per esserci più spesso.",
        .obDurationReasonApps:      "Visto che sono le app a portarti via, un primo volo breve è più facile da proteggere.",
        .obDurationReasonProcrast:  "Visto che la parte difficile è iniziare, un primo volo breve costa meno fatica.",
        .obDurationReasonMomentum:  "Visto che è il ritmo a cedere, vale di più un volo che finisci che uno lungo.",
        .obDurationReasonOverwhelm: "Visto che può sembrare tanto, partiamo piccoli di proposito.",
        .obDurationReasonEnvironment: "Visto che l'ambiente ti interrompe, un volo breve è più facile da difendere.",
        .obDurationReasonUnsure:    "Visto che la durata giusta non è ancora chiara, te ne proponiamo una e la aggiusti.",
        .obDurationMinutesFormat:   "%d min",
        .obDurationChooseForMe:     "Scegli tu per me",

        .obCadenceTitle:            "Quanto spesso vuoi volare?",
        .obCadenceSubtitle:         "Un obiettivo che rispetti vale più di uno ambizioso.",
        .obCadenceThree:            "3 giorni a settimana",
        .obCadenceFive:             "5 giorni a settimana",
        .obCadenceEvery:            "Tutti i giorni",
        .obCadenceFlexible:         "Senza giorni fissi",

        .obCompanyTitle:            "Come ti concentri meglio?",
        .obCompanySubtitle:         "Preselezioniamo la tua modalità di volo. Non si condivide nulla finché non voli.",
        .obCompanyAlone:            "Per conto mio",
        .obCompanyFriends:          "Con gli amici",
        .obCompanyOthers:           "Insieme ad altri concentrati",
        .obCompanyMixed:            "Un po' e un po'",

        .obShieldTitle:             "Blocchiamo le app che distraggono mentre voli?",
        .obShieldSubtitle:          "Qui imposti solo una preferenza. iOS chiederà il permesso Tempo di utilizzo più avanti, e solo se dici di sì.",
        .obShieldYes:               "Sì, blocca le app che scelgo durante i voli",
        .obShieldLater:             "Magari più avanti",

        .obSkyTitle:                "Scegli il tuo Cielo",
        .obSkySubtitle:             "Il mondo attraversato dalla tua mongolfiera. Ne sbloccherai altri strada facendo.",
        .obSkyLocked:               "PRO",

        .obSoundTitle:              "Scegli il tuo paesaggio sonoro",
        .obSoundSubtitle:           "Suona piano mentre voli. Puoi cambiarlo quando vuoi.",
        .obSoundSilence:            "Silenzio",

        .obPlanBuildingTitle:       "Stiamo preparando il tuo piano",
        .obPlanBuildingGoal:        "Alliniamo il tuo obiettivo",
        .obPlanBuildingLength:      "Impostiamo il tuo primo volo",
        .obPlanBuildingAtmosphere:  "Prepariamo Cielo e sonoro",

        .obPlanTitle:               "Il tuo piano di concentrazione",
        .obPlanRowFlight:           "Primo volo",
        .obPlanRowWeekly:           "Obiettivo settimanale",
        .obPlanRowMode:             "Modalità di volo",
        .obPlanRowSky:              "Cielo",
        .obPlanRowSound:            "Sonoro",
        .obPlanRowShield:           "Scudo di concentrazione",
        .obPlanMinutesFormat:       "%d minuti",
        .obPlanDaysFormat:          "%d giorni a settimana",
        .obPlanFlexible:            "Flessibile",
        .obPlanShieldOn:            "Consigliato",
        .obPlanShieldOff:           "Per ora no",
        .obPlanModeSolo:            "Da solo",
        .obPlanModePrivate:         "Con gli amici",
        .obPlanModePublic:          "Online",
        .obPlanRationaleApps:       "Pensato per difenderti meglio dalle app che ti portano via.",
        .obPlanRationaleProcrast:   "Pensato per partire facile nei giorni in cui non ne hai voglia.",
        .obPlanRationaleMomentum:   "Pensato per essere semplice da riprendere.",
        .obPlanRationaleOverwhelm:  "Pensato per sembrare meno, non di più.",
        .obPlanRationaleEnvironment: "Pensato per reggere quando l'ambiente attorno non aiuta.",
        .obPlanRationaleUnsure:     "Pensato su una durata che ti sta bene e che puoi cambiare quando vuoi.",
        .obPlanCTA:                 "Mi piace",
        .obPlanAdjust:              "Modifica",

        .obPreviewTitle:            "Ecco com'è un volo",
        .obPreviewSubtitle:         "La mongolfiera viaggia mentre ti concentri. Questa è solo un'anteprima: non conta ancora nulla.",
        .obPreviewCTA:              "Ho capito",
        .obPreviewSkip:             "Salta l'anteprima",

        .obNotifyTitle:             "Un promemoria nei tuoi giorni di concentrazione",
        .obNotifySubtitle:          "Un promemoria discreto nei giorni che hai scelto. Mai pubblicità, e puoi disattivarlo nelle Impostazioni.",
        .obNotifyCTA:               "Attiva i promemoria",

        .obShieldWarmTitle:         "Blocca le app che distraggono mentre voli",
        .obShieldWarmSubtitle:      "Le app le scegli tu. Restano bloccate solo mentre un volo è in corso, mai in altri momenti.",
        .obShieldWarmCTA:           "Scegli le app da bloccare",

        .obDoneTitle:               "Il tuo piano è pronto",
        .obDoneSubtitle:            "Il tuo primo volo è impostato e ti aspetta.",
        .obDoneCTA:                 "Inizia il primo volo",
        .obDoneSignIn:              "Accedi con Apple",
        .obDoneSignInDetail:        "Facoltativo. Conserva i tuoi progressi se cambi dispositivo.",

        .paywallHeadShield:         "Tieni le app fuori dai tuoi voli",
        .paywallHeadTime:           "Vola per tutto il tempo che serve",
        .paywallHeadOnline:         "Concentrati insieme ad altri piloti",
        .paywallHeadSkies:          "Vola Cieli che raggiungono solo i piloti PRO",
        .paywallHeadSkins:          "Rendi tue la mongolfiera e la Cabina",
        .paywallHeadWidgets:        "La tua serie, a un tocco dalla schermata Home",
        .paywallHeadCoins:          "Guadagna il doppio delle Monete a ogni viaggio",
        .paywallSubhead:            "Il tuo piano funziona tutto senza PRO. Questo toglie solo i limiti.",
        .paywallFreePath:           "Continua senza PRO",

        .benefitShieldTitle:        "Scudo di concentrazione",
        .benefitShieldDetail:       "Blocca le app che ti portano via, per tutta la durata di un volo.",
        .benefitTimeTitle:          "Tempo di concentrazione illimitato",
        .benefitTimeDetail:         "Vola per tutto il tempo che serve.",
        .benefitOnlineTitle:        "Online e Amici",
        .benefitOnlineDetail:       "Concentrati insieme ad altri piloti, o invita i tuoi.",
        .benefitSkiesTitle:         "Cieli esclusivi",
        .benefitSkiesDetail:        "Quattro Cieli che possono volare solo i piloti PRO.",
        .benefitSkinsTitle:         "Livree e oggetti Cabina esclusivi",
        .benefitSkinsDetail:        "Rendi tue la mongolfiera e la Cabina.",
        .benefitWidgetsTitle:       "Widget e Passaporto",
        .benefitWidgetsDetail:      "La tua serie e il prossimo volo, a un tocco dalla schermata Home.",
        .benefitCoinsTitle:         "2× Monete nei viaggi",
        .benefitCoinsDetail:        "Ogni viaggio completato rende il doppio.",

        .paywallRestore:            "Ripristina acquisti",
        .paywallTerms:              "Condizioni d'uso",
        .paywallPrivacy:            "Informativa sulla privacy",
        .paywallBestValue:          "Miglior prezzo",
    ]

    // MARK: - Self-check

    #if DEBUG
    /// The invariants that keep a half-translated language from ever shipping,
    /// and a format string from ever crashing.
    static func _selfCheck() -> String? {
        // 1. English is the source language: it must cover every key.
        for key in FocusStringKey.allCases {
            guard let value = english[key], !value.isEmpty else {
                return "English is missing \(key.rawValue)"
            }
        }
        // 2. No table may contain a key that no longer exists — impossible with
        //    a typed key, but a value must never be blank either, because a
        //    blank string silently renders as nothing rather than falling back.
        for language in AppLanguage.concreteCases {
            for (key, value) in table(for: language) where value.isEmpty {
                return "\(language.endonym) has an empty value for \(key.rawValue)"
            }
        }
        // 3. Placeholders must survive translation. A missing %d turns a
        //    localized format into a crash or a lie about the pilot's plan.
        for language in AppLanguage.concreteCases {
            let table = table(for: language)
            for key in FocusStringKey.allCases where key.placeholderCount > 0 {
                guard let value = table[key] else { continue }
                let found = placeholderTokens(in: value)
                if found != key.placeholderCount {
                    return "\(language.endonym) \(key.rawValue) has \(found) placeholders, expected \(key.placeholderCount)"
                }
            }
            // A translation must never introduce a placeholder the caller does
            // not supply — that is the crash the check above cannot see.
            for key in FocusStringKey.allCases where key.placeholderCount == 0 {
                guard let value = table[key] else { continue }
                if placeholderTokens(in: value) > 0 {
                    return "\(language.endonym) \(key.rawValue) contains an unexpected placeholder"
                }
            }
        }
        // 4. Lookup must never surface a raw key to a pilot.
        for language in AppLanguage.allCases {
            for key in FocusStringKey.allCases where string(key, language: language) == key.rawValue {
                return "lookup returned the raw key for \(key.rawValue) in \(language.endonym)"
            }
        }
        return nil
    }

    /// Counts `%d`, `%@`, `%1$d`, `%.1f`-style tokens, ignoring an escaped `%%`.
    private static func placeholderTokens(in value: String) -> Int {
        /// Positional index, flags, width, precision and length modifiers — all
        /// the characters that may sit between the `%` and the conversion.
        let modifiers = Set("0123456789$.-+#'lhqLzjt")
        let conversions = Set("diouxXeEfgGaAcsSpn@")
        var count = 0
        var cursor = value.startIndex
        while cursor < value.endIndex {
            guard value[cursor] == "%" else {
                cursor = value.index(after: cursor)
                continue
            }
            var scan = value.index(after: cursor)
            guard scan < value.endIndex else { break }
            if value[scan] == "%" {                 // escaped literal percent
                cursor = value.index(after: scan)
                continue
            }
            while scan < value.endIndex, modifiers.contains(value[scan]) {
                scan = value.index(after: scan)
            }
            if scan < value.endIndex, conversions.contains(value[scan]) {
                count += 1
                cursor = value.index(after: scan)
            } else {
                cursor = scan
            }
        }
        return count
    }
    #endif
}
