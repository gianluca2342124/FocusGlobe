import Foundation

/// The curated catalog of supported origin hubs and their **real** destinations.
///
/// Better to support fewer cities with real, beautiful routes than many fake
/// ones. Expand over time. Short destinations are real nearby places shown at
/// 30–35 min (free); premium destinations are recognizable farther places.
enum HubCatalog {

    /// Match an arbitrary coordinate to the nearest supported hub within a
    /// reasonable radius. Returns `nil` if none is close enough (→ clean
    /// "preparing journeys" fallback instead of fake places).
    static func nearestHub(to coordinate: GeoCoordinate, maxKm: Double = 150) -> OriginHub? {
        let ranked = all
            .map { ($0, GeoMath.distanceKm(from: coordinate, to: $0.coordinate)) }
            .sorted { $0.1 < $1.1 }
        guard let nearest = ranked.first, nearest.1 <= maxKm else { return nil }
        return nearest.0
    }

    static func hub(id: String) -> OriginHub? { all.first { $0.id == id } }

    // MARK: - Builder

    private static func d(_ name: String, _ code: String, _ lat: Double, _ lon: Double,
                          _ cat: RouteCategory, _ min: Int, _ mood: RouteMood, _ theme: RouteTheme,
                          _ lm: Landmark, _ sub: String) -> JourneyDestination {
        JourneyDestination(name: name, code: code, lat: lat, lon: lon, category: cat,
                           minutes: min, mood: mood, theme: theme, landmark: lm, subtitle: sub)
    }

    // MARK: - Hubs

    static let all: [OriginHub] = [
        barcelona, madrid, paris, london, newYork, losAngeles, tokyo, rome,
        lisbon, amsterdam, berlin, sanFrancisco, dubai, singapore, sydney
    ]

    static let barcelona = OriginHub(
        id: "barcelona", cityName: "Barcelona", countryName: "Spain", latitude: 41.3851, longitude: 2.1734,
        aliases: ["Badalona", "L'Hospitalet", "Sant Adrià", "Cornellà", "Esplugues", "Sabadell"], code: "BCN",
        shortDestinations: [
            d("Castelldefels", "CST", 41.2800, 1.9760, .short, 30, .ocean, .teal, .coastline, "Wide beach south of the city"),
            d("Sitges", "SIT", 41.2371, 1.8055, .short, 30, .ocean, .blush, .coastline, "Whitewashed seaside town"),
            d("Sant Cugat", "SCU", 41.4727, 2.0863, .short, 30, .calm, .mint, .forest, "Leafy hills behind Collserola"),
            d("Mataró", "MAT", 41.5388, 2.4449, .short, 30, .ocean, .teal, .coastline, "Capital of the Maresme coast"),
            d("Sabadell", "SBD", 41.5483, 2.1075, .short, 30, .city, .slate, .skyline, "City in the Vallès valley"),
            d("Terrassa", "TRS", 41.5640, 2.0111, .short, 30, .city, .lavender, .skyline, "Modernista mill town"),
            d("Granollers", "GRN", 41.6083, 2.2876, .short, 30, .calm, .mint, .generic, "Gateway to the Vallès"),
            d("Vilanova i la Geltrú", "VNG", 41.2241, 1.7252, .short, 35, .ocean, .teal, .coastline, "Fishing port and golden sand"),
            d("Montserrat", "MON", 41.5930, 1.8376, .short, 35, .mountains, .slate, .mountain, "Serrated holy mountain"),
            d("Calella", "CAL", 41.6147, 2.6555, .short, 35, .ocean, .coral, .coastline, "Costa del Maresme resort"),
        ],
        premiumDestinations: [
            d("Girona", "GIR", 41.9794, 2.8214, .deep, 50, .sunset, .gold, .dome, "Medieval old town and river houses"),
            d("Tarragona", "TAR", 41.1189, 1.2445, .deep, 55, .ocean, .gold, .coastline, "Roman ruins by the sea"),
            d("Andorra la Vella", "ALV", 42.5063, 1.5218, .deep, 80, .mountains, .slate, .mountain, "Pyrenees mountain capital"),
            d("Valencia", "VLC", 39.4699, -0.3763, .long, 120, .ocean, .coral, .coastline, "City of arts and oranges"),
            d("Marseille", "MRS", 43.2965, 5.3698, .long, 150, .ocean, .teal, .coastline, "France's Mediterranean port"),
            d("Palma de Mallorca", "PMI", 39.5696, 2.6502, .long, 150, .ocean, .teal, .island, "Balearic island capital"),
            d("Rome", "ROM", 41.9028, 12.4964, .ultra, 300, .sunset, .gold, .dome, "The Eternal City"),
            d("Paris", "PAR", 48.8566, 2.3522, .ultra, 300, .city, .lavender, .tower, "City of light"),
            d("Tokyo", "TYO", 35.6762, 139.6503, .ultra, 660, .city, .lavender, .tower, "Neon metropolis"),
        ])

