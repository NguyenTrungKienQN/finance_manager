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

    static func isIOS17OrNewer() -> Bool {
        if #available(iOSApplicationExtension 17.0, *) {
            return true
        }
        return false
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
        GeometryReader { proxy in
            ZStack {
                // Background (Only for iOS < 17 where containerBackground isn't used)
                if !WidgetData.isIOS17OrNewer() {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color(hex: "6FA8FF"), Color(hex: "9B8CFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: proxy.size.height * 0.70)

                        Color(hex: "F2F2F7")
                        .frame(height: proxy.size.height * 0.30)
                    }
                }

                // Foreground
                VStack(spacing: 0) {
                    // TOP
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HÔM NAY")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .kerning(1.2)
                        
                        Text(WidgetData.formatted(entry.remaining))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.top, 4)
                        
                        Text(entry.todaySpent > 0 ? "Còn lại" : "Chưa chi tiêu")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.85))
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.25))
                                if entry.progress > 0 {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E8E")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * entry.progress)
                                }
                            }
                        }
                        .frame(height: 8)
                        .padding(.top, 12)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .frame(height: proxy.size.height * 0.70, alignment: .top)

                    // BOTTOM (30% white section)
                    HStack(alignment: .center, spacing: 0) {
                        // Left: Text message
                        Text(entry.isOverBudget ? "Đã vượt hạn mức." : "Bạn đang tiêu rất tốt hôm nay.")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundColor(Color(hex: "6B6B6B"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                            .frame(maxWidth: proxy.size.width * 0.7, alignment: .leading)
                        
                        Spacer(minLength: 0)
                        
                        // Right: Mascot pinned to the corner
                        Image("defaultpose")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: proxy.size.height * 0.55)
                            .offset(y: proxy.size.height * 0.08)
                    }
                    .frame(height: proxy.size.height * 0.30)
                }
            }
        }
    }
}

struct DailyBalanceWidget: Widget {
    let kind = "DailyBalanceWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: DailyBalanceProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                DailyBalanceWidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [Color(hex: "6FA8FF"), Color(hex: "9B8CFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Color(hex: "F2F2F7").frame(height: 50)
                        }
                    }
            } else {
                DailyBalanceWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Số dư ngày")
        .description("Hiển thị chi tiêu hôm nay so with hạn mức.")
        .supportedFamilies([.systemSmall, .systemMedium])

        if #available(iOSApplicationExtension 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}



// MARK: - 3. Spending Forecast Widget

struct ForecastEntry: TimelineEntry {
    let date: Date
    let projectedSpend: Double
    let avgDailySpend: Double
    let monthlyBudget: Double
}

struct ForecastProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForecastEntry {
        ForecastEntry(date: Date(), projectedSpend: 9500000, avgDailySpend: 250000, monthlyBudget: 10000000)
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
            avgDailySpend: WidgetData.double("avgDailySpend"),
            monthlyBudget: WidgetData.double("monthlyBudget")
        )
    }
}

struct ForecastWidgetView: View {
    let entry: ForecastEntry

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Background Gradient (Dark Navy Glassmorphism)
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1B263B"), Color(hex: "0D1B2A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                    )

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    Text("DỰ BÁO")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                        .kerning(2.0)
                    
                    Spacer().frame(height: 12)
                    
                    Text(getHeadline())
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .lineLimit(2)
                    
                    Spacer().frame(height: 8)
                    
                    Text(getSubtitle())
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.75))
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Mascot logic
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack {
                            // Soft shadow
                            Image(getMascotName())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.black.opacity(0.4))
                                .blur(radius: 12)
                                .offset(y: 8)
                            
                            Image(getMascotName())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        .frame(height: 110)
                        .offset(x: 15, y: 15) // Overflow bottom-right
                    }
                }
            }
        }
    }

    private func getMascotName() -> String {
        return isDanger() ? "mascotsad" : "defaultpose"
    }

    private func isDanger() -> Bool {
        return entry.projectedSpend > entry.monthlyBudget
    }

    private func getHeadline() -> String {
        if entry.avgDailySpend == 0 {
            return "Chưa có dữ liệu\ntháng này"
        }
        
        if isDanger() {
            // Re-calculate current spend to estimate exhaustion day
            let calendar = Calendar.current
            let range = calendar.range(of: .day, in: .month, for: Date())
            let daysInMonth = Double(range?.count ?? 30)
            let today = Double(calendar.component(.day, from: Date()))
            let daysRemaining = daysInMonth - today
            
            let currentSpent = entry.projectedSpend - (entry.avgDailySpend * daysRemaining)
            var daysLeft = Int((entry.monthlyBudget - currentSpent) / entry.avgDailySpend)
            if daysLeft < 0 { daysLeft = 0 }
            
            let exhaustionDate = calendar.date(byAdding: .day, value: daysLeft, to: Date()) ?? Date()
            let weekday = calendar.component(.weekday, from: exhaustionDate)
            let weekdayStrs = ["", "Chủ nhật", "Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7"]
            let dayName = weekdayStrs[weekday]
            
            if daysLeft == 0 { return "Bạn đã hết tiền\nhôm nay" }
            if daysLeft == 1 { return "Bạn sẽ hết tiền\nvào ngày mai" }
            return "Bạn sẽ hết tiền\nvào \(dayName)"
        }
        
        return "Bạn đang chi tiêu\nổn định"
    }

    private func getSubtitle() -> String {
        if entry.avgDailySpend == 0 { return "Hãy thêm giao dịch để xem dự báo" }
        return isDanger() ? "Nếu giữ mức chi hiện tại" : "Chưa có dấu hiệu vượt hạn mức"
    }
}

