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
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let result = try GroupHelpers.findGroupWithParent(pbxproj: pbxproj, groupPath: groupPath) else {
            return .init(content: [.text("Group '\(groupPath)' not found.")], isError: true)
        }

        let group = result.group
        let oldParent = result.parent

        // Find or create destination group
        let destGroup = try GroupHelpers.findOrCreateGroup(pbxproj: pbxproj, groupPath: toGroup)

        // Remove from old parent
        oldParent.children.removeAll { $0 == group }

        // Add to new parent
        destGroup.children.append(group)

        try xcodeproj.write(path: projPath)

        let groupName = group.name ?? group.path ?? groupPath
        return .init(content: [.text("Moved group '\(groupName)' to '\(toGroup)'.")])
    }
}