    static let madrid = OriginHub(
        id: "madrid", cityName: "Madrid", countryName: "Spain", latitude: 40.4168, longitude: -3.7038,
        aliases: ["Móstoles", "Alcalá de Henares", "Getafe", "Leganés", "Fuenlabrada"], code: "MAD",
        shortDestinations: [
            d("Toledo", "TOL", 39.8628, -4.0273, .short, 30, .sunset, .gold, .dome, "Imperial city on the Tagus"),
            d("Segovia", "SEG", 40.9429, -4.1088, .short, 35, .mountains, .slate, .canyon, "Roman aqueduct and Alcázar"),
            d("El Escorial", "ESC", 40.5894, -4.1488, .short, 30, .mountains, .slate, .mountain, "Royal monastery in the sierra"),
            d("Aranjuez", "ARJ", 40.0312, -3.6028, .short, 30, .calm, .mint, .forest, "Royal gardens by the river"),
            d("Alcalá de Henares", "ALC", 40.4818, -3.3645, .short, 30, .sunset, .gold, .skyline, "Cervantes' university town"),
            d("Ávila", "AVL", 40.6566, -4.6818, .short, 35, .mountains, .slate, .canyon, "Walled medieval city"),
            d("Chinchón", "CHN", 40.1396, -3.4225, .short, 30, .sunset, .coral, .skyline, "Arcaded plaza and vineyards"),
            d("Manzanares el Real", "MZN", 40.7269, -3.8620, .short, 30, .mountains, .mint, .mountain, "Castle below La Pedriza"),
        ],
        premiumDestinations: [
            d("Cuenca", "CUE", 40.0704, -2.1374, .deep, 50, .sunset, .gold, .canyon, "Hanging houses over the gorge"),
            d("Salamanca", "SAL", 40.9701, -5.6635, .deep, 70, .sunset, .gold, .dome, "Golden sandstone university"),
            d("Valencia", "VLC", 39.4699, -0.3763, .long, 120, .ocean, .coral, .coastline, "City of arts and oranges"),
            d("Barcelona", "BCN", 41.3851, 2.1734, .long, 150, .city, .indigo, .skyline, "Gaudí's Mediterranean capital"),
            d("Lisbon", "LIS", 38.7223, -9.1393, .long, 180, .sunset, .blush, .coastline, "Hills above the Tagus"),
            d("Paris", "PAR", 48.8566, 2.3522, .ultra, 300, .city, .lavender, .tower, "City of light"),
        ])

    static let paris = OriginHub(
        id: "paris", cityName: "Paris", countryName: "France", latitude: 48.8566, longitude: 2.3522,
        aliases: ["Boulogne", "Saint-Denis", "Versailles", "Nanterre", "Créteil"], code: "PAR",
        shortDestinations: [
            d("Versailles", "VRS", 48.8049, 2.1204, .short, 30, .sunset, .gold, .dome, "Palace and royal gardens"),
            d("Fontainebleau", "FON", 48.4020, 2.7019, .short, 35, .calm, .mint, .forest, "Château in the great forest"),
            d("Chantilly", "CTL", 49.1939, 2.4699, .short, 30, .calm, .mint, .forest, "Château and lace town"),
            d("Giverny", "GIV", 49.0758, 1.5333, .short, 35, .calm, .blush, .forest, "Monet's water gardens"),
            d("Provins", "PRV", 48.5602, 3.2999, .short, 35, .sunset, .gold, .skyline, "Medieval fair town"),
            d("Auvers-sur-Oise", "AUV", 49.0703, 2.1700, .short, 30, .sunset, .coral, .forest, "Van Gogh's last village"),
            d("Rambouillet", "RMB", 48.6443, 1.8307, .short, 30, .calm, .mint, .forest, "Royal forest retreat"),
            d("Senlis", "SNL", 49.2069, 2.5869, .short, 30, .sunset, .gold, .skyline, "Gothic medieval town"),
        ],
        premiumDestinations: [
            d("Reims", "RMS", 49.2583, 4.0317, .deep, 50, .sunset, .gold, .dome, "Cathedral and champagne"),
            d("Rouen", "ROU", 49.4432, 1.0993, .deep, 55, .sunset, .blush, .dome, "Normandy's old quarter"),
            d("Mont-Saint-Michel", "MSM", 48.6361, -1.5115, .deep, 90, .ocean, .slate, .island, "Abbey island in the bay"),
            d("Lyon", "LYO", 45.7640, 4.8357, .long, 120, .calm, .slate, .skyline, "Rivers and old town"),
            d("Nice", "NCE", 43.7102, 7.2620, .long, 180, .ocean, .teal, .coastline, "Riviera promenade"),
            d("Barcelona", "BCN", 41.3851, 2.1734, .ultra, 300, .city, .indigo, .skyline, "Gaudí's capital"),
        ])

