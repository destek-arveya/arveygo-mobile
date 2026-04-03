import SwiftUI

// MARK: - Vehicle Edit Sheet
struct VehicleEditSheet: View {
    let vehicle: Vehicle
    var onSaved: ((Vehicle) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var ds: DS { DS(isDark: colorScheme == .dark) }

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
            ZStack {
                ds.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        vehicleHeaderCard

                        editSection(title: "Temel Bilgiler", icon: "car.fill") {
                            editField(label: "Plaka") {
                                TextField("34 ABC 123", text: $plate)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.characters)
                            }

                            editField(label: "Araç Adı") {
                                TextField("İsteğe bağlı", text: $name)
                                    .autocorrectionDisabled()
                            }
                        }

                        editSection(title: "Araç Detayları", icon: "info.circle.fill") {
                            editField(label: "Marka") {
                                TextField("Ford, Mercedes…", text: $brand)
                                    .autocorrectionDisabled()
                            }

                            editField(label: "Model") {
                                TextField("Transit, Sprinter…", text: $vehicleModel)
                                    .autocorrectionDisabled()
                            }

                            editField(label: "Yıl") {
                                TextField("2022", text: $year)
                                    .keyboardType(.numberPad)
                            }

                            editField(label: "Tip") {
                                TextField("car, motorcycle, truck…", text: $type)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                        }

                        editSection(title: "Sayaç", icon: "gauge.open.with.lines.needle.33percent") {
                            editField(label: "Odometer (km)") {
                                TextField("48320", text: $odometer)
                                    .keyboardType(.numberPad)
                            }

                            Text("Araç odometer değerini metre cinsinden kayıt eder.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ds.text3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let errorMessage {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.red)
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.red.opacity(0.20), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Araç Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                        .foregroundColor(ds.text1)
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
            .safeAreaInset(edge: .bottom) {
                bottomSaveBar
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

    private var vehicleHeaderCard: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(vehicle.status.color.opacity(0.15))
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: vehicle.mapIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(vehicle.status.color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.plate)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(ds.text1)
                Text(vehicle.model.isEmpty ? "Araç bilgilerini güncelleyin" : vehicle.model)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ds.text2)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            StatusBadge(status: vehicle.status)
        }
        .padding(18)
        .background(ds.cardBg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ds.divider, lineWidth: 1)
        )
    }

    private func editSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(AppTheme.indigo))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(ds.text2)
            }

            content()
        }
        .padding(16)
        .background(ds.cardBg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ds.divider, lineWidth: 1)
        )
    }

    private func editField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ds.text2)

            content()
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ds.text1)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ds.isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ds.divider, lineWidth: 1)
                )
        }
    }

    private var bottomSaveBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(ds.isDark ? 0.15 : 0.08)

            HStack(spacing: 12) {
                Button("İptal") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ds.text1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ds.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ds.divider, lineWidth: 1)
                    )

                Button(action: { Task { await save() } }) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Kaydet")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(AppTheme.indigo), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isSaving)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(ds.pageBg)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(AppTheme.indigo))
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(ds.text3)
                .tracking(0.5)
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(ds.text1)
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
