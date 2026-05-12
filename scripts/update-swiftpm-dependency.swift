#!/usr/bin/env swift

import Foundation

struct DependencySyncConfig: Decodable {
    let dependencies: [DependencyRule]
}

struct DependencyRule: Decodable {
    let identity: String
    let packageURL: String
    let syncs: [SyncRule]
}

struct SyncRule: Decodable {
    enum Kind: String, Decodable {
        case files
        case tree
    }

    let kind: Kind
    let paths: [String]?
    let root: String?
    let required: Bool?
    let fileExtensions: [String]?
    let pattern: String
    let replacement: String
}

struct PackageResolved: Decodable {
    let pins: [ResolvedPin]
}

struct ResolvedPin: Decodable {
    let identity: String
    let state: ResolvedState
}

struct ResolvedState: Decodable {
    let version: String?
}

let versionPlaceholder = "__VERSION_PLACEHOLDER__"

enum ScriptError: LocalizedError {
    case usage
    case missingDependency(String)
    case missingResolvedVersion(String)
    case missingPackageDeclaration(String)
    case missingScriptDirectory
    case invalidRule(String)
    case noMatches(path: String, pattern: String)
    case noTreeMatches(root: String, pattern: String)
    case driftDetected([String])
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage:\n  ./scripts/update-swiftpm-dependency.swift <dependency-identity> <version>\n  ./scripts/update-swiftpm-dependency.swift --check"
        case .missingDependency(let identity):
            return "No dependency rule found for '\(identity)'."
        case .missingResolvedVersion(let identity):
            return "Package.resolved does not contain a resolved version for '\(identity)'."
        case .missingPackageDeclaration(let url):
            return "Could not find a matching .package declaration for \(url) in Package.swift."
        case .missingScriptDirectory:
            return "Could not determine the script directory."
        case .invalidRule(let message):
            return message
        case .noMatches(let path, let pattern):
            return "No matches found in \(path) for pattern: \(pattern)"
        case .noTreeMatches(let root, let pattern):
            return "No matches found under \(root) for pattern: \(pattern)"
        case .driftDetected(let paths):
            let joined = paths.joined(separator: "\n")
            return "Dependency metadata drift detected in:\n\(joined)"
        case .commandFailed(let command):
            return "Command failed: \(command)"
        }
    }
}

func scriptURL() throws -> URL {
    let path = CommandLine.arguments[0]
    guard !path.isEmpty else {
        throw ScriptError.missingScriptDirectory
    }

    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
        .standardizedFileURL
}

func loadConfig(at url: URL) throws -> DependencySyncConfig {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(DependencySyncConfig.self, from: data)
}

func replaceMatches(in text: String, pattern: String, replacementTemplate: String) throws -> (String, Int) {
    let regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    let count = regex.numberOfMatches(in: text, options: [], range: range)
    guard count > 0 else {
        return (text, 0)
    }

    let updated = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacementTemplate)
    return (updated, count)
}

func applySync(in text: String, pattern: String, replacementTemplate: String, resolvedVersion: String, requireMatch: Bool, failurePath: String) throws -> (String, Int) {
    let placeholderTemplate = replacementTemplate.replacingOccurrences(of: "{{version}}", with: versionPlaceholder)
    let (intermediate, matchCount) = try replaceMatches(in: text, pattern: pattern, replacementTemplate: placeholderTemplate)

    if requireMatch && matchCount == 0 {
        throw ScriptError.noMatches(path: failurePath, pattern: pattern)
    }

    return (intermediate.replacingOccurrences(of: versionPlaceholder, with: resolvedVersion), matchCount)
}

@discardableResult
func syncFile(at url: URL, pattern: String, replacementTemplate: String, resolvedVersion: String, requireMatch: Bool) throws -> Int {
    let original = try String(contentsOf: url, encoding: .utf8)
    let (updated, matchCount) = try applySync(
        in: original,
        pattern: pattern,
        replacementTemplate: replacementTemplate,
        resolvedVersion: resolvedVersion,
        requireMatch: requireMatch,
        failurePath: url.path
    )

    if updated != original {
        try updated.write(to: url, atomically: true, encoding: .utf8)
    }

    return matchCount
}

