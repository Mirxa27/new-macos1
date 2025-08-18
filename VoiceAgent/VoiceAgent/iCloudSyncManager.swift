#if os(macOS)
import Foundation
import CloudKit
import Combine
import os.log

/// Manages iCloud synchronization of settings and data across devices
@MainActor
class iCloudSyncManager: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "iCloudSync")
    
    // MARK: - Published Properties
    @Published var isSyncing = false
    @Published var syncEnabled = false
    @Published var lastSyncTime: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var conflictCount = 0
    @Published var syncProgress: Double = 0.0
    
    // MARK: - CloudKit Components
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private var syncSubscription: CKDatabaseSubscription?
    private var syncOperation: CKModifyRecordsOperation?
    
    // MARK: - Sync Configuration
    private let recordZone = CKRecordZone(zoneName: "VoiceAgentZone")
    private let subscriptionID = "VoiceAgentSyncSubscription"
    
    // MARK: - Data Management
    private var localData: SyncableData = SyncableData()
    private var pendingChanges: [PendingChange] = []
    private var syncQueue = DispatchQueue(label: "com.voiceagent.sync", qos: .background)
    
    // MARK: - Conflict Resolution
    private var conflictResolver: ConflictResolver
    
    // MARK: - Record Types
    enum RecordType: String, CaseIterable {
        case settings = "Settings"
        case aiProviderConfig = "AIProviderConfig"
        case pluginConfig = "PluginConfig"
        case automationRecording = "AutomationRecording"
        case customCommand = "CustomCommand"
        case voiceProfile = "VoiceProfile"
        case performanceSettings = "PerformanceSettings"
    }
    
    // MARK: - Sync Status
    enum SyncStatus: String {
        case idle = "Idle"
        case syncing = "Syncing"
        case uploading = "Uploading"
        case downloading = "Downloading"
        case resolving = "Resolving Conflicts"
        case error = "Error"
        case offline = "Offline"
    }
    
    init() {
        container = CKContainer(identifier: "iCloud.com.voiceagent")
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        conflictResolver = ConflictResolver()
        
        setupCloudKit()
        checkiCloudAvailability()
    }
    
    // MARK: - Setup
    
    private func setupCloudKit() {
        // Create custom zone
        createCustomZone()
        
        // Setup subscription for changes
        setupSubscription()
        
        // Register for remote notifications
        registerForRemoteNotifications()
        
        // Load existing data
        loadLocalData()
    }
    
    private func createCustomZone() {
        let zoneOperation = CKModifyRecordZonesOperation(
            recordZonesToSave: [recordZone],
            recordZoneIDsToDelete: nil
        )
        
        zoneOperation.modifyRecordZonesResultBlock = { result in
            switch result {
            case .success:
                self.logger.info("Custom zone created successfully")
            case .failure(let error):
                self.logger.error("Failed to create custom zone: \(error.localizedDescription)")
            }
        }
        
        privateDatabase.add(zoneOperation)
    }
    
    private func setupSubscription() {
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.alertBody = "Settings updated on another device"
        
        subscription.notificationInfo = notificationInfo
        
        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )
        
        operation.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                self.logger.info("Subscription setup successful")
            case .failure(let error):
                self.logger.error("Failed to setup subscription: \(error.localizedDescription)")
            }
        }
        
        privateDatabase.add(operation)
    }
    
    private func registerForRemoteNotifications() {
        NSApplication.shared.registerForRemoteNotifications()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteNotification),
            name: .CKDatabaseDidReceiveRemoteNotification,
            object: nil
        )
    }
    
    // MARK: - iCloud Availability
    
    private func checkiCloudAvailability() {
        container.accountStatus { [weak self] status, error in
            Task { @MainActor in
                switch status {
                case .available:
                    self?.syncEnabled = true
                    self?.logger.info("iCloud is available")
                    self?.performInitialSync()
                    
                case .noAccount:
                    self?.syncEnabled = false
                    self?.syncStatus = .offline
                    self?.logger.warning("No iCloud account")
                    
                case .restricted, .couldNotDetermine:
                    self?.syncEnabled = false
                    self?.syncStatus = .error
                    self?.logger.error("iCloud status: \(status.rawValue)")
                    
                @unknown default:
                    self?.syncEnabled = false
                }
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func performSync() async {
        guard syncEnabled, !isSyncing else { return }
        
        isSyncing = true
        syncStatus = .syncing
        syncProgress = 0.0
        
        do {
            // Upload local changes
            syncStatus = .uploading
            try await uploadLocalChanges()
            syncProgress = 0.5
            
            // Download remote changes
            syncStatus = .downloading
            try await downloadRemoteChanges()
            syncProgress = 0.8
            
            // Resolve conflicts if any
            if conflictCount > 0 {
                syncStatus = .resolving
                try await resolveConflicts()
            }
            
            syncProgress = 1.0
            syncStatus = .idle
            lastSyncTime = Date()
            
            logger.info("Sync completed successfully")
            
        } catch {
            syncStatus = .error
            logger.error("Sync failed: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    private func performInitialSync() {
        Task {
            await performSync()
        }
    }
    
    // MARK: - Upload Changes
    
    private func uploadLocalChanges() async throws {
        let records = createRecordsFromLocalData()
        
        guard !records.isEmpty else { return }
        
        let operation = CKModifyRecordsOperation(
            recordsToSave: records,
            recordIDsToDelete: nil
        )
        
        operation.perRecordSaveBlock = { recordID, result in
            switch result {
            case .success(let record):
                self.logger.debug("Uploaded record: \(record.recordID)")
            case .failure(let error):
                self.logger.error("Failed to upload record: \(error.localizedDescription)")
            }
        }
        
        operation.modifyRecordsResultBlock = { result in
            switch result {
            case .success:
                self.logger.info("All records uploaded successfully")
                self.pendingChanges.removeAll()
            case .failure(let error):
                self.logger.error("Upload operation failed: \(error.localizedDescription)")
            }
        }
        
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated
        
        privateDatabase.add(operation)
        
        // Wait for operation to complete
        await withCheckedContinuation { continuation in
            operation.modifyRecordsResultBlock = { _ in
                continuation.resume()
            }
        }
    }
    
    // MARK: - Download Changes
    
    private func downloadRemoteChanges() async throws {
        let query = CKQuery(recordType: RecordType.settings.rawValue, predicate: NSPredicate(value: true))
        
        let operation = CKQueryOperation(query: query)
        operation.zoneID = recordZone.zoneID
        
        var downloadedRecords: [CKRecord] = []
        
        operation.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                downloadedRecords.append(record)
            case .failure(let error):
                self.logger.error("Failed to fetch record: \(error.localizedDescription)")
            }
        }
        
        operation.queryResultBlock = { result in
            switch result {
            case .success:
                self.logger.info("Downloaded \(downloadedRecords.count) records")
                Task { @MainActor in
                    self.mergeRemoteData(downloadedRecords)
                }
            case .failure(let error):
                self.logger.error("Query failed: \(error.localizedDescription)")
            }
        }
        
        privateDatabase.add(operation)
        
        // Wait for operation to complete
        await withCheckedContinuation { continuation in
            operation.queryResultBlock = { _ in
                continuation.resume()
            }
        }
    }
    
    // MARK: - Data Conversion
    
    private func createRecordsFromLocalData() -> [CKRecord] {
        var records: [CKRecord] = []
        
        // Settings record
        let settingsRecord = CKRecord(
            recordType: RecordType.settings.rawValue,
            recordID: CKRecord.ID(recordName: "UserSettings", zoneID: recordZone.zoneID)
        )
        
        settingsRecord["wakeWordEnabled"] = localData.settings.wakeWordEnabled
        settingsRecord["wakeWord"] = localData.settings.wakeWord
        settingsRecord["speechLanguage"] = localData.settings.speechLanguage
        settingsRecord["voiceFeedbackEnabled"] = localData.settings.voiceFeedbackEnabled
        settingsRecord["voiceFeedbackVolume"] = localData.settings.voiceFeedbackVolume
        settingsRecord["voiceFeedbackSpeed"] = localData.settings.voiceFeedbackSpeed
        settingsRecord["lastModified"] = Date()
        settingsRecord["deviceID"] = getDeviceID()
        
        records.append(settingsRecord)
        
        // AI Provider configs
        for config in localData.aiProviderConfigs {
            let record = CKRecord(
                recordType: RecordType.aiProviderConfig.rawValue,
                recordID: CKRecord.ID(recordName: config.id, zoneID: recordZone.zoneID)
            )
            
            record["provider"] = config.provider
            record["apiKey"] = encryptSensitiveData(config.apiKey)
            record["model"] = config.model
            record["enabled"] = config.enabled
            record["lastModified"] = Date()
            
            records.append(record)
        }
        
        // Plugin configs
        for config in localData.pluginConfigs {
            let record = CKRecord(
                recordType: RecordType.pluginConfig.rawValue,
                recordID: CKRecord.ID(recordName: config.id, zoneID: recordZone.zoneID)
            )
            
            record["pluginID"] = config.pluginID
            record["enabled"] = config.enabled
            record["configuration"] = try? JSONSerialization.data(withJSONObject: config.configuration)
            record["lastModified"] = Date()
            
            records.append(record)
        }
        
        return records
    }
    
    private func mergeRemoteData(_ records: [CKRecord]) {
        for record in records {
            guard let recordType = RecordType(rawValue: record.recordType) else { continue }
            
            switch recordType {
            case .settings:
                mergeSettings(from: record)
                
            case .aiProviderConfig:
                mergeAIProviderConfig(from: record)
                
            case .pluginConfig:
                mergePluginConfig(from: record)
                
            case .automationRecording:
                mergeAutomationRecording(from: record)
                
            case .customCommand:
                mergeCustomCommand(from: record)
                
            case .voiceProfile:
                mergeVoiceProfile(from: record)
                
            case .performanceSettings:
                mergePerformanceSettings(from: record)
            }
        }
        
        saveLocalData()
        notifyDataChanged()
    }
    
    // MARK: - Merge Operations
    
    private func mergeSettings(from record: CKRecord) {
        let remoteModified = record["lastModified"] as? Date ?? Date.distantPast
        let localModified = localData.settings.lastModified
        
        if remoteModified > localModified {
            localData.settings.wakeWordEnabled = record["wakeWordEnabled"] as? Bool ?? false
            localData.settings.wakeWord = record["wakeWord"] as? String ?? "Hey Assistant"
            localData.settings.speechLanguage = record["speechLanguage"] as? String ?? "en-US"
            localData.settings.voiceFeedbackEnabled = record["voiceFeedbackEnabled"] as? Bool ?? false
            localData.settings.voiceFeedbackVolume = record["voiceFeedbackVolume"] as? Float ?? 0.7
            localData.settings.voiceFeedbackSpeed = record["voiceFeedbackSpeed"] as? Float ?? 0.5
            localData.settings.lastModified = remoteModified
        } else if remoteModified < localModified {
            // Local is newer, mark for upload
            markForUpload(.settings)
        } else {
            // Same timestamp, potential conflict
            handleConflict(local: localData.settings, remote: record)
        }
    }
    
    private func mergeAIProviderConfig(from record: CKRecord) {
        let configID = record.recordID.recordName
        
        if let index = localData.aiProviderConfigs.firstIndex(where: { $0.id == configID }) {
            let remoteModified = record["lastModified"] as? Date ?? Date.distantPast
            let localModified = localData.aiProviderConfigs[index].lastModified
            
            if remoteModified > localModified {
                localData.aiProviderConfigs[index].provider = record["provider"] as? String ?? ""
                localData.aiProviderConfigs[index].apiKey = decryptSensitiveData(record["apiKey"] as? Data)
                localData.aiProviderConfigs[index].model = record["model"] as? String ?? ""
                localData.aiProviderConfigs[index].enabled = record["enabled"] as? Bool ?? false
                localData.aiProviderConfigs[index].lastModified = remoteModified
            } else if remoteModified < localModified {
                markForUpload(.aiProviderConfig)
            }
        } else {
            // New config from remote
            let config = AIProviderConfig(
                id: configID,
                provider: record["provider"] as? String ?? "",
                apiKey: decryptSensitiveData(record["apiKey"] as? Data),
                model: record["model"] as? String ?? "",
                enabled: record["enabled"] as? Bool ?? false,
                lastModified: record["lastModified"] as? Date ?? Date()
            )
            localData.aiProviderConfigs.append(config)
        }
    }
    
    private func mergePluginConfig(from record: CKRecord) {
        let configID = record.recordID.recordName
        
        if let index = localData.pluginConfigs.firstIndex(where: { $0.id == configID }) {
            let remoteModified = record["lastModified"] as? Date ?? Date.distantPast
            let localModified = localData.pluginConfigs[index].lastModified
            
            if remoteModified > localModified {
                localData.pluginConfigs[index].pluginID = record["pluginID"] as? String ?? ""
                localData.pluginConfigs[index].enabled = record["enabled"] as? Bool ?? false
                
                if let configData = record["configuration"] as? Data,
                   let configuration = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                    localData.pluginConfigs[index].configuration = configuration
                }
                
                localData.pluginConfigs[index].lastModified = remoteModified
            } else if remoteModified < localModified {
                markForUpload(.pluginConfig)
            }
        } else {
            // New config from remote
            var configuration: [String: Any] = [:]
            if let configData = record["configuration"] as? Data {
                configuration = (try? JSONSerialization.jsonObject(with: configData) as? [String: Any]) ?? [:]
            }
            
            let config = PluginConfig(
                id: configID,
                pluginID: record["pluginID"] as? String ?? "",
                enabled: record["enabled"] as? Bool ?? false,
                configuration: configuration,
                lastModified: record["lastModified"] as? Date ?? Date()
            )
            localData.pluginConfigs.append(config)
        }
    }
    
    private func mergeAutomationRecording(from record: CKRecord) {
        // Implementation for automation recording merge
        logger.debug("Merging automation recording")
    }
    
    private func mergeCustomCommand(from record: CKRecord) {
        // Implementation for custom command merge
        logger.debug("Merging custom command")
    }
    
    private func mergeVoiceProfile(from record: CKRecord) {
        // Implementation for voice profile merge
        logger.debug("Merging voice profile")
    }
    
    private func mergePerformanceSettings(from record: CKRecord) {
        // Implementation for performance settings merge
        logger.debug("Merging performance settings")
    }
    
    // MARK: - Conflict Resolution
    
    private func handleConflict(local: Any, remote: CKRecord) {
        conflictCount += 1
        
        let conflict = SyncConflict(
            localData: local,
            remoteRecord: remote,
            timestamp: Date()
        )
        
        conflictResolver.addConflict(conflict)
    }
    
    private func resolveConflicts() async throws {
        let resolvedConflicts = await conflictResolver.resolveAll()
        
        for resolution in resolvedConflicts {
            switch resolution.strategy {
            case .useLocal:
                markForUpload(resolution.recordType)
                
            case .useRemote:
                mergeRemoteData([resolution.remoteRecord])
                
            case .merge:
                // Custom merge logic
                performCustomMerge(resolution)
                
            case .askUser:
                // Present UI for user to resolve
                await presentConflictResolution(resolution)
            }
        }
        
        conflictCount = 0
    }
    
    private func performCustomMerge(_ resolution: ConflictResolution) {
        // Implement custom merge logic based on record type
        logger.info("Performing custom merge for \(resolution.recordType)")
    }
    
    private func presentConflictResolution(_ resolution: ConflictResolution) async {
        // Present UI for user to resolve conflict
        logger.info("Presenting conflict resolution UI")
    }
    
    // MARK: - Change Tracking
    
    private func markForUpload(_ recordType: RecordType) {
        let change = PendingChange(
            recordType: recordType,
            changeType: .update,
            timestamp: Date()
        )
        
        pendingChanges.append(change)
    }
    
    func trackLocalChange(_ recordType: RecordType, changeType: ChangeType) {
        let change = PendingChange(
            recordType: recordType,
            changeType: changeType,
            timestamp: Date()
        )
        
        pendingChanges.append(change)
        
        // Trigger sync after delay
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await performSync()
        }
    }
    
    // MARK: - Notifications
    
    @objc private func handleRemoteNotification(_ notification: Notification) {
        logger.info("Received remote notification")
        
        Task {
            await performSync()
        }
    }
    
    private func notifyDataChanged() {
        NotificationCenter.default.post(
            name: .iCloudSyncDataChanged,
            object: nil,
            userInfo: ["data": localData]
        )
    }
    
    // MARK: - Data Persistence
    
    private func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: "SyncableData"),
           let decoded = try? JSONDecoder().decode(SyncableData.self, from: data) {
            localData = decoded
        }
    }
    
    private func saveLocalData() {
        if let encoded = try? JSONEncoder().encode(localData) {
            UserDefaults.standard.set(encoded, forKey: "SyncableData")
        }
    }
    
    // MARK: - Encryption
    
    private func encryptSensitiveData(_ data: String?) -> Data? {
        guard let data = data else { return nil }
        // Implement encryption using CryptoKit
        return data.data(using: .utf8) // Simplified for example
    }
    
    private func decryptSensitiveData(_ data: Data?) -> String? {
        guard let data = data else { return nil }
        // Implement decryption using CryptoKit
        return String(data: data, encoding: .utf8) // Simplified for example
    }
    
    // MARK: - Device Management
    
    private func getDeviceID() -> String {
        if let deviceID = UserDefaults.standard.string(forKey: "DeviceID") {
            return deviceID
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "DeviceID")
            return newID
        }
    }
    
    // MARK: - Export/Import
    
    func exportSyncData(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(localData)
        try data.write(to: url)
    }
    
    func importSyncData(from url: URL) throws {
        let data = try Data(contentsOf: url)
        localData = try JSONDecoder().decode(SyncableData.self, from: data)
        saveLocalData()
        
        Task {
            await performSync()
        }
    }
}