    static let london = OriginHub(
        id: "london", cityName: "London", countryName: "United Kingdom", latitude: 51.5074, longitude: -0.1278,
        aliases: ["Croydon", "Watford", "Richmond", "Kingston", "Bromley"], code: "LON",
        shortDestinations: [
            d("Oxford", "OXF", 51.7520, -1.2577, .short, 35, .sunset, .gold, .dome, "City of dreaming spires"),
            d("Cambridge", "CAM", 52.2053, 0.1218, .short, 35, .calm, .mint, .dome, "Colleges on the Cam"),
            d("Brighton", "BTN", 50.8225, -0.1372, .short, 35, .ocean, .teal, .coastline, "Seafront and the pier"),
            d("Windsor", "WND", 51.4791, -0.6095, .short, 30, .sunset, .gold, .dome, "Castle on the Thames"),
            d("Canterbury", "CTB", 51.2802, 1.0789, .short, 35, .sunset, .gold, .dome, "Cathedral pilgrim city"),
            d("St Albans", "STA", 51.7550, -0.3360, .short, 30, .calm, .mint, .skyline, "Roman city and abbey"),
            d("Whitstable", "WHT", 51.3600, 1.0257, .short, 35, .ocean, .teal, .coastline, "Oyster harbour town"),
            d("Cotswolds", "CTW", 51.8330, -1.8433, .short, 35, .calm, .mint, .forest, "Honey-stone villages"),
        ],
        premiumDestinations: [
            d("Bath", "BTH", 51.3811, -2.3590, .deep, 50, .sunset, .gold, .dome, "Georgian spa city"),
            d("Stonehenge", "STH", 51.1789, -1.8262, .deep, 55, .mountains, .slate, .generic, "Ancient stone circle"),
            d("York", "YRK", 53.9600, -1.0873, .deep, 75, .sunset, .gold, .skyline, "Walled minster city"),
            d("Edinburgh", "EDI", 55.9533, -3.1883, .long, 150, .mountains, .slate, .skyline, "Castle on the crag"),
            d("Paris", "PAR", 48.8566, 2.3522, .long, 180, .city, .lavender, .tower, "Across the Channel"),
            d("New York", "NYC", 40.7128, -74.0060, .ultra, 480, .city, .indigo, .skyline, "The city that never sleeps"),
        ])

    static let newYork = OriginHub(
        id: "new-york", cityName: "New York", countryName: "United States", latitude: 40.7128, longitude: -74.0060,
        aliases: ["Brooklyn", "Newark", "Jersey City", "Queens", "Bronx", "Hoboken"], code: "NYC",
        shortDestinations: [
            d("The Hamptons", "HAM", 40.9634, -72.1848, .short, 35, .ocean, .teal, .coastline, "Long Island dunes"),
            d("Hudson Valley", "HUD", 41.7004, -73.9210, .short, 35, .mountains, .mint, .forest, "River and autumn colour"),
            d("Princeton", "PRN", 40.3573, -74.6672, .short, 30, .calm, .mint, .dome, "Ivy campus town"),
            d("Bear Mountain", "BMT", 41.3126, -73.9887, .short, 30, .mountains, .slate, .mountain, "Hudson Highlands"),
            d("Greenwich", "GRW", 41.0262, -73.6282, .short, 30, .calm, .slate, .coastline, "Connecticut shoreline"),
            d("Montauk", "MTK", 41.0359, -71.9545, .short, 35, .ocean, .teal, .coastline, "Lighthouse at the end"),
            d("New Haven", "NHV", 41.3083, -72.9279, .short, 35, .calm, .slate, .skyline, "Yale's green city"),
            d("Storm King", "STK", 41.4249, -74.0560, .short, 30, .calm, .mint, .generic, "Sculpture in the hills"),
        ],
        premiumDestinations: [
            d("Philadelphia", "PHL", 39.9526, -75.1652, .deep, 50, .city, .slate, .skyline, "Liberty's city"),
            d("Boston", "BOS", 42.3601, -71.0589, .deep, 70, .calm, .slate, .skyline, "Harbor and history"),
            d("Washington", "WAS", 38.9072, -77.0369, .deep, 80, .city, .slate, .dome, "The capital mall"),
            d("Chicago", "CHI", 41.8781, -87.6298, .long, 150, .city, .indigo, .skyline, "City by the lake"),
            d("Miami", "MIA", 25.7617, -80.1918, .long, 180, .ocean, .teal, .island, "Art-deco beaches"),
            d("London", "LON", 51.5074, -0.1278, .ultra, 480, .city, .indigo, .tower, "Across the Atlantic"),
        ])