func checkFile(at url: URL, pattern: String, replacementTemplate: String, resolvedVersion: String, requireMatch: Bool) throws -> Bool {
    let original = try String(contentsOf: url, encoding: .utf8)
    let (expected, _) = try applySync(
        in: original,
        pattern: pattern,
        replacementTemplate: replacementTemplate,
        resolvedVersion: resolvedVersion,
        requireMatch: requireMatch,
        failurePath: url.path
    )
    return expected == original
}

func filesUnderRoot(rootURL: URL, allowedExtensions: Set<String>) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        return []
    }

    var urls: [URL] = []
    for case let url as URL in enumerator {
        if !allowedExtensions.isEmpty {
            let fileExtension = url.pathExtension.lowercased()
            guard allowedExtensions.contains(fileExtension) else {
                continue
            }
        }
        urls.append(url)
    }

    return urls.sorted { $0.path < $1.path }
}

func runCommand(_ launchPath: String, arguments: [String], workingDirectory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments
    process.currentDirectoryURL = workingDirectory

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let output = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let command = ([launchPath] + arguments).joined(separator: " ")
        if !output.isEmpty {
            FileHandle.standardError.write(Data(output.utf8))
        }
        throw ScriptError.commandFailed(command)
    }
}

func resolvedVersion(for dependency: DependencyRule, in resolved: PackageResolved) throws -> String {
    guard let resolvedVersion = resolved.pins.first(where: { $0.identity == dependency.identity })?.state.version else {
        throw ScriptError.missingResolvedVersion(dependency.identity)
    }
    return resolvedVersion
}

func performCheck(config: DependencySyncConfig, repoRoot: URL, packageResolvedURL: URL) throws {
    let resolvedData = try Data(contentsOf: packageResolvedURL)
    let resolved = try JSONDecoder().decode(PackageResolved.self, from: resolvedData)
    var driftedPaths: [String] = []

    for dependency in config.dependencies {
        let resolvedVersion = try resolvedVersion(for: dependency, in: resolved)

        for rule in dependency.syncs {
            let isRequired = rule.required ?? true

            switch rule.kind {
            case .files:
                guard let paths = rule.paths, !paths.isEmpty else {
                    throw ScriptError.invalidRule("The 'files' rule for \(dependency.identity) is missing 'paths'.")
                }

                for relativePath in paths {
                    let fileURL = repoRoot.appendingPathComponent(relativePath)
                    let isInSync = try checkFile(
                        at: fileURL,
                        pattern: rule.pattern,
                        replacementTemplate: rule.replacement,
                        resolvedVersion: resolvedVersion,
                        requireMatch: isRequired
                    )
                    if !isInSync {
                        driftedPaths.append(relativePath)
                    }
                }

            case .tree:
                guard let root = rule.root else {
                    throw ScriptError.invalidRule("The 'tree' rule for \(dependency.identity) is missing 'root'.")
                }

                let rootURL = repoRoot.appendingPathComponent(root)
                let extensions = Set((rule.fileExtensions ?? []).map { $0.lowercased() })
                let fileURLs = filesUnderRoot(rootURL: rootURL, allowedExtensions: extensions)

                var sawMatch = false
                for fileURL in fileURLs {
                    let original = try String(contentsOf: fileURL, encoding: .utf8)
                    let (expected, matchCount) = try applySync(
                        in: original,
                        pattern: rule.pattern,
                        replacementTemplate: rule.replacement,
                        resolvedVersion: resolvedVersion,
                        requireMatch: false,
                        failurePath: fileURL.path
                    )
                    if matchCount > 0 {
                        sawMatch = true
                        if expected != original {
                            let relativePath = fileURL.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                            driftedPaths.append(relativePath)
                        }
                    }
                }

                if isRequired && !sawMatch {
                    throw ScriptError.noTreeMatches(root: root, pattern: rule.pattern)
                }
            }
        }
    }

    if !driftedPaths.isEmpty {
        throw ScriptError.driftDetected(driftedPaths)
    }

    print("Dependency metadata sync check passed.")
}