struct ForecastWidget: Widget {
    let kind = "ForecastWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: ForecastProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                ForecastWidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        EmptyView()
                    }
            } else {
                ForecastWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Dự báo chi tiêu")
        .description("Dự báo chi tiêu cuối tháng.")
        .supportedFamilies([.systemMedium])

        if #available(iOSApplicationExtension 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
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
        Link(destination: URL(string: "fmanager://add_transaction?homeWidget")!) {
            ZStack {
                // Background Gradient
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "F2F3F7"), Color(hex: "EDEFF5")]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)

                // Main Content
                VStack(spacing: 0) {
                    Spacer(minLength: 12)
                    
                    // Circular Action Button
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "6FE0FF"), Color(hex: "7A7CFF"), Color(hex: "B084FF")]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                            .shadow(color: Color(hex: "7A7CFF").opacity(0.35), radius: 10, x: 0, y: 8)

                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer(minLength: 8)

                    Text("Thêm nhanh")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "4A4F5A"))
                        .lineLimit(1)
                    
                    Spacer(minLength: 45) // Larger gap at the bottom for the mascot
                }

                // Mascot - Peeking from bottom right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image("mascotfirst")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96, height: 96)
                            .offset(x: 10, y: 45) // Submerge the lower half
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28)) // Ensure mascot is clipped
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct QuickAddWidget: Widget {
    let kind = "QuickAddWidget"
    var body: some WidgetConfiguration {
        let config = StaticConfiguration(kind: kind, provider: QuickAddProvider()) { entry in
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

        if #available(iOSApplicationExtension 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - 6. Habit Breaker Widget

struct HabitBreakerEntry: TimelineEntry {
    let date: Date
    let habitName: String
    let streak: Int
    let status: String
    let widgetState: String // "none" | "active" | "failed" | "frozen"
}

struct HabitBreakerProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitBreakerEntry {
        HabitBreakerEntry(date: Date(), habitName: "Cà phê", streak: 7, status: "Đừng phá hôm nay.", widgetState: "active")
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
            habitName: WidgetData.string("habitName", fallback: "Chưa có thử thách"),
            streak: WidgetData.int("habitStreak"),
            status: WidgetData.string("habitStatus", fallback: "Tạo thử thách để bắt đầu"),
            widgetState: WidgetData.string("habitWidgetState", fallback: "none")
        )
    }
}

struct HabitBreakerWidgetView: View {
    let entry: HabitBreakerEntry

    // Dynamic mascot based on state
    private var mascotImageName: String {
        switch entry.widgetState {
        case "active": return "mascotfirst"
        case "failed": return "mascotsad"
        case "frozen": return "mascotwait"
        default: return "mascotwait"
        }
    }

    // Dynamic main text
    private var mainText: String {
        switch entry.widgetState {
        case "active", "failed", "frozen": return entry.habitName
        default: return "Chưa có thử thách"
        }
    }

    // Dynamic subtext
    private var subText: String {
        entry.status
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Warm gradient background with orange border
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "F5C6A0"), Color(hex: "E8A0B0")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.5
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(hex: "FFF0E6"), Color(hex: "FFEEE8"), Color(hex: "FFE4ED")]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )

                // Content: Mascot left, Text right
                HStack(spacing: 0) {
                    // Mascot — takes ~38% of widget width
                    Image(mascotImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width * 0.38, height: geo.size.height * 0.9)
                        .padding(.leading, 8)

                    Spacer(minLength: 8)

                    // Text content — vertically centered, left-aligned
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row: 🔥 Thử thách
                        HStack(spacing: 4) {
                            Text("🔥")
                                .font(.system(size: 14))
                            Text("Thử thách")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "5A3E36"))
                                .tracking(0.5)
                        }

                        Spacer().frame(height: 12)

                        // Main text (challenge name or placeholder)
                        Text(mainText)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: "5A3E36"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)

                        Spacer().frame(height: 10)

                        // Subtext
                        Text(subText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(hex: "7A5C50"))
                            .lineLimit(1)
                    }
                    .padding(.trailing, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .widgetURL(URL(string: "fmanager://habit_breaker?homeWidget"))
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
        let config = StaticConfiguration(kind: kind, provider: HabitBreakerProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                HabitBreakerWidgetView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                HabitBreakerWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Thử thách")
        .description("Theo dõi chuỗi ngày bỏ thói quen")
        .supportedFamilies([.systemMedium])

        if #available(iOSApplicationExtension 17.0, *) {
            return config.contentMarginsDisabled()
        } else {
            return config
        }
    }
}

// MARK: - Widget Bundle



struct FinanceWidgetGroup: WidgetBundle {
    var body: some Widget {
        DailyBalanceWidget()
        ForecastWidget()
        QuickAddWidget()
        HabitBreakerWidget()
    }
}

@main
struct FinanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinanceWidgetGroup().body
    }
}
