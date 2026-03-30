import SwiftUI

struct ContentView: View {
    @EnvironmentObject var beacon: BeaconManager

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

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bilgilendirme", systemImage: "info.circle")
                            .font(.caption).bold()
                            .foregroundStyle(.secondary)
                        Text("Bu uygulama telefonunuzu iBeacon olarak kullanır. Arka planda da yayın yapmaya devam eder. Bluetooth'un açık olduğundan emin olun.")
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
