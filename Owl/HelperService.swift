import Foundation
import ServiceManagement

enum HelperService {
    enum Failure: LocalizedError {
        case notEnabled
        case unavailable(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .notEnabled:
                return "Install and approve the Owl helper in macOS Settings first."
            case .unavailable(let detail):
                return detail
            case .timedOut:
                return "The Owl helper did not respond in time. Check its approval in macOS Settings."
            }
        }
    }

    static let machServiceName = "dev.ghostkaa.owl.helper"
    private static let service = SMAppService.daemon(plistName: "dev.ghostkaa.owl.helper.plist")

    static var status: SMAppService.Status { service.status }

    static func register() throws {
        try service.register()
    }

    static func unregister() throws {
        try service.unregister()
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func setSleepDisabled(_ disabled: Bool) throws {
        guard status == .enabled else { throw Failure.notEnabled }

        let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: OwlHelperProtocol.self)

        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var response: Result<Void, Error>?

        func complete(_ result: Result<Void, Error>) {
            lock.lock()
            defer { lock.unlock() }
            guard response == nil else { return }
            response = result
            semaphore.signal()
        }

        connection.interruptionHandler = {
            complete(.failure(Failure.unavailable("Connection to the Owl helper was interrupted.")))
        }
        connection.invalidationHandler = {
            complete(.failure(Failure.unavailable("Couldn't connect to the Owl helper.")))
        }
        connection.resume()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            complete(.failure(Failure.unavailable(error.localizedDescription)))
        } as? OwlHelperProtocol
        guard let proxy else {
            connection.invalidate()
            throw Failure.unavailable("Couldn't create a connection to the Owl helper.")
        }

        proxy.setSleepDisabled(disabled) { success, detail in
            complete(success ? .success(()) : .failure(Failure.unavailable(detail ?? "The Owl helper couldn't change sleep mode.")))
        }

        let timedOut = semaphore.wait(timeout: .now() + 30) == .timedOut
        connection.invalidate()
        if timedOut { throw Failure.timedOut }
        lock.lock()
        let result = response
        lock.unlock()
        guard let result else { throw Failure.unavailable("The Owl helper returned no result.") }
        try result.get()
    }
}
