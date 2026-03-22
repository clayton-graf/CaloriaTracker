import UIKit
import Foundation

extension Notification.Name {
    static let appStoreDidChange = Notification.Name("appStoreDidChange")
}

enum FoodMeasure: String, CaseIterable, Codable {
    case weight100g = "100g"
    case unit = "Unidade"
}

struct FoodItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var measure: FoodMeasure
    var calories: Double
    var proteins: Double
    var fats: Double
    var carbs: Double

    init(
        id: UUID = UUID(),
        name: String,
        measure: FoodMeasure,
        calories: Double,
        proteins: Double,
        fats: Double,
        carbs: Double
    ) {
        self.id = id
        self.name = name
        self.measure = measure
        self.calories = calories
        self.proteins = proteins
        self.fats = fats
        self.carbs = carbs
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, measure, calories, proteins, fats, carbs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        measure = try container.decode(FoodMeasure.self, forKey: .measure)
        calories = try container.decodeFlexibleDouble(forKey: .calories)
        proteins = try container.decodeFlexibleDouble(forKey: .proteins)
        fats = try container.decodeFlexibleDouble(forKey: .fats)
        carbs = try container.decodeFlexibleDouble(forKey: .carbs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(measure, forKey: .measure)
        try container.encode(calories, forKey: .calories)
        try container.encode(proteins, forKey: .proteins)
        try container.encode(fats, forKey: .fats)
        try container.encode(carbs, forKey: .carbs)
    }
}

struct LaunchEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var food: FoodItem
    var quantity: Int

    init(id: UUID = UUID(), date: Date, food: FoodItem, quantity: Int) {
        self.id = id
        self.date = date
        self.food = food
        self.quantity = quantity
    }
}

struct DailyGoals: Codable {
    var calories: Int
    var proteins: Int
    var fats: Int
    var carbs: Int
}

enum AppSection: Int, CaseIterable {
    case dashboard
    case launches
    case foods
    case goals

    var title: String {
        switch self {
        case .dashboard: return "Resumo"
        case .launches: return "Lançamentos"
        case .foods: return "Alimentos"
        case .goals: return "Metas"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .launches: return "list.bullet.rectangle"
        case .foods: return "fork.knife"
        case .goals: return "target"
        }
    }
}

private struct PersistedAppData: Codable {
    var foods: [FoodItem]
    var launches: [LaunchEntry]
    var goals: DailyGoals
}

final class AppStore {
    static let shared = AppStore()

    private(set) var foods: [FoodItem] = []
    private(set) var launches: [LaunchEntry] = []
    private(set) var goals = DailyGoals(calories: 2000, proteins: 150, fats: 70, carbs: 250)