// MARK: - Data Models

struct SyncableData: Codable {
    var settings = UserSettings()
    var aiProviderConfigs: [AIProviderConfig] = []
    var pluginConfigs: [PluginConfig] = []
    var automationRecordings: [AutomationRecordingMetadata] = []
    var customCommands: [CustomCommand] = []
    var voiceProfiles: [VoiceProfile] = []
    var performanceSettings = PerformanceSettings()
}

struct UserSettings: Codable {
    var wakeWordEnabled = false
    var wakeWord = "Hey Assistant"
    var speechLanguage = "en-US"
    var voiceFeedbackEnabled = false
    var voiceFeedbackVolume: Float = 0.7
    var voiceFeedbackSpeed: Float = 0.5
    var lastModified = Date()
}

struct AIProviderConfig: Codable {
    let id: String
    var provider: String
    var apiKey: String?
    var model: String
    var enabled: Bool
    var lastModified: Date
}

struct PluginConfig: Codable {
    let id: String
    var pluginID: String
    var enabled: Bool
    var configuration: [String: Any]
    var lastModified: Date
    
    enum CodingKeys: String, CodingKey {
        case id, pluginID, enabled, configuration, lastModified
    }
    
    init(id: String, pluginID: String, enabled: Bool, configuration: [String: Any], lastModified: Date) {
        self.id = id
        self.pluginID = pluginID
        self.enabled = enabled
        self.configuration = configuration
        self.lastModified = lastModified
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        pluginID = try container.decode(String.self, forKey: .pluginID)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        
        if let configData = try? container.decode(Data.self, forKey: .configuration),
           let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
            configuration = config
        } else {
            configuration = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pluginID, forKey: .pluginID)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(lastModified, forKey: .lastModified)
        
