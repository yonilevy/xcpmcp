import Foundation
import PathKit
import XcodeProj

enum GroupHelpers {
    /// Find a file reference by full path or filename.
    static func findFileReference(pbxproj: PBXProj, filePath: Path, sourceRoot: Path) -> PBXFileReference? {
        // Try matching by full path
        for fileRef in pbxproj.fileReferences {
            if let fullPath = try? fileRef.fullPath(sourceRoot: sourceRoot), fullPath == filePath {
                return fileRef
            }
        }
        // Try matching by path component
        let fileName = filePath.lastComponent
        for fileRef in pbxproj.fileReferences {
            if fileRef.path == filePath.string || fileRef.name == fileName || fileRef.path == fileName {
                return fileRef
            }
        }
        return nil
    }

    /// Find a child group of `parent` matching `component`. Prefers a child whose
    /// resolved on-disk folder matches the expected location (so a partial or
    /// attribute-divergent path still resolves to the real container instead of
    /// forging a phantom sibling), then falls back to a name/path attribute match.
    static func childGroup(of parent: PBXGroup, named component: String, sourceRoot: Path) -> PBXGroup? {
        let childGroups = parent.children.compactMap { $0 as? PBXGroup }
        if let expected = (try? parent.fullPath(sourceRoot: sourceRoot)).map({ ($0 + component).normalize() }),
           let match = childGroups.first(where: {
               guard let resolved = try? $0.fullPath(sourceRoot: sourceRoot) else { return false }
               return resolved.normalize() == expected
           }) {
            return match
        }
        return childGroups.first(where: { $0.name == component || $0.path == component })
    }

    /// Navigate an existing group hierarchy by path. Does not create missing groups.
    static func findGroup(pbxproj: PBXProj, groupPath: String, sourceRoot: Path) throws -> PBXGroup? {
        guard let rootProject = try pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            return nil
        }

        let components = groupPath.split(separator: "/").map(String.init)
        var current = mainGroup
        for component in components {
            guard let existing = childGroup(of: current, named: component, sourceRoot: sourceRoot) else {
                return nil
            }
            current = existing
        }
        return current
    }

    /// Navigate group hierarchy, creating missing groups along the way.
    static func findOrCreateGroup(pbxproj: PBXProj, groupPath: String, sourceRoot: Path) throws -> PBXGroup {
        guard let rootProject = try pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            throw NSError(domain: "xcpmcp", code: 1, userInfo: [NSLocalizedDescriptionKey: "No main group found"])
        }

        let components = groupPath.split(separator: "/").map(String.init)
        var current = mainGroup
        for component in components {
            if let existing = childGroup(of: current, named: component, sourceRoot: sourceRoot) {
                current = existing
            } else {
                let newGroups = try current.addGroup(named: component)
                guard let newGroup = newGroups.first else {
                    throw NSError(domain: "xcpmcp", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create group '\(component)'"])
                }
                pbxproj.add(object: newGroup)
                current = newGroup
            }
        }
        return current
    }

    /// Find a group and its parent. Returns (group, parent) or nil.
    static func findGroupWithParent(pbxproj: PBXProj, groupPath: String, sourceRoot: Path) throws -> (group: PBXGroup, parent: PBXGroup)? {
        guard let rootProject = try pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            return nil
        }

        let components = groupPath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return nil }

        var current = mainGroup
        for (i, component) in components.enumerated() {
            guard let existing = childGroup(of: current, named: component, sourceRoot: sourceRoot) else {
                return nil
            }
            if i == components.count - 1 {
                return (group: existing, parent: current)
            }
            current = existing
        }
        return nil
    }
}
