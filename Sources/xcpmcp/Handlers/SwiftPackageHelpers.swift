import Foundation
import MCP
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
}