        if let configData = try? JSONSerialization.data(withJSONObject: configuration) {
            try container.encode(configData, forKey: .configuration)
        }
    }
}

struct AutomationRecordingMetadata: Codable {
    let id: String
    var name: String
    var createdAt: Date
    var duration: TimeInterval
    var eventCount: Int
    var tags: [String]
}

struct CustomCommand: Codable {
    let id: String
    var trigger: String
    var action: String
    var parameters: [String: String]
    var enabled: Bool
    var lastModified: Date
}

struct VoiceProfile: Codable {
    let id: String
    var name: String
    var voiceID: String
    var pitch: Float
    var speed: Float
    var volume: Float
    var lastModified: Date
}

struct PerformanceSettings: Codable {
    var autoOptimize = true
    var adaptiveQuality = true
    var powerSaveMode = false
    var backgroundThrottling = true
    var maxCPUUsage: Double = 80.0
    var maxMemoryUsage: Double = 80.0
    var lastModified = Date()
}

struct PendingChange {
    let recordType: iCloudSyncManager.RecordType
    let changeType: ChangeType
    let timestamp: Date
}

enum ChangeType {
    case create, update, delete
}

struct SyncConflict {
    let localData: Any
    let remoteRecord: CKRecord
    let timestamp: Date
}

// MARK: - Conflict Resolution

