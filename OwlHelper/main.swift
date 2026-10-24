import Darwin
import Foundation
import Security

private let machServiceName = "dev.ghostkaa.owl.helper"
private let appIdentifier = "dev.ghostkaa.owl"

private func signingTeamIdentifier() -> String? {
    var selfCode: SecCode?
    guard SecCodeCopySelf(SecCSFlags(), &selfCode) == errSecSuccess, let selfCode else { return nil }

    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(selfCode, SecCSFlags(), &staticCode) == errSecSuccess,
          let staticCode else { return nil }

    var information: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode,
                                        SecCSFlags(rawValue: kSecCSSigningInformation),
                                        &information) == errSecSuccess,
          let values = information as? [String: Any],
          let team = values[kSecCodeInfoTeamIdentifier as String] as? String,
          team.count == 10,
          team.allSatisfy({ $0.isASCII && ($0.isUppercase || $0.isNumber) }) else { return nil }
    return team
}

private final class OwlHelper: NSObject, NSXPCListenerDelegate, OwlHelperProtocol {
    private let workQueue = DispatchQueue(label: "dev.ghostkaa.owl.helper.pmset")

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: OwlHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool, String?) -> Void) {
        workQueue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["-a", "disablesleep", disabled ? "1" : "0"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output

            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let detail = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if process.terminationStatus == 0 {
                    reply(true, nil)
                } else {
                    reply(false, detail?.isEmpty == false ? detail : "pmset exited with an error.")
                }
            } catch {
                reply(false, "Couldn't launch pmset: \(error.localizedDescription)")
            }
        }
    }
}

guard geteuid() == 0, let team = signingTeamIdentifier() else {
    fputs("OwlHelper requires root and an Apple-issued code signature.\n", stderr)
    exit(1)
}

let requirement = "identifier \"\(appIdentifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
private let helper = OwlHelper()
let listener = NSXPCListener(machServiceName: machServiceName)
listener.setConnectionCodeSigningRequirement(requirement)
listener.delegate = helper
listener.resume()
dispatchMain()
