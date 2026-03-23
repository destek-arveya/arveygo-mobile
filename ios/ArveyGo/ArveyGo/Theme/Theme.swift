import SwiftUI

// MARK: - Theme Colors & Styles (matching web app CSS variables)
struct AppTheme {
    // Primary colors from web
    static let navy = Color(red: 9/255, green: 15/255, blue: 65/255)        // #090F41
    static let indigo = Color(red: 74/255, green: 83/255, blue: 160/255)    // #4A53A0
    static let lavender = Color(red: 139/255, green: 149/255, blue: 224/255) // #8B95E0

    // Backgrounds
    static let bg = Color(red: 245/255, green: 246/255, blue: 250/255)       // #F5F6FA
    static let surface = Color.white
    static let bgAlt = Color(red: 240/255, green: 241/255, blue: 247/255)

    // Text
    static let textPrimary = Color(red: 9/255, green: 15/255, blue: 65/255)
    static let textSecondary = Color(red: 71/255, green: 78/255, blue: 104/255)
    static let textMuted = Color(red: 135/255, green: 142/255, blue: 168/255)
    static let textFaint = Color(red: 175/255, green: 181/255, blue: 202/255)

    // Status colors
    static let online = Color(red: 34/255, green: 197/255, blue: 94/255)    // #22C55E
    static let offline = Color(red: 239/255, green: 68/255, blue: 68/255)   // #EF4444
    static let idle = Color(red: 245/255, green: 158/255, blue: 11/255)     // #F59E0B

    // Border
    static let borderSoft = Color(red: 228/255, green: 231/255, blue: 240/255)

    // Gradient for side panel / login background
    static let panelGradient = LinearGradient(
        colors: [
            Color(red: 13/255, green: 21/255, blue: 80/255),
            Color(red: 9/255, green: 15/255, blue: 65/255),
            Color(red: 6/255, green: 11/255, blue: 48/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Button gradient
    static let buttonGradient = LinearGradient(
        colors: [navy, indigo],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Custom Button Style
struct ArveyButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.buttonGradient)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Custom TextField Style
struct ArveyTextFieldStyle: ViewModifier {
    var icon: String

    func body(content: Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 20)
            content
                .font(.system(size: 14))
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(AppTheme.bg)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.borderSoft, lineWidth: 1)
        )
    }
}

extension View {
    func arveyTextField(icon: String) -> some View {
        modifier(ArveyTextFieldStyle(icon: icon))
    }
}
