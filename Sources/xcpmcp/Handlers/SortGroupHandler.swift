import Foundation
import MCP
import PathKit
import XcodeProj

enum SortGroupHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let groupPath = params.arguments?["group"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: group")], isError: true)
        }

        let recursive = params.arguments?["recursive"]?.boolValue ?? false

        let projPath = Path(projectPath)
        let sourceRoot = projPath.parent()
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let group = try GroupHelpers.findGroup(pbxproj: pbxproj, groupPath: groupPath, sourceRoot: sourceRoot) else {
            return .init(content: [.text("Group '\(groupPath)' not found.")], isError: true)
        }

        let sortedCount = sortGroup(group, recursive: recursive)

        try xcodeproj.write(path: projPath)

        let scope = recursive ? "recursively sorted \(sortedCount) group(s)" : "sorted 1 group"
        return .init(content: [.text("Sorted '\(groupPath)' (\(scope)).")])
    }

    private static func sortKey(_ element: PBXFileElement) -> String {
        element.name ?? element.path ?? ""
    }

    @discardableResult
    private static func sortGroup(_ group: PBXGroup, recursive: Bool) -> Int {
        var count = 1

        if recursive {
            for child in group.children {
                if let childGroup = child as? PBXGroup {
                    count += sortGroup(childGroup, recursive: true)
                }
            }
        }

        let groups = group.children.filter { $0 is PBXGroup }
            .sorted { sortKey($0).localizedCaseInsensitiveCompare(sortKey($1)) == .orderedAscending }
        let files = group.children.filter { !($0 is PBXGroup) }
            .sorted { sortKey($0).localizedCaseInsensitiveCompare(sortKey($1)) == .orderedAscending }

        group.children = groups + files

        return count
    }
}