    static let losAngeles = OriginHub(
        id: "los-angeles", cityName: "Los Angeles", countryName: "United States", latitude: 34.0522, longitude: -118.2437,
        aliases: ["Hollywood", "Pasadena", "Long Beach", "Santa Monica", "Anaheim", "Burbank"], code: "LAX",
        shortDestinations: [
            d("Santa Monica", "SMO", 34.0195, -118.4912, .short, 30, .ocean, .teal, .coastline, "Pier and the bay"),
            d("Malibu", "MAL", 34.0259, -118.7798, .short, 35, .ocean, .teal, .coastline, "Surf and the cliffs"),
            d("Pasadena", "PAS", 34.1478, -118.1445, .short, 30, .sunset, .gold, .dome, "Rose-city foothills"),
            d("Laguna Beach", "LAG", 33.5427, -117.7854, .short, 35, .ocean, .blush, .coastline, "Coves and art"),
            d("Big Bear", "BBR", 34.2439, -116.9114, .short, 35, .mountains, .slate, .mountain, "Alpine lake getaway"),
            d("Ojai", "OJA", 34.4480, -119.2429, .short, 35, .sunset, .coral, .mountain, "Valley of the pink moment"),
            d("Palm Springs", "PSP", 33.8303, -116.5453, .short, 35, .sunset, .gold, .desert, "Desert oasis modernism"),
            d("Catalina Island", "CAT", 33.3879, -118.4163, .short, 35, .ocean, .teal, .island, "Harbor across the channel"),
        ],
        premiumDestinations: [
            d("San Diego", "SAN", 32.7157, -117.1611, .deep, 50, .ocean, .teal, .coastline, "Bayfront and beaches"),
            d("Santa Barbara", "SBA", 34.4208, -119.6982, .deep, 45, .ocean, .blush, .coastline, "The American Riviera"),
            d("Big Sur", "BIG", 36.2704, -121.8081, .long, 120, .ocean, .teal, .coastline, "Cliffs above the Pacific"),
            d("San Francisco", "SFO", 37.7749, -122.4194, .long, 150, .ocean, .teal, .bridge, "Fog and the bay"),
            d("Las Vegas", "LAS", 36.1699, -115.1398, .long, 120, .night, .lavender, .desert, "Neon in the desert"),
            d("Tokyo", "TYO", 35.6762, 139.6503, .ultra, 600, .city, .lavender, .tower, "Across the Pacific"),
        ])

    static let tokyo = OriginHub(
        id: "tokyo", cityName: "Tokyo", countryName: "Japan", latitude: 35.6762, longitude: 139.6503,
        aliases: ["Yokohama", "Kawasaki", "Chiba", "Saitama", "Shibuya", "Shinjuku"], code: "TYO",
        shortDestinations: [
            d("Kamakura", "KMK", 35.3192, 139.5466, .short, 30, .ocean, .teal, .pagoda, "Great Buddha by the sea"),
            d("Hakone", "HKN", 35.2324, 139.1069, .short, 35, .mountains, .lavender, .mountain, "Hot springs under Fuji"),
            d("Nikko", "NKK", 36.7199, 139.6982, .short, 35, .mountains, .slate, .pagoda, "Shrines in cedar forest"),
            d("Yokohama", "YOK", 35.4437, 139.6380, .short, 30, .city, .indigo, .bridge, "Bayside minato"),
            d("Enoshima", "ENO", 35.2990, 139.4803, .short, 30, .ocean, .teal, .island, "Shrine island and caves"),
            d("Kawagoe", "KWG", 35.9251, 139.4858, .short, 30, .sunset, .gold, .pagoda, "Little Edo warehouses"),
            d("Mount Takao", "TKO", 35.6253, 139.2436, .short, 30, .mountains, .mint, .mountain, "Forest peak by the city"),
            d("Chichibu", "CCB", 35.9919, 139.0856, .short, 35, .mountains, .mint, .mountain, "Valley shrines and festivals"),
        ],
        premiumDestinations: [
            d("Kyoto", "KYO", 35.0116, 135.7681, .deep, 90, .sunset, .coral, .pagoda, "Temples and lantern lanes"),
            d("Mount Fuji", "FUJ", 35.3606, 138.7274, .deep, 60, .sunrise, .lavender, .mountain, "Japan's sacred peak"),
            d("Osaka", "OSA", 34.6937, 135.5023, .long, 120, .city, .indigo, .skyline, "Neon and street food"),
            d("Sapporo", "SPK", 43.0618, 141.3545, .long, 180, .aurora, .teal, .forest, "Snow city of the north"),
            d("Seoul", "SEL", 37.5665, 126.9780, .long, 180, .city, .indigo, .skyline, "Across the strait"),
            d("San Francisco", "SFO", 37.7749, -122.4194, .ultra, 600, .ocean, .teal, .bridge, "Across the Pacific"),
        ])

