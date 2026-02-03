import Foundation
import MCP
import PathKit
import XcodeProj

enum ListGroupsHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }

        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        guard let rootProject = try? xcodeproj.pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            return .init(content: [.text("Could not find root project or main group.")], isError: true)
        }

        var lines: [String] = []
        buildGroupTree(group: mainGroup, indent: "", lines: &lines)

        if lines.isEmpty {
            return .init(content: [.text("No groups found.")])
        }

        return .init(content: [.text(lines.joined(separator: "\n"))])
    }

    private static func buildGroupTree(group: PBXGroup, indent: String, lines: inout [String]) {
        let name = group.name ?? group.path ?? "(root)"
        lines.append("\(indent)\(name)/")

        for child in group.children {
            if let subGroup = child as? PBXGroup {
                buildGroupTree(group: subGroup, indent: indent + "  ", lines: &lines)
            } else if let fileRef = child as? PBXFileReference {
                let fileName = fileRef.name ?? fileRef.path ?? "unknown"
                lines.append("\(indent)  \(fileName)")
            }
        }
    }
}
