import WidgetKit
import SwiftUI

// MARK: - Shared Data Helper

struct WidgetData {
    static let suiteName = "group.com.therize.fmanager"

    static func string(_ key: String, fallback: String = "0") -> String {
        UserDefaults(suiteName: suiteName)?.string(forKey: key) ?? fallback
    }

    static func double(_ key: String) -> Double {
        Double(string(key)) ?? 0
    }

    static func int(_ key: String) -> Int {
        Int(double(key))
    }

    static func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.maximumFractionDigits = 0
        return (formatter.string(from: NSNumber(value: value)) ?? "0") + "₫"
    }
}

// MARK: - 1. Daily Balance Widget

struct DailyBalanceEntry: TimelineEntry {
    let date: Date
    let todaySpent: Double
    let dailyLimit: Double
    var remaining: Double { dailyLimit - todaySpent }
    var progress: Double { dailyLimit > 0 ? min(todaySpent / dailyLimit, 1.0) : 0 }
    var isOverBudget: Bool { remaining < 0 }
}

struct DailyBalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyBalanceEntry {
        DailyBalanceEntry(date: Date(), todaySpent: 150000, dailyLimit: 300000)
    }
    func getSnapshot(in context: Context, completion: @escaping (DailyBalanceEntry) -> Void) {
        completion(createEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyBalanceEntry>) -> Void) {
        let entry = createEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
        completion(timeline)
    }
    private func createEntry() -> DailyBalanceEntry {
        DailyBalanceEntry(
            date: Date(),
            todaySpent: WidgetData.double("todaySpent"),
            dailyLimit: WidgetData.double("dailyLimit")
        )
    }
}

struct DailyBalanceWidgetView: View {
    let entry: DailyBalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.purple)
                    .font(.caption)
                Text("Chi tiêu hôm nay")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(WidgetData.formatted(entry.remaining))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(entry.isOverBudget ? .red : .green)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.isOverBudget ? Color.red : Color.purple)
                        .frame(width: geo.size.width * entry.progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Chi: \(WidgetData.formatted(entry.todaySpent))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("HM: \(WidgetData.formatted(entry.dailyLimit))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct DailyBalanceWidget: Widget {
    let kind = "DailyBalanceWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyBalanceProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                DailyBalanceWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                DailyBalanceWidgetView(entry: entry)
                    .background(Color("WidgetBackground"))
            }
        }
        .configurationDisplayName("Số dư ngày")
        .description("Hiển thị chi tiêu hôm nay so với hạn mức.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 2. Weekly Summary Widget

struct WeeklySummaryEntry: TimelineEntry {
    let date: Date
    let weekSpent: Double
    let mostExpensiveCategory: String
    let categoryAmount: Double
}

struct WeeklySummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklySummaryEntry {
        WeeklySummaryEntry(date: Date(), weekSpent: 1200000, mostExpensiveCategory: "Ăn uống", categoryAmount: 850000)
    }
    func getSnapshot(in context: Context, completion: @escaping (WeeklySummaryEntry) -> Void) {
        completion(createEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklySummaryEntry>) -> Void) {
        let timeline = Timeline(entries: [createEntry()], policy: .after(Date().addingTimeInterval(60 * 60)))
        completion(timeline)
    }
    private func createEntry() -> WeeklySummaryEntry {
        WeeklySummaryEntry(
            date: Date(),
            weekSpent: WidgetData.double("weekSpent"),
            mostExpensiveCategory: WidgetData.string("topCategory", fallback: "Chưa có"),
            categoryAmount: WidgetData.double("categoryAmount")
        )
    }
}

struct WeeklySummaryWidgetView: View {
    let entry: WeeklySummaryEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Tuần này")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            Text(WidgetData.formatted(entry.weekSpent))
                .font(.title2)
                .fontWeight(.bold)

