import SwiftUI

@main
struct OwlApp: App {
    @NSApplicationDelegateAdaptor(OwlAppDelegate.self) private var appDelegate
    @StateObject private var model = OwlModel()

    var body: some Scene {
        MenuBarExtra {
            Text(model.statusText)

            if model.isOnBattery {
                Text(model.sleepDisabled ? "On battery · higher battery drain" : "On battery power")
            }

            if let error = model.lastError {
                Text(error)
            }

            if !model.helperIsReady {
                Text(model.helperStatusText)
                if model.helperStatus == .requiresApproval {
                    Button("Open Settings to Approve Helper") {
                        model.openHelperSettings()
                    }
                } else {
                    Button("Install Owl Helper") {
                        model.registerHelper()
                    }
                }
            }

            if model.helperStatus == .enabled || model.helperStatus == .requiresApproval {
                Button("Uninstall Owl Helper") {
                    model.unregisterHelper()
                }
                .disabled(model.isBusy || model.isUnknown || model.sleepDisabled)
            }

            Divider()

            Button(model.actionTitle) {
                model.toggle()
            }
            .disabled(model.isBusy || model.isUnknown || !model.helperIsReady)

            Menu(model.sleepDisabled ? "Restore Normal Sleep In…" : "Keep Awake For…") {
                Button("1 hour") { model.scheduleReturnToSleep(after: 1) }
                Button("2 hours") { model.scheduleReturnToSleep(after: 2) }
                Button("3 hours") { model.scheduleReturnToSleep(after: 3) }
            }
            .disabled(model.isBusy || model.isUnknown || !model.helperIsReady)

            if let deadline = model.restoreDeadline {
                if deadline <= Date() {
                    Text("Retrying normal sleep…")
                } else {
                    Text("Normal sleep returns: \(deadline.formatted(date: .abbreviated, time: .shortened))")
                }
                Button("Cancel Timer") {
                    model.cancelRestoreTimer()
                }
                .disabled(model.isBusy)
            }

            Divider()

            Button("Quit Owl") {
                model.quit()
            }
            .disabled(model.isBusy)
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: OwlIcon.image(isAwake: model.sleepDisabled))
                .accessibilityLabel("Owl: \(model.statusText)")
        }
    }
}

final class OwlAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        let key = "OwlDisabledSleep"
        guard UserDefaults.standard.bool(forKey: key) else { return }
        if (try? PowerControl.setSleepDisabled(false)) != nil {
            UserDefaults.standard.set(false, forKey: key)
        }
    }
}