    static let rome = OriginHub(
        id: "rome", cityName: "Rome", countryName: "Italy", latitude: 41.9028, longitude: 12.4964,
        aliases: ["Vatican City", "Ostia", "Tivoli", "Fiumicino"], code: "ROM",
        shortDestinations: [
            d("Tivoli", "TVL", 41.9633, 12.7980, .short, 30, .sunset, .gold, .forest, "Villa gardens and fountains"),
            d("Ostia Antica", "OST", 41.7559, 12.2920, .short, 30, .sunset, .gold, .coastline, "Ancient port ruins"),
            d("Castel Gandolfo", "CGD", 41.7472, 12.6517, .short, 30, .calm, .teal, .coastline, "Papal town on the lake"),
            d("Bracciano", "BRC", 42.1037, 12.1745, .short, 35, .calm, .teal, .coastline, "Castle by the lake"),
            d("Frascati", "FRS", 41.8089, 12.6798, .short, 30, .sunset, .coral, .forest, "Hilltop wine town"),
            d("Sperlonga", "SPL", 41.2640, 13.4307, .short, 35, .ocean, .teal, .coastline, "Whitewashed cliff beach"),
            d("Viterbo", "VIT", 42.4207, 12.1077, .short, 35, .sunset, .gold, .skyline, "Medieval papal city"),
            d("Orvieto", "ORV", 42.7185, 12.1107, .short, 35, .sunset, .gold, .dome, "Cathedral on the tufa cliff"),
        ],
        premiumDestinations: [
            d("Florence", "FLR", 43.7696, 11.2558, .deep, 60, .sunset, .gold, .dome, "Renaissance city"),
            d("Naples", "NAP", 40.8518, 14.2681, .deep, 50, .ocean, .coral, .coastline, "Bay and Vesuvius"),
            d("Amalfi", "AML", 40.6340, 14.6027, .deep, 75, .ocean, .teal, .coastline, "Cliffside coast road"),
            d("Venice", "VCE", 45.4408, 12.3155, .long, 120, .sunset, .blush, .bridge, "Canals and lagoon"),
            d("Barcelona", "BCN", 41.3851, 2.1734, .long, 180, .city, .indigo, .skyline, "Across the sea"),
            d("Paris", "PAR", 48.8566, 2.3522, .ultra, 300, .city, .lavender, .tower, "City of light"),
        ])

    static let lisbon = OriginHub(
        id: "lisbon", cityName: "Lisbon", countryName: "Portugal", latitude: 38.7223, longitude: -9.1393,
        aliases: ["Sintra", "Cascais", "Almada", "Oeiras"], code: "LIS",
        shortDestinations: [
            d("Sintra", "SNT", 38.7980, -9.3878, .short, 30, .calm, .mint, .forest, "Palaces in misty hills"),
            d("Cascais", "CSC", 38.6979, -9.4215, .short, 30, .ocean, .teal, .coastline, "Bay and old fort"),
            d("Setúbal", "STB", 38.5244, -8.8882, .short, 35, .ocean, .teal, .coastline, "Sado estuary port"),
            d("Óbidos", "OBD", 39.3606, -9.1572, .short, 35, .sunset, .gold, .skyline, "Walled village in white"),
            d("Ericeira", "ERC", 38.9634, -9.4158, .short, 35, .ocean, .teal, .coastline, "Surf-town cliffs"),
            d("Évora", "EVR", 38.5713, -7.9135, .short, 35, .sunset, .gold, .dome, "Roman temple and old town"),
            d("Arrábida", "ARB", 38.4836, -8.9810, .short, 35, .ocean, .mint, .mountain, "Green cliffs over turquoise"),
            d("Mafra", "MFR", 38.9377, -9.3268, .short, 30, .sunset, .gold, .dome, "Vast baroque palace"),
        ],
        premiumDestinations: [
            d("Porto", "OPO", 41.1579, -8.6291, .deep, 70, .sunset, .coral, .bridge, "Port wine and the Douro"),
            d("Algarve", "FAO", 37.0194, -7.9304, .deep, 90, .ocean, .teal, .coastline, "The golden southern coast"),
            d("Madrid", "MAD", 40.4168, -3.7038, .long, 150, .city, .gold, .skyline, "Spain's capital"),
            d("Barcelona", "BCN", 41.3851, 2.1734, .long, 180, .city, .indigo, .skyline, "Mediterranean Gaudí"),
            d("Paris", "PAR", 48.8566, 2.3522, .ultra, 300, .city, .lavender, .tower, "City of light"),
        ])

