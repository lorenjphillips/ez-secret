import Foundation

public enum ExitCode {
    public static let stored: Int32 = 0
    public static let cancelled: Int32 = 1
    public static let usage: Int32 = 2
    public static let validationFailed: Int32 = 3
    public static let timeout: Int32 = 4
    public static let noGUISession: Int32 = 5
    public static let storeFailed: Int32 = 6
}

public enum Mode: Equatable {
    case gui
    case stdin
}

public struct CLIOptions: Equatable {
    public static let version = "0.1.1"

    public var label: String
    public var requester: String?
    public var destination: Destination
    public var rules: ValidationRules
    public var timeoutSeconds: Int
    public var digest: Bool
    public var forceGUI: Bool
    public var mode: Mode

    public struct UsageError: Swift.Error, LocalizedError, Equatable {
        public let message: String
        public var errorDescription: String? { message }
    }

    public enum Parsed: Equatable {
        case run(CLIOptions)
        case help
        case version
    }

    public static let usage = """
    ez-secret \(version) — ask the user for a secret in a native macOS panel
    and write it where the agent says, without the value ever touching stdout.

    USAGE
      ez-secret --label <text> <destination> [options]

    DESTINATION (exactly one)
      --env-file <path> --key <NAME>      upsert NAME=value into a dotenv file
                                          (other lines and comments kept; always left 0600)
      --file <path>                       write the raw value to <path> (mode 0600)
      --keychain-service <svc> --keychain-account <acct>
                                          store in the login Keychain (generic password)

    OPTIONS
      --label <text>          what the user is asked for (required)
      --requester <text>      requester name when no agent is detected
      --validate-prefix <s>   reject values that do not start with <s>
      --min-length <n>        reject values shorter than <n> characters
      --timeout <seconds>     give up after this long (default 120; minimum 15)
                              EZ_SECRET_TIMEOUT changes the default; --timeout overrides it
                              both require an integer >= 15 (otherwise exit 2)
      --no-digest             omit the sha256-prefix from stdout
      --force-gui             show the panel even inside an ssh session (you are at
                              this Mac's console); otherwise ssh sessions exit 5
      --stdin                 no UI: read the secret from stdin (tests / scripts)
      -h, --help              show this help
      --version               print the version

    STDOUT (never the secret)
      stored: <destination>, length: <n>, sha256-prefix: <8 hex>
      cancelled
      timeout

    EXIT CODES
      0 stored   1 cancelled   2 usage error   3 validation failed
      4 timeout  5 no GUI session (use --stdin)   6 write/keychain error

    FOR AGENTS
      Never ask for secrets in chat.
      The command blocks until the user answers; the shell tool's timeout must exceed --timeout.
      After exit 0, reference the destination; never read the value back (no cat/echo/printenv/security -w).
      Exit 1/4: ask the user before re-prompting. Exit 5: inside an agent sandbox, rerun the same command with sandbox escalation (user approval); otherwise ask the user to run it in a desktop terminal.
    """

    public static func parse(_ args: [String], environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Parsed {
        var label: String?
        var requester: String?
        var envFile: String?
        var key: String?
        var file: String?
        var service: String?
        var account: String?
        var prefix: String?
        var minLength: Int?
        var timeout: Int?
        var digest = true
        var forceGUI = false
        var mode = Mode.gui

        var i = 0
        func value(for flag: String) throws -> String {
            i += 1
            guard i < args.count else { throw UsageError(message: "\(flag) needs a value") }
            return args[i]
        }
        func intValue(for flag: String) throws -> Int {
            let raw = try value(for: flag)
            guard let n = Int(raw), n >= 0 else { throw UsageError(message: "\(flag) needs a non-negative integer, got '\(raw)'") }
            return n
        }

        func timeoutValue(_ raw: String, source: String) throws -> Int {
            guard let n = Int(raw), n >= 15 else {
                throw UsageError(message: "\(source) must be an integer >= 15 seconds, got '\(raw)'")
            }
            return n
        }

        while i < args.count {
            let a = args[i]
            switch a {
            case "-h", "--help": return .help
            case "--version": return .version
            case "--label": label = try value(for: a)
            case "--requester": requester = try value(for: a)
            case "--env-file": envFile = try value(for: a)
            case "--key": key = try value(for: a)
            case "--file": file = try value(for: a)
            case "--keychain-service": service = try value(for: a)
            case "--keychain-account": account = try value(for: a)
            case "--validate-prefix": prefix = try value(for: a)
            case "--min-length": minLength = try intValue(for: a)
            case "--timeout": timeout = try timeoutValue(value(for: a), source: a)
            case "--no-digest": digest = false
            case "--force-gui": forceGUI = true
            case "--stdin": mode = .stdin
            default:
                throw UsageError(message: "unknown argument '\(a)' (see --help)")
            }
            i += 1
        }

        if timeout == nil, let raw = environment["EZ_SECRET_TIMEOUT"] {
            timeout = try timeoutValue(raw, source: "EZ_SECRET_TIMEOUT")
        }

        guard let label, !label.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw UsageError(message: "--label is required")
        }

        var destinations: [Destination] = []
        if envFile != nil || key != nil {
            guard let envFile, let key else {
                throw UsageError(message: "--env-file and --key must be given together")
            }
            guard EnvFile.isValidKey(key) else {
                throw UsageError(message: "--key '\(key)' must match [A-Za-z_][A-Za-z0-9_]*")
            }
            destinations.append(.envFile(path: Destination.absolutePath(envFile), key: key))
        }
        if let file {
            destinations.append(.file(path: Destination.absolutePath(file)))
        }
        if service != nil || account != nil {
            guard let service, let account, !service.isEmpty, !account.isEmpty else {
                throw UsageError(message: "--keychain-service and --keychain-account must be given together")
            }
            destinations.append(.keychain(service: service, account: account))
        }
        guard destinations.count == 1 else {
            throw UsageError(message: destinations.isEmpty
                ? "a destination is required: --env-file/--key, --file, or --keychain-service/--keychain-account"
                : "exactly one destination is allowed, got \(destinations.count)")
        }
        if let prefix, prefix.isEmpty {
            throw UsageError(message: "--validate-prefix must not be empty")
        }

        return .run(CLIOptions(
            label: label,
            requester: requester,
            destination: destinations[0],
            rules: ValidationRules(requiredPrefix: prefix, minLength: minLength),
            timeoutSeconds: timeout ?? 120,
            digest: digest,
            forceGUI: forceGUI,
            mode: mode
        ))
    }
}
