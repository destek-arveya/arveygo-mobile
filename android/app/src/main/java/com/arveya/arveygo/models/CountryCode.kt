package com.arveya.arveygo.models

/**
 * Country code model for phone number input with flag emoji, format pattern
 */
data class CountryCode(
    val id: String,       // ISO code e.g. "TR"
    val name: String,     // Country name
    val dialCode: String, // e.g. "+90"
    val flag: String,     // Emoji flag
    val maxDigits: Int,   // Max phone digits (without country code)
    val format: String    // Format pattern e.g. "(###) ### ## ##"
) {
    companion object {
        val all: List<CountryCode> = listOf(
            CountryCode("TR", "Türkiye", "+90", "🇹🇷", 10, "(###) ### ## ##"),
            CountryCode("US", "United States", "+1", "🇺🇸", 10, "(###) ###-####"),
            CountryCode("GB", "United Kingdom", "+44", "🇬🇧", 10, "#### ######"),
            CountryCode("DE", "Germany", "+49", "🇩🇪", 11, "### ########"),
            CountryCode("FR", "France", "+33", "🇫🇷", 9, "# ## ## ## ##"),
            CountryCode("IT", "Italy", "+39", "🇮🇹", 10, "### ### ####"),
            CountryCode("ES", "Spain", "+34", "🇪🇸", 9, "### ### ###"),
            CountryCode("NL", "Netherlands", "+31", "🇳🇱", 9, "## ### ####"),
            CountryCode("BE", "Belgium", "+32", "🇧🇪", 9, "### ## ## ##"),
            CountryCode("AT", "Austria", "+43", "🇦🇹", 10, "### #######"),
            CountryCode("CH", "Switzerland", "+41", "🇨🇭", 9, "## ### ## ##"),
            CountryCode("SE", "Sweden", "+46", "🇸🇪", 9, "## ### ## ##"),
            CountryCode("NO", "Norway", "+47", "🇳🇴", 8, "### ## ###"),
            CountryCode("DK", "Denmark", "+45", "🇩🇰", 8, "## ## ## ##"),
            CountryCode("FI", "Finland", "+358", "🇫🇮", 10, "## ### ####"),
            CountryCode("PT", "Portugal", "+351", "🇵🇹", 9, "### ### ###"),
            CountryCode("GR", "Greece", "+30", "🇬🇷", 10, "### ### ####"),
            CountryCode("PL", "Poland", "+48", "🇵🇱", 9, "### ### ###"),
            CountryCode("CZ", "Czech Republic", "+420", "🇨🇿", 9, "### ### ###"),
            CountryCode("RO", "Romania", "+40", "🇷🇴", 9, "### ### ###"),
            CountryCode("HU", "Hungary", "+36", "🇭🇺", 9, "## ### ####"),
            CountryCode("BG", "Bulgaria", "+359", "🇧🇬", 9, "## ### ####"),
            CountryCode("HR", "Croatia", "+385", "🇭🇷", 9, "## ### ####"),
            CountryCode("RS", "Serbia", "+381", "🇷🇸", 9, "## ### ####"),
            CountryCode("BA", "Bosnia", "+387", "🇧🇦", 8, "## ### ###"),
            CountryCode("SI", "Slovenia", "+386", "🇸🇮", 8, "## ### ###"),
            CountryCode("SK", "Slovakia", "+421", "🇸🇰", 9, "### ### ###"),
            CountryCode("UA", "Ukraine", "+380", "🇺🇦", 9, "## ### ## ##"),
            CountryCode("RU", "Russia", "+7", "🇷🇺", 10, "(###) ###-##-##"),
            CountryCode("AZ", "Azerbaijan", "+994", "🇦🇿", 9, "## ### ## ##"),
            CountryCode("GE", "Georgia", "+995", "🇬🇪", 9, "### ### ###"),
            CountryCode("KZ", "Kazakhstan", "+7", "🇰🇿", 10, "(###) ###-##-##"),
            CountryCode("UZ", "Uzbekistan", "+998", "🇺🇿", 9, "## ### ## ##"),
            CountryCode("TM", "Turkmenistan", "+993", "🇹🇲", 8, "## ## ## ##"),
            CountryCode("KG", "Kyrgyzstan", "+996", "🇰🇬", 9, "### ### ###"),
            CountryCode("TJ", "Tajikistan", "+992", "🇹🇯", 9, "### ### ###"),
            CountryCode("SA", "Saudi Arabia", "+966", "🇸🇦", 9, "## ### ####"),
            CountryCode("AE", "UAE", "+971", "🇦🇪", 9, "## ### ####"),
            CountryCode("QA", "Qatar", "+974", "🇶🇦", 8, "#### ####"),
            CountryCode("KW", "Kuwait", "+965", "🇰🇼", 8, "#### ####"),
            CountryCode("BH", "Bahrain", "+973", "🇧🇭", 8, "#### ####"),
            CountryCode("OM", "Oman", "+968", "🇴🇲", 8, "#### ####"),
            CountryCode("IQ", "Iraq", "+964", "🇮🇶", 10, "### ### ####"),
            CountryCode("IR", "Iran", "+98", "🇮🇷", 10, "### ### ####"),
            CountryCode("IL", "Israel", "+972", "🇮🇱", 9, "## ### ####"),
            CountryCode("EG", "Egypt", "+20", "🇪🇬", 10, "### ### ####"),
            CountryCode("MA", "Morocco", "+212", "🇲🇦", 9, "## ### ####"),
            CountryCode("TN", "Tunisia", "+216", "🇹🇳", 8, "## ### ###"),
            CountryCode("DZ", "Algeria", "+213", "🇩🇿", 9, "### ## ## ##"),
            CountryCode("LY", "Libya", "+218", "🇱🇾", 9, "## ### ####"),
            CountryCode("NG", "Nigeria", "+234", "🇳🇬", 10, "### ### ####"),
            CountryCode("ZA", "South Africa", "+27", "🇿🇦", 9, "## ### ####"),
            CountryCode("KE", "Kenya", "+254", "🇰🇪", 9, "### ######"),
            CountryCode("IN", "India", "+91", "🇮🇳", 10, "##### #####"),
            CountryCode("PK", "Pakistan", "+92", "🇵🇰", 10, "### #######"),
            CountryCode("BD", "Bangladesh", "+880", "🇧🇩", 10, "#### ######"),
            CountryCode("CN", "China", "+86", "🇨🇳", 11, "### #### ####"),
            CountryCode("JP", "Japan", "+81", "🇯🇵", 10, "## #### ####"),
            CountryCode("KR", "South Korea", "+82", "🇰🇷", 10, "## #### ####"),
            CountryCode("AU", "Australia", "+61", "🇦🇺", 9, "### ### ###"),
            CountryCode("NZ", "New Zealand", "+64", "🇳🇿", 9, "## ### ####"),
            CountryCode("CA", "Canada", "+1", "🇨🇦", 10, "(###) ###-####"),
            CountryCode("MX", "Mexico", "+52", "🇲🇽", 10, "### ### ####"),
            CountryCode("BR", "Brazil", "+55", "🇧🇷", 11, "(##) #####-####"),
            CountryCode("AR", "Argentina", "+54", "🇦🇷", 10, "## #### ####"),
            CountryCode("CL", "Chile", "+56", "🇨🇱", 9, "# #### ####"),
            CountryCode("CO", "Colombia", "+57", "🇨🇴", 10, "### ### ####"),
            CountryCode("PE", "Peru", "+51", "🇵🇪", 9, "### ### ###"),
            CountryCode("SG", "Singapore", "+65", "🇸🇬", 8, "#### ####"),
            CountryCode("MY", "Malaysia", "+60", "🇲🇾", 10, "## ### ####"),
            CountryCode("TH", "Thailand", "+66", "🇹🇭", 9, "## ### ####"),
            CountryCode("ID", "Indonesia", "+62", "🇮🇩", 11, "### #### ####"),
            CountryCode("PH", "Philippines", "+63", "🇵🇭", 10, "### ### ####"),
            CountryCode("VN", "Vietnam", "+84", "🇻🇳", 9, "## ### ## ##"),
        )

        /** Format raw digits according to the format pattern */
        fun formatPhone(digits: String, format: String): String {
            val sb = StringBuilder()
            var di = 0
            for (ch in format) {
                if (di >= digits.length) break
                if (ch == '#') {
                    sb.append(digits[di])
                    di++
                } else {
                    sb.append(ch)
                }
            }
            return sb.toString()
        }
    }
}
