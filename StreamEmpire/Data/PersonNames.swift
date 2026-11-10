import Foundation

/// Fictional employee names: random first + last combinations.
enum PersonNames {
    private static let first = [
        "Maya", "Leo", "Priya", "Jonas", "Amara", "Diego", "Hana", "Kofi", "Sofia", "Omar",
        "Ingrid", "Rafael", "Mei", "Tariq", "Elena", "Yusuf", "Chloe", "Arjun", "Nia", "Mateo",
        "Freya", "Kenji", "Zara", "Lucas", "Aisha", "Pavel", "Lena", "Tomas", "Imani", "Noah",
        "Valentina", "Sami", "Greta", "Ravi", "Camila", "Felix", "Yara", "Hugo", "Keiko", "Ethan",
    ]
    private static let last = [
        "Okafor", "Lindqvist", "Moreau", "Tanaka", "Silva", "Kowalski", "Haddad", "Novak", "Reyes", "Chen",
        "Abara", "Fischer", "Rossi", "Mensah", "Patel", "Larsen", "Duarte", "Kim", "Osei", "Varga",
        "Sato", "Brennan", "Amini", "Costa", "Nakamura", "Dubois", "Petrov", "Alvarez", "Nyberg", "Kariuki",
        "Hughes", "Yilmaz", "Morales", "Akhtar", "Weber", "Santos", "Ibrahim", "Laurent", "Quinn", "Hale",
    ]

    static func make(rng: inout SeededRNG, avoiding: Set<String> = []) -> String {
        for _ in 0..<20 {
            let name = "\(rng.pick(first)) \(rng.pick(last))"
            if !avoiding.contains(name) { return name }
        }
        return "\(rng.pick(first)) \(rng.pick(last))"
    }
}
