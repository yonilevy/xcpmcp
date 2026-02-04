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

    /// Navigate an existing group hierarchy by path. Does not create missing groups.
    static func findGroup(pbxproj: PBXProj, groupPath: String) throws -> PBXGroup? {
        guard let rootProject = try pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            return nil
        }

        let components = groupPath.split(separator: "/").map(String.init)
        var current = mainGroup
        for component in components {
            if let existing = current.group(named: component)
                ?? current.children.compactMap({ $0 as? PBXGroup }).first(where: { $0.path == component }) {
                current = existing
            } else {
                return nil
            }
        }
        return current
    }

    /// Navigate group hierarchy, creating missing groups along the way.
    static func findOrCreateGroup(pbxproj: PBXProj, groupPath: String) throws -> PBXGroup {
        guard let rootProject = try pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            throw NSError(domain: "xcpmcp", code: 1, userInfo: [NSLocalizedDescriptionKey: "No main group found"])
        }

        let components = groupPath.split(separator: "/").map(String.init)
        var current = mainGroup
        for component in components {
            if let existing = current.group(named: component)
                ?? current.children.compactMap({ $0 as? PBXGroup }).first(where: { $0.path == component }) {
                current = existing
            } else {
                let newGroups = try current.addGroup(named: component)
                if let newGroup = newGroups.first {
                    pbxproj.add(object: newGroup)
                    current = newGroup
                }
            }
        }
        return current
    }

    /// Find a group and its parent. Returns (group, parent) or nil.
    static func findGroupWithParent(pbxproj: PBXProj, groupPath: String) throws -> (group: PBXGroup, parent: PBXGroup)? {
        guard let rootProject = try pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            return nil
        }

        let components = groupPath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return nil }

        var current = mainGroup
        for (i, component) in components.enumerated() {
            if let existing = current.group(named: component)
                ?? current.children.compactMap({ $0 as? PBXGroup }).first(where: { $0.path == component }) {
                if i == components.count - 1 {
                    return (group: existing, parent: current)
                }
                current = existing
            } else {
                return nil
            }
        }
        return nil
    }
}
