import SwiftUI

struct CountryPickerSheet: View {
    @Binding var selected: CountryCode
    @Binding var isPresented: Bool
    @State private var searchText = ""

    private var filtered: [CountryCode] {
        if searchText.isEmpty { return CountryCode.all }
        let q = searchText.lowercased()
        return CountryCode.all.filter {
            $0.name.lowercased().contains(q) ||
            $0.dialCode.contains(q) ||
            $0.id.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.authTextMuted)
                        .font(.system(size: 14))
                    TextField("Ülke ara / Search country", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.authTextPrimary)
                        .tint(AppTheme.navy)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(AppTheme.authField)
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                List(filtered) { country in
                    Button {
                        selected = country
                        isPresented = false
                    } label: {
                        HStack(spacing: 12) {
                            Text(country.flag)
                                .font(.system(size: 24))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.authTextPrimary)
                                Text(country.dialCode)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.authTextMuted)
                            }

                            Spacer()

                            if country.id == selected.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.authAccent)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .background(AppTheme.authCanvas.ignoresSafeArea())
            .navigationTitle("Ülke Kodu / Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.authTextMuted)
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .tint(AppTheme.navy)
    }
}
