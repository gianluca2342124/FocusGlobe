import Foundation

/// The curated, fully-local destination catalog (~120 recognizable places
/// worldwide). Journeys are generated at runtime by `JourneyPlanner` as
/// `currentOrigin → destination`, so distance, duration, category and premium
/// tier are computed from real coordinates — never hardcoded per route.
enum DestinationCatalog {

    static let all: [Destination] = [
        // MARK: Iberia & France
        Destination(id: "barcelona", city: "Barcelona", country: "Spain", lat: 41.3851, lon: 2.1734, code: "BCN", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "madrid", city: "Madrid", country: "Spain", lat: 40.4168, lon: -3.7038, code: "MAD", mood: .city, theme: .gold, landmark: .skyline),
        Destination(id: "seville", city: "Seville", country: "Spain", lat: 37.3891, lon: -5.9845, code: "SVQ", mood: .sunset, theme: .coral, landmark: .dome),
        Destination(id: "valencia", city: "Valencia", country: "Spain", lat: 39.4699, lon: -0.3763, code: "VLC", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "san-sebastian", city: "San Sebastián", country: "Spain", lat: 43.3183, lon: -1.9812, code: "EAS", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "lisbon", city: "Lisbon", country: "Portugal", lat: 38.7223, lon: -9.1393, code: "LIS", mood: .sunset, theme: .blush, landmark: .coastline),
        Destination(id: "porto", city: "Porto", country: "Portugal", lat: 41.1579, lon: -8.6291, code: "OPO", mood: .sunset, theme: .coral, landmark: .bridge),
        Destination(id: "paris", city: "Paris", country: "France", lat: 48.8566, lon: 2.3522, code: "PAR", mood: .city, theme: .lavender, landmark: .tower),
        Destination(id: "nice", city: "Nice", country: "France", lat: 43.7102, lon: 7.2620, code: "NCE", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "lyon", city: "Lyon", country: "France", lat: 45.7640, lon: 4.8357, code: "LYS", mood: .calm, theme: .slate, landmark: .skyline),
        Destination(id: "marseille", city: "Marseille", country: "France", lat: 43.2965, lon: 5.3698, code: "MRS", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "chamonix", city: "Chamonix", country: "France", lat: 45.9237, lon: 6.8694, code: "CMF", mood: .mountains, theme: .slate, landmark: .mountain),

        // MARK: UK, Ireland & Benelux
        Destination(id: "london", city: "London", country: "United Kingdom", lat: 51.5074, lon: -0.1278, code: "LON", mood: .city, theme: .indigo, landmark: .tower),
        Destination(id: "edinburgh", city: "Edinburgh", country: "United Kingdom", lat: 55.9533, lon: -3.1883, code: "EDI", mood: .mountains, theme: .slate, landmark: .skyline),
        Destination(id: "manchester", city: "Manchester", country: "United Kingdom", lat: 53.4808, lon: -2.2426, code: "MAN", mood: .city, theme: .slate, landmark: .skyline),
        Destination(id: "dublin", city: "Dublin", country: "Ireland", lat: 53.3498, lon: -6.2603, code: "DUB", mood: .calm, theme: .mint, landmark: .skyline),
        Destination(id: "amsterdam", city: "Amsterdam", country: "Netherlands", lat: 52.3676, lon: 4.9041, code: "AMS", mood: .calm, theme: .indigo, landmark: .bridge),
        Destination(id: "brussels", city: "Brussels", country: "Belgium", lat: 50.8503, lon: 4.3517, code: "BRU", mood: .city, theme: .slate, landmark: .skyline),

        // MARK: Central Europe & the Alps
        Destination(id: "berlin", city: "Berlin", country: "Germany", lat: 52.5200, lon: 13.4050, code: "BER", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "munich", city: "Munich", country: "Germany", lat: 48.1351, lon: 11.5820, code: "MUC", mood: .mountains, theme: .slate, landmark: .mountain),
        Destination(id: "hamburg", city: "Hamburg", country: "Germany", lat: 53.5511, lon: 9.9937, code: "HAM", mood: .ocean, theme: .teal, landmark: .bridge),
        Destination(id: "frankfurt", city: "Frankfurt", country: "Germany", lat: 50.1109, lon: 8.6821, code: "FRA", mood: .city, theme: .slate, landmark: .skyline),
        Destination(id: "zurich", city: "Zürich", country: "Switzerland", lat: 47.3769, lon: 8.5417, code: "ZRH", mood: .mountains, theme: .mint, landmark: .mountain),
        Destination(id: "zermatt", city: "Zermatt", country: "Switzerland", lat: 46.0207, lon: 7.7491, code: "ZMT", mood: .mountains, theme: .slate, landmark: .mountain),
        Destination(id: "geneva", city: "Geneva", country: "Switzerland", lat: 46.2044, lon: 6.1432, code: "GVA", mood: .mountains, theme: .mint, landmark: .mountain),
        Destination(id: "vienna", city: "Vienna", country: "Austria", lat: 48.2082, lon: 16.3738, code: "VIE", mood: .city, theme: .lavender, landmark: .dome),
        Destination(id: "innsbruck", city: "Innsbruck", country: "Austria", lat: 47.2692, lon: 11.4041, code: "INN", mood: .mountains, theme: .slate, landmark: .mountain),
        Destination(id: "prague", city: "Prague", country: "Czechia", lat: 50.0755, lon: 14.4378, code: "PRG", mood: .city, theme: .lavender, landmark: .tower),
        Destination(id: "budapest", city: "Budapest", country: "Hungary", lat: 47.4979, lon: 19.0402, code: "BUD", mood: .city, theme: .lavender, landmark: .bridge),
        Destination(id: "warsaw", city: "Warsaw", country: "Poland", lat: 52.2297, lon: 21.0122, code: "WAW", mood: .city, theme: .slate, landmark: .skyline),

        // MARK: Italy
        Destination(id: "rome", city: "Rome", country: "Italy", lat: 41.9028, lon: 12.4964, code: "ROM", mood: .sunset, theme: .gold, landmark: .dome),
        Destination(id: "milan", city: "Milan", country: "Italy", lat: 45.4642, lon: 9.1900, code: "MIL", mood: .city, theme: .slate, landmark: .skyline),
        Destination(id: "venice", city: "Venice", country: "Italy", lat: 45.4408, lon: 12.3155, code: "VCE", mood: .sunset, theme: .blush, landmark: .bridge),
        Destination(id: "florence", city: "Florence", country: "Italy", lat: 43.7696, lon: 11.2558, code: "FLR", mood: .sunset, theme: .gold, landmark: .dome),
        Destination(id: "naples", city: "Naples", country: "Italy", lat: 40.8518, lon: 14.2681, code: "NAP", mood: .ocean, theme: .coral, landmark: .coastline),
        Destination(id: "amalfi", city: "Amalfi", country: "Italy", lat: 40.6340, lon: 14.6027, code: "AML", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "lake-como", city: "Lake Como", country: "Italy", lat: 45.9869, lon: 9.2616, code: "COM", mood: .calm, theme: .mint, landmark: .mountain),
        Destination(id: "palermo", city: "Palermo", country: "Italy", lat: 38.1157, lon: 13.3615, code: "PMO", mood: .ocean, theme: .coral, landmark: .coastline),

        // MARK: Nordics & the Aurora belt
        Destination(id: "reykjavik", city: "Reykjavík", country: "Iceland", lat: 64.1466, lon: -21.9426, code: "REK", mood: .aurora, theme: .teal, landmark: .aurora),
        Destination(id: "tromso", city: "Tromsø", country: "Norway", lat: 69.6492, lon: 18.9553, code: "TOS", mood: .aurora, theme: .aurora, landmark: .aurora),
        Destination(id: "bergen", city: "Bergen", country: "Norway", lat: 60.3913, lon: 5.3221, code: "BGO", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "oslo", city: "Oslo", country: "Norway", lat: 59.9139, lon: 10.7522, code: "OSL", mood: .calm, theme: .slate, landmark: .forest),
        Destination(id: "geiranger", city: "Geirangerfjord", country: "Norway", lat: 62.1010, lon: 7.2060, code: "GEI", mood: .mountains, theme: .aurora, landmark: .mountain),
        Destination(id: "stockholm", city: "Stockholm", country: "Sweden", lat: 59.3293, lon: 18.0686, code: "STO", mood: .calm, theme: .indigo, landmark: .bridge),
        Destination(id: "copenhagen", city: "Copenhagen", country: "Denmark", lat: 55.6761, lon: 12.5683, code: "CPH", mood: .calm, theme: .mint, landmark: .bridge),
        Destination(id: "helsinki", city: "Helsinki", country: "Finland", lat: 60.1699, lon: 24.9384, code: "HEL", mood: .aurora, theme: .teal, landmark: .forest),

        // MARK: South-east Europe & Türkiye
        Destination(id: "athens", city: "Athens", country: "Greece", lat: 37.9838, lon: 23.7275, code: "ATH", mood: .sunset, theme: .gold, landmark: .dome),
        Destination(id: "santorini", city: "Santorini", country: "Greece", lat: 36.3932, lon: 25.4615, code: "JTR", mood: .sunset, theme: .blush, landmark: .dome),
        Destination(id: "mykonos", city: "Mykonos", country: "Greece", lat: 37.4467, lon: 25.3289, code: "JMK", mood: .ocean, theme: .teal, landmark: .dome),
        Destination(id: "dubrovnik", city: "Dubrovnik", country: "Croatia", lat: 42.6507, lon: 18.0944, code: "DBV", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "istanbul", city: "Istanbul", country: "Türkiye", lat: 41.0082, lon: 28.9784, code: "IST", mood: .sunset, theme: .gold, landmark: .dome),
        Destination(id: "cappadocia", city: "Cappadocia", country: "Türkiye", lat: 38.6431, lon: 34.8289, code: "NAV", mood: .sunrise, theme: .gold, landmark: .canyon),

        // MARK: North America — East & Central
        Destination(id: "new-york", city: "New York", country: "United States", lat: 40.7128, lon: -74.0060, code: "NYC", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "boston", city: "Boston", country: "United States", lat: 42.3601, lon: -71.0589, code: "BOS", mood: .calm, theme: .slate, landmark: .skyline),
        Destination(id: "washington", city: "Washington, D.C.", country: "United States", lat: 38.9072, lon: -77.0369, code: "WAS", mood: .city, theme: .slate, landmark: .dome),
        Destination(id: "chicago", city: "Chicago", country: "United States", lat: 41.8781, lon: -87.6298, code: "CHI", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "miami", city: "Miami", country: "United States", lat: 25.7617, lon: -80.1918, code: "MIA", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "new-orleans", city: "New Orleans", country: "United States", lat: 29.9511, lon: -90.0715, code: "MSY", mood: .sunset, theme: .gold, landmark: .skyline),
        Destination(id: "toronto", city: "Toronto", country: "Canada", lat: 43.6532, lon: -79.3832, code: "YYZ", mood: .city, theme: .slate, landmark: .skyline),
        Destination(id: "montreal", city: "Montréal", country: "Canada", lat: 45.5017, lon: -73.5673, code: "YUL", mood: .calm, theme: .slate, landmark: .skyline),
        Destination(id: "banff", city: "Banff", country: "Canada", lat: 51.1784, lon: -115.5708, code: "YBA", mood: .mountains, theme: .mint, landmark: .mountain),

        // MARK: North America — West & Mountain
        Destination(id: "san-francisco", city: "San Francisco", country: "United States", lat: 37.7749, lon: -122.4194, code: "SFO", mood: .ocean, theme: .teal, landmark: .bridge),
        Destination(id: "los-angeles", city: "Los Angeles", country: "United States", lat: 34.0522, lon: -118.2437, code: "LAX", mood: .sunset, theme: .coral, landmark: .skyline),
        Destination(id: "san-diego", city: "San Diego", country: "United States", lat: 32.7157, lon: -117.1611, code: "SAN", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "big-sur", city: "Big Sur", country: "United States", lat: 36.2704, lon: -121.8081, code: "BIG", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "las-vegas", city: "Las Vegas", country: "United States", lat: 36.1699, lon: -115.1398, code: "LAS", mood: .night, theme: .lavender, landmark: .desert),
        Destination(id: "seattle", city: "Seattle", country: "United States", lat: 47.6062, lon: -122.3321, code: "SEA", mood: .mountains, theme: .mint, landmark: .mountain),
        Destination(id: "denver", city: "Denver", country: "United States", lat: 39.7392, lon: -104.9903, code: "DEN", mood: .mountains, theme: .slate, landmark: .mountain),
        Destination(id: "grand-canyon", city: "Grand Canyon", country: "United States", lat: 36.1069, lon: -112.1129, code: "GCN", mood: .sunrise, theme: .gold, landmark: .canyon),
        Destination(id: "yosemite", city: "Yosemite", country: "United States", lat: 37.8651, lon: -119.5383, code: "YOS", mood: .mountains, theme: .mint, landmark: .mountain),
        Destination(id: "honolulu", city: "Honolulu", country: "United States", lat: 21.3069, lon: -157.8583, code: "HNL", mood: .ocean, theme: .teal, landmark: .island),

        // MARK: Latin America
        Destination(id: "mexico-city", city: "Mexico City", country: "Mexico", lat: 19.4326, lon: -99.1332, code: "MEX", mood: .city, theme: .gold, landmark: .skyline),
        Destination(id: "cancun", city: "Cancún", country: "Mexico", lat: 21.1619, lon: -86.8515, code: "CUN", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "havana", city: "Havana", country: "Cuba", lat: 23.1136, lon: -82.3666, code: "HAV", mood: .sunset, theme: .coral, landmark: .coastline),
        Destination(id: "cartagena", city: "Cartagena", country: "Colombia", lat: 10.3910, lon: -75.4794, code: "CTG", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "rio", city: "Rio de Janeiro", country: "Brazil", lat: -22.9068, lon: -43.1729, code: "GIG", mood: .ocean, theme: .coral, landmark: .coastline),
        Destination(id: "sao-paulo", city: "São Paulo", country: "Brazil", lat: -23.5505, lon: -46.6333, code: "SAO", mood: .city, theme: .slate, landmark: .skyline),
        Destination(id: "buenos-aires", city: "Buenos Aires", country: "Argentina", lat: -34.6037, lon: -58.3816, code: "BUE", mood: .sunset, theme: .blush, landmark: .skyline),
        Destination(id: "patagonia", city: "Patagonia", country: "Argentina", lat: -49.3314, lon: -72.8864, code: "FTE", mood: .mountains, theme: .slate, landmark: .mountain),
        Destination(id: "santiago", city: "Santiago", country: "Chile", lat: -33.4489, lon: -70.6693, code: "SCL", mood: .mountains, theme: .slate, landmark: .mountain),
        Destination(id: "machu-picchu", city: "Machu Picchu", country: "Peru", lat: -13.1631, lon: -72.5450, code: "CUZ", mood: .mountains, theme: .mint, landmark: .mountain),

        // MARK: Africa & the Middle East
        Destination(id: "marrakech", city: "Marrakech", country: "Morocco", lat: 31.6295, lon: -7.9811, code: "RAK", mood: .sunset, theme: .gold, landmark: .desert),
        Destination(id: "sahara", city: "Sahara", country: "Morocco", lat: 31.0801, lon: -4.0133, code: "SAH", mood: .sunrise, theme: .gold, landmark: .desert),
        Destination(id: "cairo", city: "Cairo", country: "Egypt", lat: 30.0444, lon: 31.2357, code: "CAI", mood: .sunrise, theme: .gold, landmark: .desert),
        Destination(id: "cape-town", city: "Cape Town", country: "South Africa", lat: -33.9249, lon: 18.4241, code: "CPT", mood: .ocean, theme: .teal, landmark: .mountain),
        Destination(id: "zanzibar", city: "Zanzibar", country: "Tanzania", lat: -6.1659, lon: 39.2026, code: "ZNZ", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "nairobi", city: "Nairobi", country: "Kenya", lat: -1.2921, lon: 36.8219, code: "NBO", mood: .sunrise, theme: .gold, landmark: .forest),
        Destination(id: "dubai", city: "Dubai", country: "UAE", lat: 25.2048, lon: 55.2708, code: "DXB", mood: .night, theme: .lavender, landmark: .skyline),
        Destination(id: "petra", city: "Petra", country: "Jordan", lat: 30.3285, lon: 35.4444, code: "PET", mood: .sunrise, theme: .gold, landmark: .canyon),
        Destination(id: "tel-aviv", city: "Tel Aviv", country: "Israel", lat: 32.0853, lon: 34.7818, code: "TLV", mood: .ocean, theme: .teal, landmark: .coastline),

        // MARK: East Asia
        Destination(id: "tokyo", city: "Tokyo", country: "Japan", lat: 35.6762, lon: 139.6503, code: "TYO", mood: .city, theme: .lavender, landmark: .tower),
        Destination(id: "kyoto", city: "Kyoto", country: "Japan", lat: 35.0116, lon: 135.7681, code: "KYO", mood: .sunset, theme: .coral, landmark: .pagoda),
        Destination(id: "osaka", city: "Osaka", country: "Japan", lat: 34.6937, lon: 135.5023, code: "OSA", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "mount-fuji", city: "Mount Fuji", country: "Japan", lat: 35.3606, lon: 138.7274, code: "FUJ", mood: .sunrise, theme: .lavender, landmark: .mountain),
        Destination(id: "sapporo", city: "Sapporo", country: "Japan", lat: 43.0618, lon: 141.3545, code: "SPK", mood: .aurora, theme: .teal, landmark: .forest),
        Destination(id: "seoul", city: "Seoul", country: "South Korea", lat: 37.5665, lon: 126.9780, code: "SEL", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "busan", city: "Busan", country: "South Korea", lat: 35.1796, lon: 129.0756, code: "PUS", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "beijing", city: "Beijing", country: "China", lat: 39.9042, lon: 116.4074, code: "BJS", mood: .city, theme: .gold, landmark: .pagoda),
        Destination(id: "shanghai", city: "Shanghai", country: "China", lat: 31.2304, lon: 121.4737, code: "SHA", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "hong-kong", city: "Hong Kong", country: "China", lat: 22.3193, lon: 114.1694, code: "HKG", mood: .night, theme: .lavender, landmark: .skyline),
        Destination(id: "guilin", city: "Guilin", country: "China", lat: 25.2742, lon: 110.2900, code: "KWL", mood: .calm, theme: .mint, landmark: .mountain),

        // MARK: South & South-east Asia
        Destination(id: "bangkok", city: "Bangkok", country: "Thailand", lat: 13.7563, lon: 100.5018, code: "BKK", mood: .city, theme: .gold, landmark: .pagoda),
        Destination(id: "phuket", city: "Phuket", country: "Thailand", lat: 7.8804, lon: 98.3923, code: "HKT", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "bali", city: "Bali", country: "Indonesia", lat: -8.4095, lon: 115.1889, code: "DPS", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "singapore", city: "Singapore", country: "Singapore", lat: 1.3521, lon: 103.8198, code: "SIN", mood: .city, theme: .indigo, landmark: .skyline),
        Destination(id: "kuala-lumpur", city: "Kuala Lumpur", country: "Malaysia", lat: 3.1390, lon: 101.6869, code: "KUL", mood: .city, theme: .lavender, landmark: .tower),
        Destination(id: "hanoi", city: "Hanoi", country: "Vietnam", lat: 21.0285, lon: 105.8542, code: "HAN", mood: .calm, theme: .mint, landmark: .pagoda),
        Destination(id: "halong-bay", city: "Ha Long Bay", country: "Vietnam", lat: 20.9101, lon: 107.1839, code: "HLB", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "bagan", city: "Bagan", country: "Myanmar", lat: 21.1717, lon: 94.8585, code: "BGN", mood: .sunrise, theme: .gold, landmark: .pagoda),
        Destination(id: "jaipur", city: "Jaipur", country: "India", lat: 26.9124, lon: 75.7873, code: "JAI", mood: .sunset, theme: .gold, landmark: .dome),
        Destination(id: "mumbai", city: "Mumbai", country: "India", lat: 19.0760, lon: 72.8777, code: "BOM", mood: .city, theme: .coral, landmark: .skyline),
        Destination(id: "new-delhi", city: "New Delhi", country: "India", lat: 28.6139, lon: 77.2090, code: "DEL", mood: .sunset, theme: .gold, landmark: .dome),
        Destination(id: "maldives", city: "Maldives", country: "Maldives", lat: 3.2028, lon: 73.2207, code: "MLE", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "kathmandu", city: "Kathmandu", country: "Nepal", lat: 27.7172, lon: 85.3240, code: "KTM", mood: .mountains, theme: .slate, landmark: .mountain),
        Destination(id: "everest", city: "Everest", country: "Nepal", lat: 27.9881, lon: 86.9250, code: "EVR", mood: .mountains, theme: .slate, landmark: .mountain),

        // MARK: Oceania
        Destination(id: "sydney", city: "Sydney", country: "Australia", lat: -33.8688, lon: 151.2093, code: "SYD", mood: .ocean, theme: .teal, landmark: .bridge),
        Destination(id: "melbourne", city: "Melbourne", country: "Australia", lat: -37.8136, lon: 144.9631, code: "MEL", mood: .calm, theme: .slate, landmark: .skyline),
        Destination(id: "queenstown", city: "Queenstown", country: "New Zealand", lat: -45.0312, lon: 168.6626, code: "ZQN", mood: .mountains, theme: .mint, landmark: .mountain),
        Destination(id: "auckland", city: "Auckland", country: "New Zealand", lat: -36.8485, lon: 174.7633, code: "AKL", mood: .ocean, theme: .teal, landmark: .coastline),
        Destination(id: "bora-bora", city: "Bora Bora", country: "French Polynesia", lat: -16.5004, lon: -151.7415, code: "BOB", mood: .ocean, theme: .teal, landmark: .island),
        Destination(id: "fiji", city: "Fiji", country: "Fiji", lat: -17.7765, lon: 177.4356, code: "NAN", mood: .ocean, theme: .teal, landmark: .island),
    ]

    static func destination(id: String) -> Destination? {
        all.first { $0.id == id }
    }
}
