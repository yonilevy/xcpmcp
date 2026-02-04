import Foundation
import MCP
import PathKit
import XcodeProj

enum RemoveGroupHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let groupPath = params.arguments?["group"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: group")], isError: true)
        }

        let recursive = params.arguments?["recursive"]?.boolValue ?? false

        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let result = try GroupHelpers.findGroupWithParent(pbxproj: pbxproj, groupPath: groupPath) else {
            return .init(content: [.text("Group '\(groupPath)' not found.")], isError: true)
        }

        let group = result.group
        let parent = result.parent

        if !recursive && !group.children.isEmpty {
            return .init(content: [.text("Group '\(groupPath)' is not empty. Use recursive=true to remove it and all its children.")], isError: true)
        }

        if recursive {
            removeChildrenRecursively(group: group, pbxproj: pbxproj)
        }

        // Remove from parent
        parent.children.removeAll { $0 == group }
        pbxproj.delete(object: group)

        try xcodeproj.write(path: projPath)

        return .init(content: [.text("Removed group '\(groupPath)'.")])
    }

    private static func removeChildrenRecursively(group: PBXGroup, pbxproj: PBXProj) {
        for child in group.children {
            if let subGroup = child as? PBXGroup {
                removeChildrenRecursively(group: subGroup, pbxproj: pbxproj)
                pbxproj.delete(object: subGroup)
            } else if let fileRef = child as? PBXFileReference {
                // Remove build file entries
                let buildFiles = pbxproj.buildFiles.filter { $0.file == fileRef }
                for buildFile in buildFiles {
                    // Remove from build phases
                    for target in pbxproj.nativeTargets {
                        for phase in target.buildPhases {
                            phase.files?.removeAll { $0 == buildFile }
                        }
                    }
                    pbxproj.delete(object: buildFile)
                }
                pbxproj.delete(object: fileRef)
            }
        }
        group.children.removeAll()
    }
}