    static let amsterdam = OriginHub(
        id: "amsterdam", cityName: "Amsterdam", countryName: "Netherlands", latitude: 52.3676, longitude: 4.9041,
        aliases: ["Haarlem", "Utrecht", "Zaandam", "Amstelveen"], code: "AMS",
        shortDestinations: [
            d("Haarlem", "HRL", 52.3874, 4.6462, .short, 30, .calm, .indigo, .bridge, "Golden-age canal town"),
            d("Utrecht", "UTR", 52.0907, 5.1214, .short, 30, .calm, .mint, .bridge, "Canals below the Dom"),
            d("Zaanse Schans", "ZAA", 52.4742, 4.8170, .short, 30, .calm, .mint, .generic, "Working windmills"),
            d("Keukenhof", "KEU", 52.2697, 4.5469, .short, 30, .calm, .blush, .forest, "Endless tulip gardens"),
            d("Leiden", "LEI", 52.1601, 4.4970, .short, 30, .calm, .indigo, .bridge, "Rembrandt's canal city"),
            d("Marken", "MRK", 52.4583, 5.1058, .short, 30, .ocean, .teal, .coastline, "Village on the IJsselmeer"),
            d("Giethoorn", "GTH", 52.7386, 6.0780, .short, 35, .calm, .mint, .forest, "Village of canals, no roads"),
            d("The Hague", "HAG", 52.0705, 4.3007, .short, 30, .ocean, .slate, .coastline, "Seat of government by the sea"),
        ],
        premiumDestinations: [
            d("Rotterdam", "RTM", 51.9244, 4.4777, .deep, 45, .city, .slate, .skyline, "Modern port skyline"),
            d("Bruges", "BRU", 51.2093, 3.2247, .deep, 60, .sunset, .gold, .bridge, "Medieval Belgian canals"),
            d("Paris", "PAR", 48.8566, 2.3522, .long, 150, .city, .lavender, .tower, "City of light"),
            d("Berlin", "BER", 52.5200, 13.4050, .long, 150, .city, .indigo, .skyline, "Reunited capital"),
            d("London", "LON", 51.5074, -0.1278, .long, 180, .city, .indigo, .tower, "Across the North Sea"),
        ])

    static let berlin = OriginHub(
        id: "berlin", cityName: "Berlin", countryName: "Germany", latitude: 52.5200, longitude: 13.4050,
        aliases: ["Potsdam", "Charlottenburg", "Spandau"], code: "BER",
        shortDestinations: [
            d("Potsdam", "POT", 52.3906, 13.0645, .short, 30, .sunset, .gold, .dome, "Sanssouci's palaces"),
            d("Spreewald", "SPW", 51.8667, 14.0333, .short, 35, .calm, .mint, .forest, "Canals through the forest"),
            d("Wannsee", "WSE", 52.4206, 13.1639, .short, 30, .calm, .teal, .coastline, "Lakeside beach day"),
            d("Rheinsberg", "RHB", 53.0975, 12.8939, .short, 35, .calm, .mint, .coastline, "Castle by the lake"),
            d("Brandenburg", "BRB", 52.4117, 12.5316, .short, 30, .calm, .mint, .forest, "Havel river towns"),
            d("Wittenberg", "WTB", 51.8667, 12.6500, .short, 35, .sunset, .gold, .skyline, "Luther's reformation town"),
            d("Bad Saarow", "BSW", 52.2856, 14.0639, .short, 30, .calm, .teal, .coastline, "Spa on the Scharmützelsee"),
            d("Buckow", "BCK", 52.5600, 14.0683, .short, 30, .calm, .mint, .forest, "Märkische Schweiz hills"),
        ],
        premiumDestinations: [
            d("Dresden", "DRS", 51.0504, 13.7373, .deep, 60, .sunset, .gold, .dome, "Baroque on the Elbe"),
            d("Leipzig", "LEJ", 51.3397, 12.3731, .deep, 45, .city, .slate, .skyline, "Music and markets"),
            d("Prague", "PRG", 50.0755, 14.4378, .deep, 75, .sunset, .lavender, .tower, "City of a hundred spires"),
            d("Hamburg", "HAM", 53.5511, 9.9937, .long, 120, .ocean, .teal, .bridge, "Harbour city"),
            d("Munich", "MUC", 48.1351, 11.5820, .long, 150, .mountains, .slate, .mountain, "Gateway to the Alps"),
            d("Paris", "PAR", 48.8566, 2.3522, .ultra, 300, .city, .lavender, .tower, "City of light"),
        ])