func main() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())

    let script = try scriptURL()
    let repoRoot = script.deletingLastPathComponent().deletingLastPathComponent()
    let configURL = repoRoot.appendingPathComponent("scripts/dependency-sync.json")
    let packageSwiftURL = repoRoot.appendingPathComponent("Package.swift")
    let packageResolvedURL = repoRoot.appendingPathComponent("Package.resolved")

    let config = try loadConfig(at: configURL)

    if arguments.count == 1, arguments[0] == "--check" {
        try performCheck(config: config, repoRoot: repoRoot, packageResolvedURL: packageResolvedURL)
        return
    }

    guard arguments.count == 2 else {
        throw ScriptError.usage
    }

    let dependencyIdentity = arguments[0]
    let requestedVersion = arguments[1]

    guard let dependency = config.dependencies.first(where: { $0.identity == dependencyIdentity }) else {
        throw ScriptError.missingDependency(dependencyIdentity)
    }

    let escapedURL = NSRegularExpression.escapedPattern(for: dependency.packageURL)
    let packagePattern = #"(\.package\(url: \"__URL__\",\s*(?:from|exact):\s*\")[^\"]+(\")"#
        .replacingOccurrences(of: "__URL__", with: escapedURL)

    let packageOriginal = try String(contentsOf: packageSwiftURL, encoding: .utf8)
    let (packageInterim, packageMatches) = try replaceMatches(
        in: packageOriginal,
        pattern: packagePattern,
        replacementTemplate: "$1\(versionPlaceholder)$2"
    )
    let packageUpdated = packageInterim.replacingOccurrences(of: versionPlaceholder, with: requestedVersion)

    guard packageMatches > 0 else {
        throw ScriptError.missingPackageDeclaration(dependency.packageURL)
    }

    if packageUpdated != packageOriginal {
        try packageUpdated.write(to: packageSwiftURL, atomically: true, encoding: .utf8)
    }

    try runCommand("/usr/bin/env", arguments: ["swift", "package", "resolve"], workingDirectory: repoRoot)

    let resolvedData = try Data(contentsOf: packageResolvedURL)
    let resolved = try JSONDecoder().decode(PackageResolved.self, from: resolvedData)
    let resolvedVersion = try resolvedVersion(for: dependency, in: resolved)

    var syncSummaries: [String] = []
    for rule in dependency.syncs {
        let isRequired = rule.required ?? true

        switch rule.kind {
        case .files:
            guard let paths = rule.paths, !paths.isEmpty else {
                throw ScriptError.invalidRule("The 'files' rule for \(dependencyIdentity) is missing 'paths'.")
            }

            for relativePath in paths {
                let fileURL = repoRoot.appendingPathComponent(relativePath)
                let matches = try syncFile(
                    at: fileURL,
                    pattern: rule.pattern,
                    replacementTemplate: rule.replacement,
                    resolvedVersion: resolvedVersion,
                    requireMatch: isRequired
                )

                syncSummaries.append("\(relativePath): \(matches) replacement(s)")
            }

        case .tree:
            guard let root = rule.root else {
                throw ScriptError.invalidRule("The 'tree' rule for \(dependencyIdentity) is missing 'root'.")
            }

            let rootURL = repoRoot.appendingPathComponent(root)
            let extensions = Set((rule.fileExtensions ?? []).map { $0.lowercased() })
            let fileURLs = filesUnderRoot(rootURL: rootURL, allowedExtensions: extensions)

            var matchedFiles = 0
            var totalMatches = 0
            for fileURL in fileURLs {
                let matches = try syncFile(
                    at: fileURL,
                    pattern: rule.pattern,
                    replacementTemplate: rule.replacement,
                    resolvedVersion: resolvedVersion,
                    requireMatch: false
                )
                if matches > 0 {
                    matchedFiles += 1
                    totalMatches += matches
                }
            }

            guard totalMatches > 0 || !isRequired else {
                throw ScriptError.noTreeMatches(root: root, pattern: rule.pattern)
            }

            if totalMatches > 0 {
                syncSummaries.append("\(root): \(matchedFiles) file(s), \(totalMatches) replacement(s)")
            }
        }
    }

    print("Declared \(dependencyIdentity) requirement: \(requestedVersion)")
    print("Resolved \(dependencyIdentity) version: \(resolvedVersion)")
    if syncSummaries.isEmpty {
        print("No mirrored version strings are configured for \(dependencyIdentity).")
    } else {
        print("Synchronized mirrored version strings:")
        for summary in syncSummaries {
            print("- \(summary)")
        }
    }
    print("Next verification step: swift build && swift run FluidTranscriptionCLI version")
    print("Note: this script only updates package pins and mirrored version metadata. Upstream API changes still need code review.")
}

do {
    try main()
} catch {
    let message: String
    if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
        message = description
    } else {
        message = String(describing: error)
    }

    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}