class ConflictResolver {
    private var conflicts: [SyncConflict] = []
    
    func addConflict(_ conflict: SyncConflict) {
        conflicts.append(conflict)
    }
    
    func resolveAll() async -> [ConflictResolution] {
        var resolutions: [ConflictResolution] = []
        
        for conflict in conflicts {
            let resolution = await resolve(conflict)
            resolutions.append(resolution)
        }
        
        conflicts.removeAll()
        return resolutions
    }
    
    private func resolve(_ conflict: SyncConflict) async -> ConflictResolution {
        // Implement conflict resolution logic
        // For now, prefer remote changes
        return ConflictResolution(
            recordType: iCloudSyncManager.RecordType(rawValue: conflict.remoteRecord.recordType) ?? .settings,
            strategy: .useRemote,
            localData: conflict.localData,
            remoteRecord: conflict.remoteRecord
        )
    }
}

struct ConflictResolution {
    let recordType: iCloudSyncManager.RecordType
    let strategy: ResolutionStrategy
    let localData: Any
    let remoteRecord: CKRecord
}

enum ResolutionStrategy {
    case useLocal
    case useRemote
    case merge
    case askUser
}

// MARK: - Notifications

extension Notification.Name {
    static let iCloudSyncDataChanged = Notification.Name("iCloudSyncDataChanged")
    static let iCloudSyncStatusChanged = Notification.Name("iCloudSyncStatusChanged")
    static let iCloudSyncConflictDetected = Notification.Name("iCloudSyncConflictDetected")
}

// MARK: - CloudKit Extensions

extension Notification.Name {
    static let CKDatabaseDidReceiveRemoteNotification = Notification.Name("CKDatabaseDidReceiveRemoteNotification")
}

#endif