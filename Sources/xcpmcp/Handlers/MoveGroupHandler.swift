import Foundation
import MCP
import PathKit
import XcodeProj

enum MoveGroupHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let groupPath = params.arguments?["group"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: group")], isError: true)
        }
        guard let toGroup = params.arguments?["to_group"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: to_group")], isError: true)
        }

        let projPath = Path(projectPath)
        let sourceRoot = projPath.parent()
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let result = try GroupHelpers.findGroupWithParent(pbxproj: pbxproj, groupPath: groupPath, sourceRoot: sourceRoot) else {
            return .init(content: [.text("Group '\(groupPath)' not found.")], isError: true)
        }

        let group = result.group
        let oldParent = result.parent
        let displayName = group.name ?? group.path ?? groupPath

        // The group's real on-disk folder, captured before reparenting changes how it
        // would resolve.
        let groupFolder = try? group.fullPath(sourceRoot: sourceRoot)

        // Find or create destination group
        let destGroup = try GroupHelpers.findOrCreateGroup(pbxproj: pbxproj, groupPath: toGroup, sourceRoot: sourceRoot)

        // Remove from old parent
        oldParent.children.removeAll { $0 == group }

        // Add to new parent
        destGroup.children.append(group)
        group.parent = destGroup

        // A folder-backed group's `path` is relative to its parent, so reparenting
        // without recomputing it silently re-roots the group's entire subtree under
        // the destination folder (every descendant file then resolves to the wrong
        // place). Recompute the path so the group keeps pointing at its real folder.
        if group.sourceTree == .group, group.path != nil,
           let groupFolder,
           let destFolder = try? destGroup.fullPath(sourceRoot: sourceRoot) {
            group.path = GroupHelpers.relativePath(from: destFolder, to: groupFolder)
            if let path = group.path, Path(path).lastComponent == group.name {
                group.name = nil
            }
        }

        try xcodeproj.write(path: projPath)

        return .init(content: [.text("Moved group '\(displayName)' to '\(toGroup)'.")])
    }
}