            if family == .systemMedium || family == .systemLarge {
                Divider()
                Text("Nhiều nhất: \(entry.mostExpensiveCategory)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(WidgetData.formatted(entry.categoryAmount))
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct WeeklySummaryWidget: Widget {
    let kind = "WeeklySummaryWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklySummaryProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                WeeklySummaryWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WeeklySummaryWidgetView(entry: entry)
                    .background(Color("WidgetBackground"))
            }
        }
        .configurationDisplayName("Tổng kết tuần")
        .description("Xem nhanh chi tiêu trong tuần.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - 3. Spending Forecast Widget

struct ForecastEntry: TimelineEntry {
    let date: Date
    let projectedSpend: Double
    let safeToSpendDaily: Double
    let status: String
}

struct ForecastProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForecastEntry {
        ForecastEntry(date: Date(), projectedSpend: 9500000, safeToSpendDaily: 250000, status: "Tốt")
    }
    func getSnapshot(in context: Context, completion: @escaping (ForecastEntry) -> Void) {
        completion(createEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ForecastEntry>) -> Void) {
        let timeline = Timeline(entries: [createEntry()], policy: .after(Date().addingTimeInterval(6 * 60 * 60)))
        completion(timeline)
    }
    private func createEntry() -> ForecastEntry {
        ForecastEntry(
            date: Date(),
            projectedSpend: WidgetData.double("projectedSpend"),
            safeToSpendDaily: WidgetData.double("safeToSpendDaily"),
            status: WidgetData.string("forecastStatus", fallback: "-")
        )
    }
}

struct ForecastWidgetView: View {
    let entry: ForecastEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Dự báo")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Dự kiến")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(WidgetData.formatted(entry.projectedSpend))
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Có thể chi / ngày")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(WidgetData.formatted(entry.safeToSpendDaily))
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }

            Text("Trạng thái: \(entry.status)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ForecastWidget: Widget {
    let kind = "ForecastWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ForecastProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                ForecastWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ForecastWidgetView(entry: entry)
                    .background(Color("WidgetBackground"))
            }
        }
        .configurationDisplayName("Dự báo chi tiêu")
        .description("Dự báo chi tiêu cuối tháng.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - 4. Savings Goal Widget

struct SavingsGoalEntry: TimelineEntry {
    let date: Date
    let goalName: String
    let currentAmount: Double
    let targetAmount: Double
    var progress: Double { targetAmount > 0 ? currentAmount / targetAmount : 0 }
}

struct SavingsGoalProvider: TimelineProvider {
    func placeholder(in context: Context) -> SavingsGoalEntry {
        SavingsGoalEntry(date: Date(), goalName: "Du lịch hè", currentAmount: 5000000, targetAmount: 20000000)
    }
    func getSnapshot(in context: Context, completion: @escaping (SavingsGoalEntry) -> Void) {
        completion(createEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SavingsGoalEntry>) -> Void) {
        let timeline = Timeline(entries: [createEntry()], policy: .after(Date().addingTimeInterval(30 * 60)))
        completion(timeline)
    }
    private func createEntry() -> SavingsGoalEntry {
        SavingsGoalEntry(
            date: Date(),
            goalName: WidgetData.string("topGoalName", fallback: "Tiết kiệm"),
            currentAmount: WidgetData.double("topGoalCurrent"),
            targetAmount: WidgetData.double("topGoalTarget")
        )
    }
}

struct SavingsGoalWidgetView: View {
    let entry: SavingsGoalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.green)
                    .font(.caption)
                Text(entry.goalName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(WidgetData.formatted(entry.currentAmount))
                .font(.headline)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green)
                    .frame(width: max(0, min(150, 150 * CGFloat(entry.progress))), height: 8)
            }

            if entry.progress >= 1.0 {
                Text("✓ Đã đạt!")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .fontWeight(.bold)
            } else {
                Text("Mục tiêu: \(WidgetData.formatted(entry.targetAmount))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct SavingsGoalWidget: Widget {
    let kind = "SavingsGoalWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SavingsGoalProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                SavingsGoalWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                SavingsGoalWidgetView(entry: entry)
                    .background(Color("WidgetBackground"))
            }
        }
        .configurationDisplayName("Mục tiêu tiết kiệm")
        .description("Theo dõi tiến độ mục tiêu của bạn.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 5. Quick Add Transaction Widget

struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: Date())
    }
    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        completion(Timeline(entries: [QuickAddEntry(date: Date())], policy: .never))
    }
}

struct QuickAddWidgetView: View {
    let entry: QuickAddEntry

    var body: some View {
        Link(destination: URL(string: "financemanager://open_add_transaction")!) {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.purple)
                Text("Thêm giao dịch")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct QuickAddWidget: Widget {
    let kind = "QuickAddWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                QuickAddWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuickAddWidgetView(entry: entry)
                    .background(Color("WidgetBackground"))
            }
        }
        .configurationDisplayName("Thêm nhanh")
        .description("Mở app nhanh để thêm giao dịch")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 6. Habit Breaker Widget

struct HabitBreakerEntry: TimelineEntry {
    let date: Date
    let habitName: String
    let streak: Int
    let status: String
}

struct HabitBreakerProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitBreakerEntry {
        HabitBreakerEntry(date: Date(), habitName: "Cà phê", streak: 7, status: "Khởi đầu tốt! 🌱")
    }
    func getSnapshot(in context: Context, completion: @escaping (HabitBreakerEntry) -> Void) {
        completion(createEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitBreakerEntry>) -> Void) {
        let timeline = Timeline(entries: [createEntry()], policy: .after(Date().addingTimeInterval(60 * 60)))
        completion(timeline)
    }
    private func createEntry() -> HabitBreakerEntry {
        HabitBreakerEntry(
            date: Date(),
            habitName: WidgetData.string("habitName", fallback: "Chưa có"),
            streak: WidgetData.int("habitStreak"),
            status: WidgetData.string("habitStatus", fallback: "Bắt đầu ngay!")
        )
    }
}

