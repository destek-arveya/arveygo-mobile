import SwiftUI

struct ContentView: View {
    @EnvironmentObject var beacon: BeaconManager
    @State private var copiedToClipboard = false

    /// Teltonika'nın beklediği format: UUID:Major:Minor
    private var teltonikaFormat: String {
        "\(beacon.uuidString.uppercased()):\(beacon.majorValue):\(beacon.minorValue)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Status Card
                    VStack(spacing: 12) {
                        Image(systemName: beacon.isAdvertising ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(beacon.isAdvertising ? .green : .secondary)
                            .symbolEffect(.pulse, isActive: beacon.isAdvertising)

                        Text(beacon.statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                    // Beacon Config
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Beacon Ayarları", systemImage: "gearshape.fill")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("UUID").font(.caption).foregroundStyle(.secondary)
                            TextField("UUID", text: $beacon.uuidString)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                        }

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Major").font(.caption).foregroundStyle(.secondary)
                                TextField("Major", value: $beacon.majorValue, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Minor").font(.caption).foregroundStyle(.secondary)
                                TextField("Minor", value: $beacon.minorValue, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Identifier").font(.caption).foregroundStyle(.secondary)
                            TextField("Identifier", text: $beacon.identifierLabel)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cihaz Adı (localName)").font(.caption).foregroundStyle(.secondary)
                            TextField("Cihaz adı", text: $beacon.deviceName)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                                .autocorrectionDisabled()
                            Text("Scanner'larda görünecek isim")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // Teltonika Format
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(.orange)
                                Text("Teltonika Beacon ID")
                                    .font(.caption).bold()
                                    .foregroundStyle(.orange)
                            }
                            HStack(spacing: 8) {
                                Text(teltonikaFormat)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)

                                Button {
                                    UIPasteboard.general.string = teltonikaFormat
                                    copiedToClipboard = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        copiedToClipboard = false
                                    }
                                } label: {
                                    Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.clipboard")
                                        .foregroundStyle(copiedToClipboard ? .green : .orange)
                                        .frame(width: 36, height: 36)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            Text("Bu değeri Teltonika Web Arayüzü → Bluetooth → Beacon List'e yapıştırın.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

                    // Broadcast Button
                    Button {
                        if beacon.isAdvertising {
                            beacon.stopAdvertising()
                        } else {
                            beacon.startAdvertising()
                        }
                    } label: {
                        Label(
                            beacon.isAdvertising ? "Yayını Durdur" : "Yayına Başla",
                            systemImage: beacon.isAdvertising ? "stop.circle.fill" : "play.circle.fill"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(beacon.isAdvertising ? .red : .blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Persistence info
                    if beacon.isAdvertising {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Arka planda devam ediyor")
                                    .font(.caption).bold()
                                Text("Uygulamayı kapatsan bile yayın aktif kalır. Durdurmak için uygulamayı tekrar aç.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.25), lineWidth: 1))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bilgilendirme", systemImage: "info.circle")
                            .font(.caption).bold()
                            .foregroundStyle(.secondary)
                        Text("Ayarları bir kez girin, yayına başlayın. Uygulama arka plana alınsa bile Bluetooth yayını devam eder. Telefon yeniden başlatılırsa uygulamayı tekrar açmanız gerekir.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ArveyGo Rider")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BeaconManager())
}
