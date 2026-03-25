import Foundation

/// Country code model for phone number input
struct CountryCode: Identifiable, Hashable {
    let id: String       // ISO code e.g. "TR"
    let name: String     // Country name
    let dialCode: String // e.g. "+90"
    let flag: String     // Emoji flag
    let maxDigits: Int   // Max phone digits (without country code)
    let format: String   // Format pattern e.g. "(5XX) XXX XX XX"

    /// All supported country codes
    static let all: [CountryCode] = [
        CountryCode(id: "TR", name: "Türkiye", dialCode: "+90", flag: "🇹🇷", maxDigits: 10, format: "(###) ### ## ##"),
        CountryCode(id: "US", name: "United States", dialCode: "+1", flag: "🇺🇸", maxDigits: 10, format: "(###) ###-####"),
        CountryCode(id: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧", maxDigits: 10, format: "#### ######"),
        CountryCode(id: "DE", name: "Germany", dialCode: "+49", flag: "🇩🇪", maxDigits: 11, format: "### ########"),
        CountryCode(id: "FR", name: "France", dialCode: "+33", flag: "🇫🇷", maxDigits: 9, format: "# ## ## ## ##"),
        CountryCode(id: "IT", name: "Italy", dialCode: "+39", flag: "🇮🇹", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "ES", name: "Spain", dialCode: "+34", flag: "🇪🇸", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "NL", name: "Netherlands", dialCode: "+31", flag: "🇳🇱", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "BE", name: "Belgium", dialCode: "+32", flag: "🇧🇪", maxDigits: 9, format: "### ## ## ##"),
        CountryCode(id: "AT", name: "Austria", dialCode: "+43", flag: "🇦🇹", maxDigits: 10, format: "### #######"),
        CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "🇨🇭", maxDigits: 9, format: "## ### ## ##"),
        CountryCode(id: "SE", name: "Sweden", dialCode: "+46", flag: "🇸🇪", maxDigits: 9, format: "## ### ## ##"),
        CountryCode(id: "NO", name: "Norway", dialCode: "+47", flag: "🇳🇴", maxDigits: 8, format: "### ## ###"),
        CountryCode(id: "DK", name: "Denmark", dialCode: "+45", flag: "🇩🇰", maxDigits: 8, format: "## ## ## ##"),
        CountryCode(id: "FI", name: "Finland", dialCode: "+358", flag: "🇫🇮", maxDigits: 10, format: "## ### ####"),
        CountryCode(id: "PT", name: "Portugal", dialCode: "+351", flag: "🇵🇹", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "GR", name: "Greece", dialCode: "+30", flag: "🇬🇷", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "PL", name: "Poland", dialCode: "+48", flag: "🇵🇱", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "CZ", name: "Czech Republic", dialCode: "+420", flag: "🇨🇿", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "RO", name: "Romania", dialCode: "+40", flag: "🇷🇴", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "HU", name: "Hungary", dialCode: "+36", flag: "🇭🇺", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "BG", name: "Bulgaria", dialCode: "+359", flag: "🇧🇬", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "HR", name: "Croatia", dialCode: "+385", flag: "🇭🇷", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "RS", name: "Serbia", dialCode: "+381", flag: "🇷🇸", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "BA", name: "Bosnia", dialCode: "+387", flag: "🇧🇦", maxDigits: 8, format: "## ### ###"),
        CountryCode(id: "SI", name: "Slovenia", dialCode: "+386", flag: "🇸🇮", maxDigits: 8, format: "## ### ###"),
        CountryCode(id: "SK", name: "Slovakia", dialCode: "+421", flag: "🇸🇰", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "UA", name: "Ukraine", dialCode: "+380", flag: "🇺🇦", maxDigits: 9, format: "## ### ## ##"),
        CountryCode(id: "RU", name: "Russia", dialCode: "+7", flag: "🇷🇺", maxDigits: 10, format: "(###) ###-##-##"),
        CountryCode(id: "AZ", name: "Azerbaijan", dialCode: "+994", flag: "🇦🇿", maxDigits: 9, format: "## ### ## ##"),
        CountryCode(id: "GE", name: "Georgia", dialCode: "+995", flag: "🇬🇪", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "KZ", name: "Kazakhstan", dialCode: "+7", flag: "🇰🇿", maxDigits: 10, format: "(###) ###-##-##"),
        CountryCode(id: "UZ", name: "Uzbekistan", dialCode: "+998", flag: "🇺🇿", maxDigits: 9, format: "## ### ## ##"),
        CountryCode(id: "TM", name: "Turkmenistan", dialCode: "+993", flag: "🇹🇲", maxDigits: 8, format: "## ## ## ##"),
        CountryCode(id: "KG", name: "Kyrgyzstan", dialCode: "+996", flag: "🇰🇬", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "TJ", name: "Tajikistan", dialCode: "+992", flag: "🇹🇯", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "SA", name: "Saudi Arabia", dialCode: "+966", flag: "🇸🇦", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "AE", name: "UAE", dialCode: "+971", flag: "🇦🇪", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "QA", name: "Qatar", dialCode: "+974", flag: "🇶🇦", maxDigits: 8, format: "#### ####"),
        CountryCode(id: "KW", name: "Kuwait", dialCode: "+965", flag: "🇰🇼", maxDigits: 8, format: "#### ####"),
        CountryCode(id: "BH", name: "Bahrain", dialCode: "+973", flag: "🇧🇭", maxDigits: 8, format: "#### ####"),
        CountryCode(id: "OM", name: "Oman", dialCode: "+968", flag: "🇴🇲", maxDigits: 8, format: "#### ####"),
        CountryCode(id: "IQ", name: "Iraq", dialCode: "+964", flag: "🇮🇶", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "IR", name: "Iran", dialCode: "+98", flag: "🇮🇷", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "IL", name: "Israel", dialCode: "+972", flag: "🇮🇱", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "EG", name: "Egypt", dialCode: "+20", flag: "🇪🇬", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "MA", name: "Morocco", dialCode: "+212", flag: "🇲🇦", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "TN", name: "Tunisia", dialCode: "+216", flag: "🇹🇳", maxDigits: 8, format: "## ### ###"),
        CountryCode(id: "DZ", name: "Algeria", dialCode: "+213", flag: "🇩🇿", maxDigits: 9, format: "### ## ## ##"),
        CountryCode(id: "LY", name: "Libya", dialCode: "+218", flag: "🇱🇾", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "NG", name: "Nigeria", dialCode: "+234", flag: "🇳🇬", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "ZA", name: "South Africa", dialCode: "+27", flag: "🇿🇦", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "KE", name: "Kenya", dialCode: "+254", flag: "🇰🇪", maxDigits: 9, format: "### ######"),
        CountryCode(id: "IN", name: "India", dialCode: "+91", flag: "🇮🇳", maxDigits: 10, format: "##### #####"),
        CountryCode(id: "PK", name: "Pakistan", dialCode: "+92", flag: "🇵🇰", maxDigits: 10, format: "### #######"),
        CountryCode(id: "BD", name: "Bangladesh", dialCode: "+880", flag: "🇧🇩", maxDigits: 10, format: "#### ######"),
        CountryCode(id: "CN", name: "China", dialCode: "+86", flag: "🇨🇳", maxDigits: 11, format: "### #### ####"),
        CountryCode(id: "JP", name: "Japan", dialCode: "+81", flag: "🇯🇵", maxDigits: 10, format: "## #### ####"),
        CountryCode(id: "KR", name: "South Korea", dialCode: "+82", flag: "🇰🇷", maxDigits: 10, format: "## #### ####"),
        CountryCode(id: "AU", name: "Australia", dialCode: "+61", flag: "🇦🇺", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "NZ", name: "New Zealand", dialCode: "+64", flag: "🇳🇿", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "CA", name: "Canada", dialCode: "+1", flag: "🇨🇦", maxDigits: 10, format: "(###) ###-####"),
        CountryCode(id: "MX", name: "Mexico", dialCode: "+52", flag: "🇲🇽", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "BR", name: "Brazil", dialCode: "+55", flag: "🇧🇷", maxDigits: 11, format: "(##) #####-####"),
        CountryCode(id: "AR", name: "Argentina", dialCode: "+54", flag: "🇦🇷", maxDigits: 10, format: "## #### ####"),
        CountryCode(id: "CL", name: "Chile", dialCode: "+56", flag: "🇨🇱", maxDigits: 9, format: "# #### ####"),
        CountryCode(id: "CO", name: "Colombia", dialCode: "+57", flag: "🇨🇴", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "PE", name: "Peru", dialCode: "+51", flag: "🇵🇪", maxDigits: 9, format: "### ### ###"),
        CountryCode(id: "SG", name: "Singapore", dialCode: "+65", flag: "🇸🇬", maxDigits: 8, format: "#### ####"),
        CountryCode(id: "MY", name: "Malaysia", dialCode: "+60", flag: "🇲🇾", maxDigits: 10, format: "## ### ####"),
        CountryCode(id: "TH", name: "Thailand", dialCode: "+66", flag: "🇹🇭", maxDigits: 9, format: "## ### ####"),
        CountryCode(id: "ID", name: "Indonesia", dialCode: "+62", flag: "🇮🇩", maxDigits: 11, format: "### #### ####"),
        CountryCode(id: "PH", name: "Philippines", dialCode: "+63", flag: "🇵🇭", maxDigits: 10, format: "### ### ####"),
        CountryCode(id: "VN", name: "Vietnam", dialCode: "+84", flag: "🇻🇳", maxDigits: 9, format: "## ### ## ##"),
    ]

    /// Format raw digits according to the format pattern
    /// '#' in format is replaced by a digit
    static func formatPhone(_ digits: String, format: String) -> String {
        var result = ""
        var digitIndex = digits.startIndex
        for char in format {
            guard digitIndex < digits.endIndex else { break }
            if char == "#" {
                result.append(digits[digitIndex])
                digitIndex = digits.index(after: digitIndex)
            } else {
                result.append(char)
            }
        }
        return result
    }
}
