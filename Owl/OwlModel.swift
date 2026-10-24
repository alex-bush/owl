import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class OwlModel: ObservableObject {
    @Published private(set) var sleepDisabled = false
    @Published private(set) var isUnknown = false
    @Published private(set) var isOnBattery = false
    @Published private(set) var isBusy = false
    @Published private(set) var lastError: String?
    @Published private(set) var helperStatus = HelperService.status
    @Published private(set) var restoreDeadline: Date?

    private static let ownedSettingKey = "OwlDisabledSleep"
    private static let restoreRetryInterval: TimeInterval = 60
    private var refreshTimer: Timer?
    private var restoreTimer: Timer?
    private var nextRestoreAttempt: Date?
    private var pendingStartupRecovery: Bool

    var statusText: String {
        if isBusy { return "Changing sleep mode…" }
        if isUnknown { return "Sleep state unknown" }
        return sleepDisabled ? "Sleep disabled" : "Sleep works normally"
    }

    var actionTitle: String {
        sleepDisabled ? "Restore Normal Sleep" : "Keep Mac Awake (1h)"
    }

    var helperIsReady: Bool { helperStatus == .enabled }

    var helperStatusText: String {
        switch helperStatus {
        case .enabled: return "Owl helper is ready"
        case .requiresApproval: return "Approve the Owl helper in macOS Settings"
        case .notRegistered: return "Owl helper is not installed"
        case .notFound: return "Owl helper not found in the app bundle"
        @unknown default: return "Owl helper status unknown"
        }
    }

    init() {
        pendingStartupRecovery = UserDefaults.standard.bool(forKey: Self.ownedSettingKey)
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.recoverAfterInterruptedRun()
            }
        }
        recoverAfterInterruptedRun()
    }

    func refresh() {
        helperStatus = HelperService.status
        isOnBattery = PowerControl.isOnBattery()
        do {
            sleepDisabled = try PowerControl.readSleepDisabled()
            isUnknown = false
            if !sleepDisabled && restoreDeadline != nil && !isBusy {
                cancelRestoreTimer()
                UserDefaults.standard.set(false, forKey: Self.ownedSettingKey)
            }
            restoreIfDue()
        } catch {
            isUnknown = true
            lastError = error.localizedDescription
        }
    }

    func toggle() {
        guard !isBusy && !isUnknown && helperIsReady else { return }
        if sleepDisabled {
            changeSleepDisabled(to: false)
        } else {
            scheduleReturnToSleep(after: 1)
        }
    }

    func scheduleReturnToSleep(after hours: Int) {
        guard (1...3).contains(hours), !isBusy && !isUnknown && helperIsReady else { return }
        if sleepDisabled {
            UserDefaults.standard.set(true, forKey: Self.ownedSettingKey)
            setRestoreDeadline(Date().addingTimeInterval(TimeInterval(hours * 3600)))
        } else {
            changeSleepDisabled(to: true, restoreAfter: TimeInterval(hours * 3600))
        }
    }

    func cancelRestoreTimer() {
        restoreTimer?.invalidate()
        restoreTimer = nil
        restoreDeadline = nil
        nextRestoreAttempt = nil
    }

    private func setRestoreDeadline(_ deadline: Date) {
        cancelRestoreTimer()
        restoreDeadline = deadline
        scheduleRestoreTimer(at: deadline)
    }

    private func scheduleRestoreTimer(at date: Date) {
        restoreTimer?.invalidate()
        restoreTimer = Timer.scheduledTimer(withTimeInterval: max(0, date.timeIntervalSinceNow), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.restoreIfDue() }
        }
    }

    private func restoreIfDue() {
        let now = Date()
        guard let restoreDeadline, restoreDeadline <= now,
              nextRestoreAttempt.map({ $0 <= now }) ?? true,
              !isBusy, !isUnknown, helperIsReady else { return }
        guard sleepDisabled else { return }
        let retryAt = now.addingTimeInterval(Self.restoreRetryInterval)
        nextRestoreAttempt = retryAt
        scheduleRestoreTimer(at: retryAt)
        changeSleepDisabled(to: false, showAlertOnFailure: false)
    }

    private func changeSleepDisabled(to target: Bool, restoreAfter duration: TimeInterval? = nil,
                                     showAlertOnFailure: Bool = true) {
        pendingStartupRecovery = false
        if target, let duration {
            setRestoreDeadline(Date().addingTimeInterval(duration))
        }
        isBusy = true
        lastError = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try PowerControl.setSleepDisabled(target) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success:
                    UserDefaults.standard.set(target, forKey: Self.ownedSettingKey)
                    if !target {
                        self.cancelRestoreTimer()
                    }
                    self.refresh()
                case .failure(let error):
                    self.refresh()
                    if !self.isUnknown && self.sleepDisabled == target {
                        UserDefaults.standard.set(target, forKey: Self.ownedSettingKey)
                    }
                    if showAlertOnFailure {
                        self.showError(error)
                    } else {
                        self.lastError = error.localizedDescription
                    }
                }
                self.restoreIfDue()
            }
        }
    }

    func registerHelper() {
        lastError = nil
        do {
            try HelperService.register()
        } catch {
            refresh()
            if helperStatus != .requiresApproval && helperStatus != .enabled {
                showError(error, title: "Couldn't install the helper")
            }
        }
        refresh()
        recoverAfterInterruptedRun()
    }

    func openHelperSettings() {
        HelperService.openSettings()
    }

    func unregisterHelper() {
        guard !isBusy && !isUnknown && !sleepDisabled else { return }
        lastError = nil
        do {
            try HelperService.unregister()
            refresh()
        } catch {
            showError(error, title: "Couldn't uninstall the helper")
        }
    }

    func quit() {
        guard !isBusy else { return }
        guard UserDefaults.standard.bool(forKey: Self.ownedSettingKey) else {
            NSApplication.shared.terminate(nil)
            return
        }

        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try PowerControl.setSleepDisabled(false) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success:
                    UserDefaults.standard.set(false, forKey: Self.ownedSettingKey)
                    NSApplication.shared.terminate(nil)
                case .failure(let error):
                    self.refresh()
                    self.showError(error)
                }
            }
        }
    }

    private func recoverAfterInterruptedRun() {
        guard pendingStartupRecovery && helperIsReady && !isBusy else { return }
        pendingStartupRecovery = false
        isBusy = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try PowerControl.setSleepDisabled(false) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isBusy = false
                switch result {
                case .success:
                    UserDefaults.standard.set(false, forKey: Self.ownedSettingKey)
                    self.refresh()
                case .failure(let error):
                    self.refresh()
                    self.showError(error)
                }
            }
        }
    }

    private func showError(_ error: Error, title: String = "Couldn't change sleep mode") {
        lastError = error.localizedDescription
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
