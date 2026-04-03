import SwiftUI

struct DS {
    let isDark: Bool

    var primary: Color { isDark ? Color(red: 139/255, green: 149/255, blue: 224/255) : Color(red: 9/255, green: 15/255, blue: 65/255) }
    var primaryLight: Color { Color(red: 74/255, green: 83/255, blue: 160/255) }
    var primarySoft: Color { primary.opacity(isDark ? 0.15 : 0.07) }

    var pageBg: Color { isDark ? Color(red: 13/255, green: 16/255, blue: 36/255) : Color(red: 245/255, green: 246/255, blue: 250/255) }
    var cardBg: Color { isDark ? Color(red: 22/255, green: 26/255, blue: 55/255) : Color.white }

    static let green = Color(red: 34/255, green: 197/255, blue: 94/255)
    static let red = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let sky = Color(red: 56/255, green: 147/255, blue: 241/255)

    var text1: Color { isDark ? Color(red: 240/255, green: 241/255, blue: 250/255) : Color(red: 26/255, green: 26/255, blue: 26/255) }
    var text2: Color { isDark ? Color(red: 170/255, green: 175/255, blue: 200/255) : Color(red: 100/255, green: 100/255, blue: 112/255) }
    var text3: Color { isDark ? Color(red: 110/255, green: 115/255, blue: 145/255) : Color(red: 160/255, green: 160/255, blue: 175/255) }

    var divider: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }
    var cardShadow: Color { isDark ? Color.clear : Color.black.opacity(0.04) }

    static let r: CGFloat = 16
}
