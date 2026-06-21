import Foundation
import MCP
import PathKit
import XcodeProj

enum SwiftPackageHelpers {
    enum PkgError: Error, CustomStringConvertible {
        case message(String)
        var description: String {
            switch self { case let .message(m): return m }
        }
    }

    /// Parse the `requirement` argument (an object) into a XcodeProj version
    /// requirement. Accepts a `kind` plus the fields that kind needs. Single-version
    /// kinds accept `minimum` or `version` interchangeably for convenience.
    static func parseRequirement(_ value: Value?) throws -> XCRemoteSwiftPackageReference.VersionRequirement {
        guard let obj = value?.objectValue, let kind = obj["kind"]?.stringValue else {
            throw PkgError.message("A remote package needs a 'requirement' object with a 'kind' (upToNextMajor, upToNextMinor, exactVersion, versionRange, branch, or revision).")
        }
        func field(_ keys: String...) -> String? {
            for k in keys { if let s = obj[k]?.stringValue, !s.isEmpty { return s } }
            return nil
        }
        switch kind {
        case "upToNextMajor", "upToNextMajorVersion":
            guard let v = field("minimum", "version") else { throw PkgError.message("requirement kind 'upToNextMajor' needs 'minimum'.") }
            return .upToNextMajorVersion(v)
        case "upToNextMinor", "upToNextMinorVersion":
            guard let v = field("minimum", "version") else { throw PkgError.message("requirement kind 'upToNextMinor' needs 'minimum'.") }
            return .upToNextMinorVersion(v)
        case "exactVersion", "exact":
            guard let v = field("version", "minimum") else { throw PkgError.message("requirement kind 'exactVersion' needs 'version'.") }
            return .exact(v)
        case "versionRange", "range":
            guard let from = field("minimum", "from"), let to = field("maximum", "to") else {
                throw PkgError.message("requirement kind 'versionRange' needs 'minimum' and 'maximum'.")
            }
            return .range(from: from, to: to)
        case "branch":
            guard let b = field("branch", "version", "minimum") else { throw PkgError.message("requirement kind 'branch' needs 'branch'.") }
            return .branch(b)
        case "revision":
            guard let r = field("revision", "version", "minimum") else { throw PkgError.message("requirement kind 'revision' needs 'revision'.") }
            return .revision(r)
        default:
            throw PkgError.message("Unknown requirement kind '\(kind)'. Use upToNextMajor, upToNextMinor, exactVersion, versionRange, branch, or revision.")
        }
    }

    /// Human-readable description of a version requirement, for tool output.
    static func describe(_ requirement: XCRemoteSwiftPackageReference.VersionRequirement?) -> String {
        guard let requirement else { return "unspecified" }
        switch requirement {
        case let .upToNextMajorVersion(v): return "upToNextMajor from \(v)"
        case let .upToNextMinorVersion(v): return "upToNextMinor from \(v)"
        case let .exact(v): return "exactly \(v)"
        case let .range(from, to): return "\(from) ..< \(to)"
        case let .branch(b): return "branch \(b)"
        case let .revision(r): return "revision \(r)"
        }
    }

    /// All package product dependencies reachable from the project's native targets.
    /// (XcodeProj's `objects` collection is module-internal, so we enumerate via the
    /// targets that link them — which is where every real product dependency lives.)
    static func allProductDependencies(_ pbxproj: PBXProj) -> [XCSwiftPackageProductDependency] {
        pbxproj.nativeTargets.flatMap { $0.packageProductDependencies ?? [] }
    }

    /// Read the `products` argument, accepting either an array of strings or a single
    /// comma-separated string (the CLI passes the latter).
    static func products(from value: Value?) -> [String] {
        if let arr = value?.arrayValue {
            return arr.compactMap { $0.stringValue }.filter { !$0.isEmpty }
        }
        if let single = value?.stringValue {
            return single.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        return []
    }

    /// Resolve a local package's library product names by evaluating its manifest. Local
    /// product dependencies carry no link back to their package, so this lets removal
    /// target exactly the right products instead of every package-less dependency.
    /// Returns nil if the manifest can't be evaluated (no swift toolchain, missing/invalid
    /// package, etc.), in which case the caller falls back to a safe strategy.
    static func localPackageProductNames(packagePath: Path) -> [String]? {
        guard packagePath.exists else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "package", "dump-package", "--package-path", packagePath.string]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]] else {
            return nil
        }
        let names = products.compactMap { $0["name"] as? String }
        return names.isEmpty ? nil : names
    }

    /// Work around an XcodeProj bug: `PBXObjects.delete` has no branch for
    /// `XCLocalSwiftPackageReference`, so deleting one removes its `packageReferences`
    /// entry but leaves the now-unreferenced object definition in the file (which trips up
    /// tools that parse the pbxproj). After writing, strip any `XCLocalSwiftPackageReference`
    /// object block whose id appears nowhere else in the file — these objects are only ever
    /// referenced from `packageReferences`, so an id that occurs once (its own definition)
    /// is a genuine orphan. Also cleans up orphans left behind by earlier buggy runs.
    static func stripOrphanedLocalPackageReferences(pbxprojPath: Path) {
        guard let text = try? String(contentsOfFile: pbxprojPath.string, encoding: .utf8) else { return }
        var lines = text.components(separatedBy: "\n")
        var removeRanges: [(start: Int, end: Int)] = []
        var i = 0
        while i < lines.count {
            guard let id = blockStartID(lines[i]) else { i += 1; continue }
            var j = i + 1
            var isLocalPackageRef = false
            while j < lines.count, lines[j] != "\t\t};" {
                if lines[j].contains("isa = XCLocalSwiftPackageReference;") { isLocalPackageRef = true }
                j += 1
            }
            let end = min(j, lines.count - 1)
            if isLocalPackageRef, occurrences(of: id, in: text) <= 1 {
                removeRanges.append((i, end))
            }
            i = end + 1
        }
        guard !removeRanges.isEmpty else { return }
        for range in removeRanges.sorted(by: { $0.start > $1.start }) {
            lines.removeSubrange(range.start...range.end)
        }
        try? lines.joined(separator: "\n").write(toFile: pbxprojPath.string, atomically: true, encoding: String.Encoding.utf8)
    }

    /// If `line` opens a multi-line pbxproj object block ("\t\t<24-hex id> ... = {"),
    /// return its object id.
    private static func blockStartID(_ line: String) -> String? {
        guard line.hasPrefix("\t\t"), line.hasSuffix("= {") else { return nil }
        let token = line.dropFirst(2).prefix { $0 != " " }
        guard token.count == 24, token.allSatisfy({ $0.isHexDigit }) else { return nil }
        return String(token)
    }

    private static func occurrences(of needle: String, in haystack: String) -> Int {
        var count = 0
        var searchStart = haystack.startIndex
        while let found = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            count += 1
            searchStart = found.upperBound
        }
        return count
    }
}