struct HabitBreakerWidgetView: View {
    let entry: HabitBreakerEntry

    var body: some View {
        ZStack {
            // Main Content
            VStack(alignment: .leading, spacing: 0) {
                // Top Left Labels
                Text("THÓI QUEN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .kerning(0.5)

                Text(entry.habitName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 2)

                Spacer()

                // Center Stack
                VStack(spacing: -3) {
                    Text("🔥")
                        .font(.system(size: 24))
                    
                    Text("\(entry.streak)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Text("Ngày liên tiếp")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity) // Center horizontally

                Spacer()
                // Spacer pushes the status bar down, but we pin it perfectly with another Vstack layer
            }
            .padding(12)
            
            // Bottom Status Bar Pinned
            VStack {
                Spacer()
                Text(entry.status)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "4CAF50")) // Android Green
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
            }
        }
    }
}

// Extension to support Android Hex colors easily
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct HabitBreakerWidget: Widget {
    let kind = "HabitBreakerWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HabitBreakerProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                HabitBreakerWidgetView(entry: entry)
                    .containerBackground(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "1A237E"), .black]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ),
                        for: .widget
                    )
            } else {
                HabitBreakerWidgetView(entry: entry)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "1A237E"), .black]),
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
            }
        }
        .configurationDisplayName("Thói quen")
        .description("Theo dõi chuỗi ngày bỏ thói quen")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle

// MARK: - 7. Recurring Widget

struct RecurringEntry: TimelineEntry {
    let date: Date
    let title: String
    let amount: Double
    let daysUntilDue: Int
}

struct RecurringProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecurringEntry {
        RecurringEntry(date: Date(), title: "Tiền nhà", amount: 5000000, daysUntilDue: 3)
    }
    func getSnapshot(in context: Context, completion: @escaping (RecurringEntry) -> Void) {
        completion(createEntry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecurringEntry>) -> Void) {
        let timeline = Timeline(entries: [createEntry()], policy: .after(Date().addingTimeInterval(30 * 60)))
        completion(timeline)
    }
    private func createEntry() -> RecurringEntry {
        RecurringEntry(
            date: Date(),
            title: WidgetData.string("recurringTitle", fallback: "Chưa có"),
            amount: WidgetData.double("recurringAmount"),
            daysUntilDue: WidgetData.int("recurringDays")
        )
    }
}

struct RecurringWidgetView: View {
    let entry: RecurringEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text("Sắp đến hạn")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(entry.title)
                .font(.headline)
                .lineLimit(1)

            Text(WidgetData.formatted(entry.amount))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.red)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(entry.daysUntilDue <= 3 ? Color.red : Color.blue)
                    .frame(width: max(0, min(150, 150 * (max(0, 30.0 - Double(entry.daysUntilDue)) / 30.0))), height: 6)
            }
            .padding(.vertical, 4)

            if entry.daysUntilDue < 0 {
                Text("Đã quá hạn \(abs(entry.daysUntilDue)) ngày!")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            } else if entry.daysUntilDue == 0 {
                Text("Đến hạn hôm nay!")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            } else {
                Text("Còn \(entry.daysUntilDue) ngày")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct RecurringWidget: Widget {
    let kind = "RecurringWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecurringProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                RecurringWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                RecurringWidgetView(entry: entry)
                    .background(Color("WidgetBackground"))
            }
        }
        .configurationDisplayName("Chi phí định kỳ")
        .description("Khoản chi định kỳ sắp đến hạn nhất.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle Workarounds for iOS 14
// iOS 14 limit is 5 widgets per bundle. We have 7. We must split them.

struct FinanceWidgetGroup1: WidgetBundle {
    var body: some Widget {
        DailyBalanceWidget()
        WeeklySummaryWidget()
        ForecastWidget()
        SavingsGoalWidget()
    }
}

struct FinanceWidgetGroup2: WidgetBundle {
    var body: some Widget {
        QuickAddWidget()
        HabitBreakerWidget()
        RecurringWidget()
    }
}

@main
struct FinanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinanceWidgetGroup1().body
        FinanceWidgetGroup2().body
    }
}