    static let sanFrancisco = OriginHub(
        id: "san-francisco", cityName: "San Francisco", countryName: "United States", latitude: 37.7749, longitude: -122.4194,
        aliases: ["Oakland", "Berkeley", "San Jose", "Marin", "Palo Alto"], code: "SFO",
        shortDestinations: [
            d("Sausalito", "SAU", 37.8591, -122.4853, .short, 30, .ocean, .teal, .bridge, "Bayside houseboats"),
            d("Napa Valley", "NPA", 38.5025, -122.2654, .short, 35, .sunset, .blush, .forest, "Vineyard hills"),
            d("Muir Woods", "MUI", 37.8927, -122.5719, .short, 30, .calm, .mint, .forest, "Ancient redwoods"),
            d("Half Moon Bay", "HMB", 37.4636, -122.4286, .short, 30, .ocean, .teal, .coastline, "Foggy surf coast"),
            d("Berkeley", "BRK", 37.8715, -122.2730, .short, 30, .calm, .slate, .skyline, "Hills and the campus"),
            d("Santa Cruz", "SCZ", 36.9741, -122.0308, .short, 35, .ocean, .teal, .coastline, "Boardwalk and surf"),
            d("Point Reyes", "PTR", 38.0700, -122.8067, .short, 35, .ocean, .slate, .coastline, "Windswept peninsula"),
            d("Sonoma", "SON", 38.2919, -122.4580, .short, 35, .sunset, .coral, .forest, "Wine-country plaza"),
        ],
        premiumDestinations: [
            d("Yosemite", "YOS", 37.8651, -119.5383, .deep, 90, .mountains, .mint, .mountain, "Granite valley"),
            d("Lake Tahoe", "TVL", 39.0968, -120.0324, .deep, 75, .mountains, .teal, .mountain, "Alpine blue lake"),
            d("Big Sur", "BIG", 36.2704, -121.8081, .deep, 60, .ocean, .teal, .coastline, "Cliffs above the Pacific"),
            d("Los Angeles", "LAX", 34.0522, -118.2437, .long, 150, .sunset, .coral, .skyline, "City of angels"),
            d("Las Vegas", "LAS", 36.1699, -115.1398, .long, 150, .night, .lavender, .desert, "Desert neon"),
            d("Tokyo", "TYO", 35.6762, 139.6503, .ultra, 600, .city, .lavender, .tower, "Across the Pacific"),
        ])

    static let dubai = OriginHub(
        id: "dubai", cityName: "Dubai", countryName: "United Arab Emirates", latitude: 25.2048, longitude: 55.2708,
        aliases: ["Sharjah", "Abu Dhabi", "Ajman", "Deira"], code: "DXB",
        shortDestinations: [
            d("Abu Dhabi", "AUH", 24.4539, 54.3773, .short, 35, .sunset, .gold, .dome, "Grand-mosque capital"),
            d("Hatta", "HAT", 24.8000, 56.1167, .short, 35, .mountains, .slate, .mountain, "Mountain dam and pools"),
            d("Sharjah", "SHJ", 25.3463, 55.4209, .short, 30, .sunset, .gold, .dome, "Arts and heritage emirate"),
            d("Al Ain", "AAN", 24.1917, 55.7606, .short, 35, .sunrise, .gold, .desert, "Oasis and palm groves"),
            d("Liwa Desert", "LIW", 23.1300, 53.7800, .short, 35, .sunrise, .gold, .desert, "Empty-Quarter dunes"),
            d("Fujairah", "FJR", 25.1288, 56.3265, .short, 35, .ocean, .teal, .coastline, "Gulf of Oman coast"),
            d("Ras Al Khaimah", "RKT", 25.7895, 55.9432, .short, 35, .mountains, .slate, .mountain, "Jebel Jais peaks"),
            d("Palm Jumeirah", "PLM", 25.1124, 55.1390, .short, 30, .ocean, .teal, .island, "Island of villas"),
        ],
        premiumDestinations: [
            d("Muscat", "MCT", 23.5880, 58.3829, .deep, 90, .ocean, .teal, .coastline, "Omani corniche"),
            d("Doha", "DOH", 25.2854, 51.5310, .deep, 75, .city, .lavender, .skyline, "Gulf skyline"),
            d("Cairo", "CAI", 30.0444, 31.2357, .long, 180, .sunrise, .gold, .desert, "Pyramids on the Nile"),
            d("Mumbai", "BOM", 19.0760, 72.8777, .long, 180, .city, .coral, .skyline, "City by the Arabian Sea"),
            d("Istanbul", "IST", 41.0082, 28.9784, .ultra, 300, .sunset, .gold, .dome, "Where two continents meet"),
        ])

