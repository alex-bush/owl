import Foundation
import IOKit.ps

enum PowerControl {
    enum Failure: LocalizedError {
        case command(String)
        case missingStatus
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .command(let detail): return detail
            case .missingStatus: return "pmset did not report the SleepDisabled state."
            case .verificationFailed: return "pmset ran, but the sleep state did not change."
            }
        }
    }

    private struct CommandResult {
        let exitCode: Int32
        let output: String
    }

    static func readSleepDisabled() throws -> Bool {
        let result = try run("/usr/bin/pmset", ["-g"])
        guard result.exitCode == 0 else { throw Failure.command(result.output) }

        for line in result.output.split(separator: "\n") {
            let fields = line.split(whereSeparator: \.isWhitespace)
            if fields.count >= 2 && fields[0] == "SleepDisabled" {
                if fields[1] == "1" { return true }
                if fields[1] == "0" { return false }
            }
        }
        throw Failure.missingStatus
    }

    static func isOnBattery() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let source = IOPSGetProvidingPowerSourceType(snapshot).takeUnretainedValue()
        return (source as String) == (kIOPSBatteryPowerValue as String)
    }

    static func setSleepDisabled(_ disabled: Bool) throws {
        try HelperService.setSleepDisabled(disabled)
        guard try readSleepDisabled() == disabled else { throw Failure.verificationFailed }
    }

    private static func run(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw Failure.command("Couldn't launch \(executable): \(error.localizedDescription)")
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(exitCode: process.terminationStatus,
                             output: String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
}
