import SwiftUI

// MARK: - Status Badge
struct StatusBadge: View {
    let status: VehicleStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.1))
            .foregroundColor(status.color)
            .cornerRadius(20)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let metric: DashboardMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(metric.iconColor == AppTheme.online ? AppTheme.online : AppTheme.navy)

                Spacer()

                Image(systemName: metric.icon)
                    .font(.system(size: 14))
                    .foregroundColor(metric.iconColor)
                    .frame(width: 32, height: 32)
                    .background(metric.iconBg)
                    .cornerRadius(8)
            }

            Text(metric.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.textMuted)

            HStack(spacing: 3) {
                Image(systemName: metric.changeType.icon)
                    .font(.system(size: 8, weight: .semibold))
                Text(metric.change)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(metric.changeType.color)
            .padding(.top, 2)
        }
        .padding(16)
        .background(AppTheme.surface)
    }
}

// MARK: - Avatar Circle
struct AvatarCircle: View {
    let initials: String
    let color: Color
    let size: CGFloat

    init(initials: String, color: Color = AppTheme.navy, size: CGFloat = 32) {
        self.initials = initials
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
    }
}

// MARK: - Card Container
struct CardView<Content: View>: View {
    let title: String
    var count: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.navy)

                    if let count = count {
                        Text(count)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.bg)
                            .cornerRadius(20)
                    }
                }

                Spacer()

                if let actionLabel = actionLabel {
                    Button(action: { action?() }) {
                        HStack(spacing: 4) {
                            Text(actionLabel)
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.indigo)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            content()
        }
        .background(AppTheme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }
}

// MARK: - Loading Spinner
struct LoadingSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white, lineWidth: 2.5)
            .frame(width: 20, height: 20)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

// MARK: - Language Switcher (Picker/Dropdown)
struct LanguageSwitcher: View {
    @ObservedObject private var strings = LoginStrings.shared

    private let languages: [(code: String, flag: String, name: String)] = [
        ("TR", "🇹🇷", "Türkçe"),
        ("EN", "🇬🇧", "English"),
        ("ES", "🇪🇸", "Español"),
        ("FR", "🇫🇷", "Français")
    ]

    var body: some View {
        Menu {
            ForEach(languages, id: \.code) { lang in
                Button(action: {
                    strings.currentLang = lang.code
                    DashboardStrings.shared.currentLang = lang.code
                }) {
                    HStack {
                        Text("\(lang.flag) \(lang.name)")
                        if strings.currentLang == lang.code {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(currentFlag)
                    .font(.system(size: 14))
                Text(strings.currentLang)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.authNightText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(AppTheme.authNightTextMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.authNightField)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.authNightBorder, lineWidth: 1)
            )
        }
    }

    private var currentFlag: String {
        languages.first(where: { $0.code == strings.currentLang })?.flag ?? "🇹🇷"
    }
}
