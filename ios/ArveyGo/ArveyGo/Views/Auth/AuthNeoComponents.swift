import SwiftUI

struct AuthNeoBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.authNightTop, AppTheme.authNightBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Circle()
                        .fill(AppTheme.authNightGlow)
                        .frame(width: 260, height: 260)
                        .blur(radius: 12)
                    Spacer()
                }
                Spacer()
            }
            .ignoresSafeArea()

            GeometryReader { geo in
                Path { path in
                    let spacing: CGFloat = 28
                    stride(from: CGFloat(0), through: geo.size.width, by: spacing).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    stride(from: CGFloat(0), through: geo.size.height, by: spacing).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
            }
            .ignoresSafeArea()
        }
    }
}

struct AuthNeoHero: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let chips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.authNightTextSecondary)

            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.authNightText)
                .fixedSize(horizontal: false, vertical: true)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.authNightTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !chips.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    ForEach(chips, id: \.self) { chip in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(0.72))
                                .frame(width: 6, height: 6)
                            Text(chip)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.authNightTextSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.authNightChip, in: Capsule(style: .continuous))
                    }
                }
            }
        }
    }
}

func authPrompt(_ text: String) -> Text {
    Text(text).foregroundStyle(Color.white.opacity(0.78))
}

struct AuthNeoPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [AppTheme.authNightPanel, AppTheme.authNightPanelSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.authNightBorder, lineWidth: 1)
        )
        .shadow(color: AppTheme.authShadow.opacity(0.45), radius: 24, x: 0, y: 14)
    }
}

struct AuthNeoField<Content: View>: View {
    let label: String
    let icon: String
    var isFocused: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.authNightTextSecondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.authNightTextMuted)
                    .frame(width: 20)
                content
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(AppTheme.authNightField, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isFocused ? Color.white.opacity(0.40) : AppTheme.authNightBorder, lineWidth: isFocused ? 1.4 : 1)
            )
        }
    }
}

struct AuthNeoModeSwitcher: View {
    let selectedIndex: Int
    let options: [(icon: String, title: String)]
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    onSelect(index)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: option.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(option.title)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(selectedIndex == index ? AppTheme.navy : AppTheme.authNightTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedIndex == index ? Color.white : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(AppTheme.authNightField, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.authNightBorder, lineWidth: 1)
        )
    }
}

struct AuthNeoSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.authNightTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.authNightField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.authNightBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct AuthNeoDivider: View {
    let title: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(AppTheme.authNightBorder)
                .frame(height: 1)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.authNightTextMuted)
            Rectangle()
                .fill(AppTheme.authNightBorder)
                .frame(height: 1)
        }
    }
}