    private let calendar = Calendar.current
    private let saveURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.saveURL = docs.appendingPathComponent("caloria_tracker_data.json")
        load()
    }

    private var defaultFoods: [FoodItem] {
        [
            FoodItem(name: "Arroz cozido", measure: .weight100g, calories: 130.0, proteins: 3.0, fats: 0.3, carbs: 28.0),
            FoodItem(name: "Aveia", measure: .weight100g, calories: 389.0, proteins: 17.0, fats: 7.0, carbs: 66.0),
            FoodItem(name: "Banana", measure: .unit, calories: 89.0, proteins: 1.1, fats: 0.3, carbs: 23.0),
            FoodItem(name: "Ovo", measure: .unit, calories: 78.0, proteins: 6.0, fats: 5.0, carbs: 0.6)
        ]
    }

    private func defaultData() -> PersistedAppData {
        PersistedAppData(
            foods: defaultFoods,
            launches: [LaunchEntry(date: Date(), food: defaultFoods[3], quantity: 2)],
            goals: DailyGoals(calories: 2000, proteins: 150, fats: 70, carbs: 250)
        )
    }

    func sortedFoods(matching query: String? = nil) -> [FoodItem] {
        let normalized = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let source = normalized.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(normalized) }
        return source.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func launches(for date: Date) -> [LaunchEntry] {
        launches
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { lhs, rhs in
                if lhs.food.name.localizedCaseInsensitiveCompare(rhs.food.name) == .orderedSame {
                    return lhs.date < rhs.date
                }
                return lhs.food.name.localizedCaseInsensitiveCompare(rhs.food.name) == .orderedAscending
            }
    }

    func totals(for date: Date) -> (calories: Double, proteins: Double, fats: Double, carbs: Double) {
        let dayLaunches = launches(for: date)
        var totalCalories = 0.0
        var totalProteins = 0.0
        var totalFats = 0.0
        var totalCarbs = 0.0

        for entry in dayLaunches {
            let factor = entry.food.measure == .weight100g ? Double(entry.quantity) / 100.0 : Double(entry.quantity)
            totalCalories += entry.food.calories * factor
            totalProteins += entry.food.proteins * factor
            totalFats += entry.food.fats * factor
            totalCarbs += entry.food.carbs * factor
        }

        return (
            totalCalories.roundedToOneDecimal(),
            totalProteins.roundedToOneDecimal(),
            totalFats.roundedToOneDecimal(),
            totalCarbs.roundedToOneDecimal()
        )
    }

    func replaceGoals(_ newGoals: DailyGoals) {
        goals = newGoals
        persistAndNotify()
    }

    func addFood(_ food: FoodItem) {
        foods.append(food)
        persistAndNotify()
    }

    func updateFood(_ food: FoodItem) {
        guard let index = foods.firstIndex(where: { $0.id == food.id }) else { return }
        foods[index] = food
        launches = launches.map { entry in
            guard entry.food.id == food.id else { return entry }
            return LaunchEntry(id: entry.id, date: entry.date, food: food, quantity: entry.quantity)
        }
        persistAndNotify()
    }

    func deleteFood(_ food: FoodItem) {
        foods.removeAll { $0.id == food.id }
        launches.removeAll { $0.food.id == food.id }
        persistAndNotify()
    }

    func addLaunch(food: FoodItem, quantity: Int, date: Date = Date()) {
        launches.append(LaunchEntry(date: date, food: food, quantity: quantity))
        persistAndNotify()
    }

    func updateLaunch(_ launch: LaunchEntry, food: FoodItem, quantity: Int, date: Date) {
        guard let index = launches.firstIndex(where: { $0.id == launch.id }) else { return }
        launches[index] = LaunchEntry(id: launch.id, date: date, food: food, quantity: quantity)
        persistAndNotify()
    }

    func deleteLaunch(_ launch: LaunchEntry) {
        launches.removeAll { $0.id == launch.id }
        persistAndNotify()
    }

    func backupFileURL() throws -> URL {
        save()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let name = "CaloriaTracker-backup-\(formatter.string(from: Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        try FileManager.default.copyItem(at: saveURL, to: tempURL)
        return tempURL
    }

    func hasDuplicateFoodName(_ name: String, ignoring id: UUID? = nil) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return foods.contains {
            $0.id != id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == normalized
        }
    }

    private func persistAndNotify() {
        save()
        NotificationCenter.default.post(name: .appStoreDidChange, object: nil)
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else {
            apply(defaultData())
            save()
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let persisted = try? decoder.decode(PersistedAppData.self, from: data) else {
            apply(defaultData())
            save()
            return
        }

        apply(persisted)
    }

    private func save() {
        let payload = PersistedAppData(foods: foods, launches: launches, goals: goals)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    private func apply(_ payload: PersistedAppData) {
        foods = payload.foods
        launches = payload.launches
        goals = payload.goals
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return doubleValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            let normalized = stringValue.replacingOccurrences(of: ",", with: ".")
            if let value = Double(normalized) {
                return value
            }
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Valor numérico inválido")
    }
}

extension Double {
    func roundedToOneDecimal() -> Double {
        (self * 10).rounded() / 10
    }

    var formattedOneDecimalPTBR: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "0,0"
    }
}

extension Date {
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    var shortBrazilianDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        return formatter.string(from: self)
    }
}

extension UIViewController {
    func showToast(message: String) {
        let label = PaddingLabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.alpha = 0

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        UIView.animate(withDuration: 0.2, animations: {
            label.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.4, options: [.curveEaseInOut]) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }

    func installKeyboardDismissTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(endEditingFromTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func endEditingFromTap() {
        view.endEditing(true)
    }

    func applyIntegerKeyboardAccessory(to fields: [UITextField]) { }
}

final class PaddingLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
