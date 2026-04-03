import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Shimmer Modifier
// ═══════════════════════════════════════════════════════════════════════════
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    var isDark: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let base = isDark ? Color(white: 1.0, opacity: 0.05) : Color(white: 1.0, opacity: 0.6)
                    let highlight = isDark ? Color(white: 1.0, opacity: 0.12) : Color(white: 1.0, opacity: 0.9)

                    LinearGradient(
                        stops: [
                            .init(color: base, location: 0.0),
                            .init(color: highlight, location: 0.4),
                            .init(color: highlight, location: 0.6),
                            .init(color: base, location: 1.0)
                        ],
                        startPoint: .init(x: phase, y: 0.5),
                        endPoint: .init(x: phase + 1, y: 0.5)
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + geo.size.width * 2 * phase)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(isDark: Bool = false) -> some View {
        modifier(ShimmerModifier(isDark: isDark))
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Skeleton Block (reusable)
// ═══════════════════════════════════════════════════════════════════════════
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 6
    var isDark: Bool

    var body: some View {
        let fill = isDark ? Color(white: 1, opacity: 0.08) : Color(white: 0, opacity: 0.07)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .frame(width: width, height: height)
            .shimmer(isDark: isDark)
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Dashboard Skeleton View
// ═══════════════════════════════════════════════════════════════════════════
struct DashboardSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var ds: DS { DS(isDark: isDark) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {

                // ── Header Skeleton ──
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(width: 80, height: 12, isDark: isDark)
                        SkeletonBlock(width: 140, height: 20, isDark: isDark)
                    }
                    Spacer()
                    SkeletonBlock(width: 70, height: 26, cornerRadius: 13, isDark: isDark)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                // ── Fleet Status Card Skeleton ──
                skeletonCard {
                    VStack(spacing: 0) {
                        HStack {
                            SkeletonBlock(width: 90, height: 15, isDark: isDark)
                            Spacer()
                            SkeletonBlock(width: 50, height: 12, isDark: isDark)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 14)

                        SkeletonBlock(height: 6, cornerRadius: 3, isDark: isDark)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)

                        Divider().opacity(0.1).padding(.horizontal, 16)

                        HStack(spacing: 0) {
                            ForEach(0..<3) { _ in
                                VStack(spacing: 6) {
                                    SkeletonBlock(width: 36, height: 22, isDark: isDark)
                                    SkeletonBlock(width: 60, height: 11, isDark: isDark)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }

                // ── Fastest Vehicles Card Skeleton ──
                skeletonCard {
                    VStack(spacing: 0) {
                        HStack {
                            SkeletonBlock(width: 110, height: 15, isDark: isDark)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                        ForEach(0..<3) { i in
                            HStack(spacing: 12) {
                                SkeletonBlock(width: 32, height: 32, cornerRadius: 8, isDark: isDark)
                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonBlock(width: 80, height: 13, isDark: isDark)
                                    SkeletonBlock(width: 50, height: 10, isDark: isDark)
                                }
                                Spacer()
                                SkeletonBlock(width: 55, height: 16, isDark: isDark)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            if i < 2 {
                                Divider().opacity(0.1).padding(.leading, 52)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }

                // ── Driver Score & Daily KM (side-by-side) ──
                HStack(spacing: 12) {
                    skeletonHalfCard()
                    skeletonHalfCard()
                }
                .padding(.horizontal, 20)

                // ── Alarms Card Skeleton ──
                skeletonCard {
                    VStack(spacing: 0) {
                        HStack {
                            SkeletonBlock(width: 100, height: 15, isDark: isDark)
                            Spacer()
                            SkeletonBlock(width: 40, height: 12, isDark: isDark)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 10)

                        ForEach(0..<4) { i in
                            HStack(spacing: 10) {
                                SkeletonBlock(width: 32, height: 32, cornerRadius: 8, isDark: isDark)
                                VStack(alignment: .leading, spacing: 4) {
                                    SkeletonBlock(width: 130, height: 13, isDark: isDark)
                                    SkeletonBlock(width: 90, height: 10, isDark: isDark)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    SkeletonBlock(width: 45, height: 10, isDark: isDark)
                                    SkeletonBlock(width: 35, height: 10, isDark: isDark)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            if i < 3 {
                                Divider().opacity(0.1).padding(.leading, 52)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(.top, 2)
        }
    }

    // ── Full-width card wrapper ──
    @ViewBuilder
    private func skeletonCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(ds.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
            .shadow(color: ds.cardShadow, radius: 8, x: 0, y: 3)
            .padding(.horizontal, 20)
    }

    // ── Half-width card (Driver Score / Daily KM) ──
    private func skeletonHalfCard() -> some View {
        VStack(spacing: 0) {
            HStack {
                SkeletonBlock(width: 80, height: 13, isDark: isDark)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Ring placeholder
            ZStack {
                Circle()
                    .stroke(
                        isDark ? Color(white: 1, opacity: 0.06) : Color(white: 0, opacity: 0.06),
                        lineWidth: 5
                    )
                    .frame(width: 64, height: 64)
                SkeletonBlock(width: 28, height: 22, isDark: isDark)
            }
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    SkeletonBlock(width: 24, height: 15, isDark: isDark)
                    SkeletonBlock(width: 36, height: 10, isDark: isDark)
                }
                VStack(alignment: .leading, spacing: 3) {
                    SkeletonBlock(width: 24, height: 15, isDark: isDark)
                    SkeletonBlock(width: 36, height: 10, isDark: isDark)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            SkeletonBlock(height: 30, cornerRadius: 8, isDark: isDark)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background(ds.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: DS.r, style: .continuous))
        .shadow(color: ds.cardShadow, radius: 8, x: 0, y: 3)
    }
}

struct AlarmEventsSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var ds: DS { DS(isDark: isDark) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonBlock(width: 40, height: 40, cornerRadius: 20, isDark: isDark)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBlock(width: 120, height: 13, isDark: isDark)
                            SkeletonBlock(width: 78, height: 10, isDark: isDark)
                            SkeletonBlock(width: 150, height: 10, isDark: isDark)
                        }
                        Spacer()
                        SkeletonBlock(width: 42, height: 10, isDark: isDark)
                    }
                    .padding(12)
                    .background(ds.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ds.divider, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
}

struct AlarmRulesSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var ds: DS { DS(isDark: isDark) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                SkeletonBlock(height: 44, cornerRadius: 10, isDark: isDark)
                    .padding(.horizontal, 16)

                SkeletonBlock(height: 56, cornerRadius: 12, isDark: isDark)
                    .padding(.horizontal, 16)

                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            SkeletonBlock(width: 38, height: 38, cornerRadius: 19, isDark: isDark)
                            VStack(alignment: .leading, spacing: 5) {
                                SkeletonBlock(width: 120, height: 13, isDark: isDark)
                                SkeletonBlock(width: 86, height: 10, isDark: isDark)
                            }
                            Spacer()
                            SkeletonBlock(width: 56, height: 18, cornerRadius: 9, isDark: isDark)
                        }

                        SkeletonBlock(width: 170, height: 10, isDark: isDark)
                        SkeletonBlock(width: 130, height: 10, isDark: isDark)
                    }
                    .padding(12)
                    .background(ds.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ds.divider, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
}

struct VehiclesListSkeletonView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    private var ds: DS { DS(isDark: isDark) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                SkeletonBlock(height: 44, cornerRadius: 20, isDark: isDark)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                SkeletonBlock(height: 76, cornerRadius: 16, isDark: isDark)
                    .padding(.horizontal, 16)

                ForEach(0..<5, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            SkeletonBlock(width: 40, height: 40, cornerRadius: 12, isDark: isDark)
                            VStack(alignment: .leading, spacing: 5) {
                                SkeletonBlock(width: 88, height: 14, isDark: isDark)
                                SkeletonBlock(width: 110, height: 10, isDark: isDark)
                            }
                            Spacer()
                            SkeletonBlock(width: 50, height: 18, cornerRadius: 9, isDark: isDark)
                        }

                        HStack(spacing: 8) {
                            SkeletonBlock(height: 48, cornerRadius: 10, isDark: isDark)
                            SkeletonBlock(height: 48, cornerRadius: 10, isDark: isDark)
                            SkeletonBlock(height: 48, cornerRadius: 10, isDark: isDark)
                        }

                        HStack {
                            SkeletonBlock(width: 86, height: 10, isDark: isDark)
                            Spacer()
                            SkeletonBlock(width: 64, height: 10, isDark: isDark)
                        }
                    }
                    .padding(12)
                    .background(ds.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(ds.divider, lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 20)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Preview
// ═══════════════════════════════════════════════════════════════════════════
#Preview("Light") {
    DashboardSkeletonView()
}

#Preview("Dark") {
    DashboardSkeletonView()
        .preferredColorScheme(.dark)
}
