import Foundation

enum DishCategory: String, Codable, CaseIterable, Identifiable {
    case main
    case soup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: return "Main dish"
        case .soup: return "Soup"
        }
    }
}

struct Dish: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var category: DishCategory
    var hasPhoto: Bool = false
    /// Goes up every time the photo changes, so the app shows the new one.
    var photoVersion: Int = 0
    var createdAt: Date = Date()
    /// Starting dishes come with a built-in photo. True when you removed it.
    var hidesBuiltInPhoto: Bool?
}

enum SwipeChoice: String, Codable {
    case no
    case yes
    case crave

    var isPositive: Bool { self != .no }
}

/// One person's swipes for one day.
struct Round: Codable, Equatable {
    /// Day in "yyyy-MM-dd" form.
    var day: String
    /// This person's own random order of dish ids for the day.
    var order: [String]
    var choices: [String: SwipeChoice] = [:]
    /// Dish ids in the order they were swiped, used for Undo.
    var history: [String] = []
}

struct MatchResult: Identifiable {
    let dish: Dish
    let mine: SwipeChoice
    let partner: SwipeChoice

    var id: String { dish.id }

    /// Both craving ranks highest, then one craving, then both liking.
    var score: Int {
        (mine == .crave ? 2 : 1) + (partner == .crave ? 2 : 1)
    }

    var label: String {
        if mine == .crave && partner == .crave { return "You both crave it" }
        if mine == .crave || partner == .crave { return "One craves it · one likes it" }
        return "You both like it"
    }
}

enum DayKey {
    static func today() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// The starting menu. Fixed ids so they stay the same on both phones later.
enum SeedMenu {
    static let dishes: [Dish] = {
        let items: [(String, DishCategory)] = [
            ("Плов", .main),
            ("Манты Файза", .main),
            ("Манты домашние", .main),
            ("Самсы домашние", .main),
            ("Котлеты с гарниром", .main),
            ("Лагман", .main),
            ("Босо лагман", .main),
            ("Shawarma", .main),
            ("Firefly Burger", .main),
            ("Halal Burger", .main),
            ("Чебурек / Беляш", .main),
            ("Шашлык", .main),
            ("Бешбармак", .main),
            ("Жарма / Аралаш / Максым", .main),
            ("Шорпо", .soup),
            ("Мастава", .soup),
            ("Борщ", .soup),
            ("Пельмени", .soup),
            ("Ramen", .soup),
            ("Pho", .soup)
        ]
        return items.enumerated().map { index, item in
            Dish(
                id: String(format: "seed-%02d", index + 1),
                name: item.0,
                category: item.1,
                createdAt: Date(timeIntervalSince1970: 1_795_000_000 + Double(index))
            )
        }
    }()
}
