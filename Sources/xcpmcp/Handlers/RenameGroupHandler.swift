import Foundation
import MCP
import PathKit
import XcodeProj

enum RenameGroupHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let groupPath = params.arguments?["group"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: group")], isError: true)
        }
        guard let newName = params.arguments?["new_name"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: new_name")], isError: true)
        }

        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let group = try GroupHelpers.findGroup(pbxproj: pbxproj, groupPath: groupPath) else {
            return .init(content: [.text("Group '\(groupPath)' not found.")], isError: true)
        }

        let oldName = group.name ?? group.path ?? groupPath

        // Update whichever property is set
        if group.name != nil {
            group.name = newName
        }
        if group.path != nil {
            group.path = newName
        }
        // If neither was set, set name
        if group.name == nil && group.path == nil {
            group.name = newName
        }

        try xcodeproj.write(path: projPath)

        return .init(content: [.text("Renamed group '\(oldName)' to '\(newName)'.")])
    }
}
