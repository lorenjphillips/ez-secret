import EzSecretCore
import Foundation

func stderr(_ s: String) {
    FileHandle.standardError.write(Data((s + "\n").utf8))
}

let parsed: CLIOptions.Parsed
do {
    parsed = try CLIOptions.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
    stderr("error: \(error.localizedDescription)")
    stderr("usage: ez-secret --label <text> (--env-file <p> --key <K> | --file <p> | --keychain-service <s> --keychain-account <a>) [--help]")
    exit(ExitCode.usage)
}

let options: CLIOptions
switch parsed {
case .help:
    print(CLIOptions.usage)
    exit(0)
case .version:
    print(CLIOptions.version)
    exit(0)
case .run(let o):
    options = o
}

switch options.mode {
case .stdin:
    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard let raw = String(data: data, encoding: .utf8) else {
        stderr("error: stdin is not valid UTF-8")
        exit(ExitCode.validationFailed)
    }
    let secret = stripTrailingNewline(raw)
    if let problem = options.rules.validate(secret) {
        stderr("error: validation failed: \(problem)")
        exit(ExitCode.validationFailed)
    }
    do {
        let result = try SecretStore.store(secret, to: options.destination, label: options.label, digest: options.digest)
        print(result.stdoutLine)
        exit(ExitCode.stored)
    } catch {
        stderr("error: \(error.localizedDescription)")
        exit(ExitCode.storeFailed)
    }

case .gui:
    let availability = Session.guiAvailability(forceGUI: options.forceGUI)
    guard case .available = availability else {
        stderr(availability.errorMessage)
        exit(ExitCode.noGUISession)
    }
    GUIRunner.run(options: options)
}