    static let singapore = OriginHub(
        id: "singapore", cityName: "Singapore", countryName: "Singapore", latitude: 1.3521, longitude: 103.8198,
        aliases: ["Johor Bahru", "Sentosa", "Jurong"], code: "SIN",
        shortDestinations: [
            d("Sentosa", "STS", 1.2494, 103.8303, .short, 30, .ocean, .teal, .island, "Resort-island beaches"),
            d("Pulau Ubin", "UBN", 1.4043, 103.9636, .short, 30, .calm, .mint, .forest, "Kampong on the wild isle"),
            d("Johor Bahru", "JHB", 1.4927, 103.7414, .short, 30, .city, .slate, .skyline, "Across the causeway"),
            d("Batam", "BTM", 1.0456, 104.0305, .short, 35, .ocean, .teal, .island, "Indonesian island escape"),
            d("Bintan", "BTN", 1.0667, 104.4167, .short, 35, .ocean, .teal, .island, "White-sand resort isle"),
            d("Desaru", "DSR", 1.5800, 104.2600, .short, 35, .ocean, .teal, .coastline, "Malaysian beach coast"),
            d("Kukup", "KKP", 1.3261, 103.4392, .short, 35, .ocean, .teal, .island, "Fishing village on stilts"),
            d("Malacca", "MLC", 2.1896, 102.2501, .short, 35, .sunset, .gold, .skyline, "Historic strait city"),
        ],
        premiumDestinations: [
            d("Kuala Lumpur", "KUL", 3.1390, 101.6869, .deep, 75, .city, .lavender, .tower, "Twin-tower capital"),
            d("Bali", "DPS", -8.4095, 115.1889, .long, 150, .ocean, .teal, .island, "Island of temples"),
            d("Bangkok", "BKK", 13.7563, 100.5018, .long, 150, .city, .gold, .pagoda, "City of golden temples"),
            d("Hong Kong", "HKG", 22.3193, 114.1694, .long, 180, .night, .lavender, .skyline, "Harbour of lights"),
            d("Tokyo", "TYO", 35.6762, 139.6503, .ultra, 360, .city, .lavender, .tower, "Neon metropolis"),
        ])

    static let sydney = OriginHub(
        id: "sydney", cityName: "Sydney", countryName: "Australia", latitude: -33.8688, longitude: 151.2093,
        aliases: ["Parramatta", "Newcastle", "Wollongong", "Bondi"], code: "SYD",
        shortDestinations: [
            d("Blue Mountains", "BLU", -33.7000, 150.3000, .short, 35, .mountains, .slate, .mountain, "Three Sisters and gum valleys"),
            d("Bondi", "BND", -33.8915, 151.2767, .short, 30, .ocean, .teal, .coastline, "Iconic surf beach"),
            d("Manly", "MNL", -33.7969, 151.2870, .short, 30, .ocean, .teal, .coastline, "Ferry beach town"),
            d("Palm Beach", "PMB", -33.5994, 151.3225, .short, 35, .ocean, .teal, .coastline, "Northern peninsula sands"),
            d("Hunter Valley", "HUN", -32.7000, 151.1667, .short, 35, .sunset, .blush, .forest, "Vineyards north of the city"),
            d("Wollongong", "WOL", -34.4278, 150.8931, .short, 35, .ocean, .teal, .coastline, "Sea cliffs and lighthouses"),
            d("Royal National Park", "RNP", -34.1333, 151.0500, .short, 30, .calm, .mint, .forest, "Coastal bush trails"),
            d("Jervis Bay", "JRV", -35.0667, 150.7000, .short, 35, .ocean, .teal, .coastline, "Whitest sand and dolphins"),
        ],
        premiumDestinations: [
            d("Canberra", "CBR", -35.2809, 149.1300, .deep, 60, .calm, .slate, .skyline, "The bush capital"),
            d("Byron Bay", "BYR", -28.6474, 153.6020, .deep, 90, .ocean, .teal, .coastline, "Lighthouse and surf"),
            d("Melbourne", "MEL", -37.8136, 144.9631, .long, 120, .calm, .slate, .skyline, "Laneways and coffee"),
            d("Queenstown", "ZQN", -45.0312, 168.6626, .long, 180, .mountains, .mint, .mountain, "Alpine adventure town"),
            d("Bali", "DPS", -8.4095, 115.1889, .ultra, 360, .ocean, .teal, .island, "Island of temples"),
        ])
}
