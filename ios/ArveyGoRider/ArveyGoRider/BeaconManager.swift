import Foundation
import CoreBluetooth
import CoreLocation

// MARK: - Persistence Keys
private enum StorageKey {
    static let uuid         = "beacon_uuid"
    static let major        = "beacon_major"
    static let minor        = "beacon_minor"
    static let identifier   = "beacon_identifier"
    static let deviceName   = "beacon_device_name"
    static let wasActive    = "beacon_was_active"   // ← arka planda yeniden başlatmak için
}

/// iBeacon yayın yöneticisi.
/// - CBPeripheralManager state restoration sayesinde iOS uygulamayı arka planda
///   yeniden başlattığında yayın otomatik devam eder.
/// - "wasActive" flag'i ile her uygulama açılışında önceki oturum devam ettirilir.
@MainActor
class BeaconManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var isAdvertising  = false
    @Published var statusMessage  = "Hazır. Ayarları girin ve yayına başlayın."

    // Ayarlar UserDefaults'a persist edilir
    @Published var uuidString: String {
        didSet { UserDefaults.standard.set(uuidString,     forKey: StorageKey.uuid) }
    }
    @Published var majorValue: UInt16 {
        didSet { UserDefaults.standard.set(majorValue,     forKey: StorageKey.major) }
    }
    @Published var minorValue: UInt16 {
        didSet { UserDefaults.standard.set(minorValue,     forKey: StorageKey.minor) }
    }
    @Published var identifierLabel: String {
        didSet { UserDefaults.standard.set(identifierLabel, forKey: StorageKey.identifier) }
    }
    @Published var deviceName: String {
        didSet { UserDefaults.standard.set(deviceName,     forKey: StorageKey.deviceName) }
    }

    // MARK: - Private
    private static let restoreID = "com.arveya.arveygorider.peripheral"
    private var peripheralManager: CBPeripheralManager!
    private var pendingBeaconData: [String: Any]?

    // MARK: - Init
    override init() {
        let ud = UserDefaults.standard
        uuidString      = ud.string(forKey: StorageKey.uuid)       ?? "89627cfc-1a11-4be4-9b29-a668aa394835"
        let savedMajor  = ud.object(forKey: StorageKey.major) as? Int
        let savedMinor  = ud.object(forKey: StorageKey.minor) as? Int
        majorValue      = savedMajor.map { UInt16($0) } ?? 1
        minorValue      = savedMinor.map { UInt16($0) } ?? 1
        identifierLabel = ud.string(forKey: StorageKey.identifier) ?? "com.arveya.arveygorider"
        deviceName      = ud.string(forKey: StorageKey.deviceName) ?? "ArveyGoRider"
        super.init()

        // State restoration ile PeripheralManager'ı başlat
        // iOS bu sayede arka planda uygulamayı restore edebilir
        let options: [String: Any] = [
            CBPeripheralManagerOptionRestoreIdentifierKey: Self.restoreID,
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ]
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main, options: options)
    }

    // MARK: - Public API

    func startAdvertising() {
        guard let uuid = UUID(uuidString: uuidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            statusMessage = "⛔ Geçersiz UUID formatı."
            return
        }

        let constraint = CLBeaconIdentityConstraint(uuid: uuid, major: majorValue, minor: minorValue)
        let region     = CLBeaconRegion(beaconIdentityConstraint: constraint, identifier: identifierLabel)
        var data       = region.peripheralData(withMeasuredPower: -59) as? [String: Any] ?? [:]

        let name = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            data[CBAdvertisementDataLocalNameKey] = name
        }

        pendingBeaconData = data
        UserDefaults.standard.set(true, forKey: StorageKey.wasActive)   // persist

        if peripheralManager.state == .poweredOn {
            beginBroadcast()
        } else {
            statusMessage = "⏳ Bluetooth açılıyor…"
        }
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        pendingBeaconData = nil
        isAdvertising = false
        UserDefaults.standard.set(false, forKey: StorageKey.wasActive)  // persist
        statusMessage = "⏹ Yayın durduruldu."
    }

    // MARK: - Private

    private func beginBroadcast() {
        guard let data = pendingBeaconData else { return }
        peripheralManager.stopAdvertising()         // temizle
        peripheralManager.startAdvertising(data)
        isAdvertising = true
        statusMessage = "📡 Beacon yayını aktif!"
    }

    /// Önceki oturumda yayın aktifse otomatik devam et
    private func resumeIfNeeded() {
        guard UserDefaults.standard.bool(forKey: StorageKey.wasActive) else { return }
        guard pendingBeaconData == nil else { return }  // zaten hazır
        startAdvertising()
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BeaconManager: CBPeripheralManagerDelegate {

    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        Task { @MainActor in
            switch state {
            case .poweredOn:
                if pendingBeaconData != nil {
                    beginBroadcast()
                } else {
                    resumeIfNeeded()
                    if !isAdvertising {
                        statusMessage = "✅ Bluetooth açık. Yayına başlayabilirsiniz."
                    }
                }
            case .poweredOff:
                isAdvertising = false
                statusMessage = "⛔ Bluetooth kapalı. Lütfen açın."
            case .unauthorized:
                statusMessage = "⛔ Bluetooth izni verilmedi."
            case .unsupported:
                statusMessage = "⛔ Bu cihaz BLE desteklemiyor."
            case .resetting:
                statusMessage = "⏳ Bluetooth yeniden başlıyor…"
            default:
                break
            }
        }
    }

    /// iOS state restoration: uygulama arka planda restore edildiğinde çağrılır
    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager,
                                       willRestoreState dict: [String: Any]) {
        let hasServices = (dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService])?.isEmpty == false
        Task { @MainActor in
            if hasServices {
                isAdvertising = true
                statusMessage = "📡 Beacon yayını aktif! (restore)"
            }
        }
    }

    nonisolated func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        let errMsg = error?.localizedDescription
        Task { @MainActor in
            if let errMsg {
                isAdvertising = false
                statusMessage = "⛔ Hata: \(errMsg)"
                UserDefaults.standard.set(false, forKey: StorageKey.wasActive)
            } else {
                isAdvertising = true
                statusMessage = "📡 Beacon yayını aktif!"
            }
        }
    }
}
