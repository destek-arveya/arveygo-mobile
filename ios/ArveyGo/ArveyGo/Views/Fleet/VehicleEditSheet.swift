import SwiftUI

// MARK: - Vehicle Edit Sheet
struct VehicleEditSheet: View {
    let vehicle: Vehicle
    var onSaved: ((Vehicle) -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var plate: String = ""
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var vehicleModel: String = ""
    @State private var year: String = ""
    @State private var type: String = ""
    @State private var odometer: String = ""

    // State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                // ── Temel Bilgiler ──
                Section {
                    formRow(label: "Plaka") {
                        TextField("34 ABC 123", text: $plate)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                    }
                    formRow(label: "Araç Adı") {
                        TextField("İsteğe bağlı", text: $name)
                            .autocorrectionDisabled()
                    }
                } header: {
                    sectionHeader("TEMEL BİLGİLER", icon: "car.fill")
                }

                // ── Araç Detayları ──
                Section {
                    formRow(label: "Marka") {
                        TextField("Ford, Mercedes…", text: $brand)
                            .autocorrectionDisabled()
                    }
                    formRow(label: "Model") {
                        TextField("Transit, Sprinter…", text: $vehicleModel)
                            .autocorrectionDisabled()
                    }
                    formRow(label: "Yıl") {
                        TextField("2022", text: $year)
                            .keyboardType(.numberPad)
                    }
                    formRow(label: "Tip") {
                        TextField("car, motorcycle, truck…", text: $type)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    sectionHeader("ARAÇ DETAYLARI", icon: "info.circle.fill")
                }

                // ── Kilometre ──
                Section {
                    formRow(label: "Odometer (km)") {
                        TextField("48320", text: $odometer)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    sectionHeader("SAYAÇ", icon: "gauge.open.with.lines.needle.33percent")
                } footer: {
                    Text("Araç odometer değerini metre cinsinden kayıt eder.")
                        .font(.caption)
                }

                // ── Hata mesajı ──
                if let errorMessage {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Araç Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(Color(AppTheme.navy))
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(Color(AppTheme.indigo))
                    } else {
                        Button("Kaydet") { Task { await save() } }
                            .fontWeight(.semibold)
                            .foregroundColor(Color(AppTheme.indigo))
                    }
                }
            }
            .onAppear { populateFields() }
            .overlay {
                if showSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.green)
                        Text("Araç güncellendi")
                            .font(.headline)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 20)
                }
            }
        }
    }

    // MARK: - UI Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(AppTheme.indigo))
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(AppTheme.textMuted))
                .tracking(0.5)
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(AppTheme.navy))
                .frame(width: 110, alignment: .leading)
            content()
                .font(.system(size: 14))
        }
    }

    // MARK: - Logic

    private func populateFields() {
        plate         = vehicle.plate
        name          = vehicle.name.isEmpty ? vehicle.model : vehicle.name
        brand         = vehicle.vehicleBrand
        vehicleModel  = vehicle.vehicleModel
        year          = ""   // API'den gelmiyor, boş bırakılır
        type          = vehicle.vehicleCategory
        odometer      = vehicle.totalKm > 0 ? "\(vehicle.totalKm)" : ""
    }

    private func save() async {
        isSaving = true
        errorMessage = nil

        var body: [String: Any] = [:]
        if !plate.trimmingCharacters(in: .whitespaces).isEmpty        { body["plate"]    = plate.trimmingCharacters(in: .whitespaces) }
        if !name.trimmingCharacters(in: .whitespaces).isEmpty         { body["name"]     = name.trimmingCharacters(in: .whitespaces) }
        if !brand.trimmingCharacters(in: .whitespaces).isEmpty        { body["brand"]    = brand.trimmingCharacters(in: .whitespaces) }
        if !vehicleModel.trimmingCharacters(in: .whitespaces).isEmpty { body["model"]    = vehicleModel.trimmingCharacters(in: .whitespaces) }
        if let yr = Int(year), yr >= 1950                             { body["year"]     = yr }
        if !type.trimmingCharacters(in: .whitespaces).isEmpty         { body["type"]     = type.trimmingCharacters(in: .whitespaces) }
        if let odo = Int(odometer), odo >= 0                          { body["odometer"] = odo * 1000 } // km → m

        do {
            try await APIService.shared.updateVehicle(deviceId: vehicle.deviceId, data: body)

            // Build updated vehicle for callback
            var updated = vehicle
            if let p = body["plate"] as? String  { updated.plate = p }
            if let n = body["name"] as? String   { updated.name = n; updated.model = n }

            showSuccess = true
            try? await Task.sleep(for: .seconds(1.2))
            onSaved?(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

