import Foundation
import MCP
import PathKit
import XcodeProj

enum MoveFileHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let filePath = params.arguments?["file_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: file_path")], isError: true)
        }
        guard let toGroup = params.arguments?["to_group"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: to_group")], isError: true)
        }

        let projPath = Path(projectPath)
        let sourceRoot = projPath.parent()
        let absFilePath = Path(filePath)

        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        // Find the file reference
        guard let fileRef = GroupHelpers.findFileReference(pbxproj: pbxproj, filePath: absFilePath, sourceRoot: sourceRoot) else {
            return .init(content: [.text("File '\(filePath)' not found in project.")], isError: true)
        }

        // Remove from current parent group
        if let parent = fileRef.parent as? PBXGroup {
            parent.children.removeAll { $0 == fileRef }
        }

        // Find or create destination group
        let destGroup = try GroupHelpers.findOrCreateGroup(pbxproj: pbxproj, groupPath: toGroup, sourceRoot: sourceRoot)

        // Add to destination group
        destGroup.children.append(fileRef)
        fileRef.parent = destGroup

        // A `<group>`-relative reference's `path` is interpreted relative to its
        // parent group, so reparenting without recomputing it silently re-roots the
        // file under the destination group's folder (red/misplaced in Xcode, even
        // though the file never moved on disk). Recompute the path so the reference
        // keeps pointing at the same on-disk file.
        if fileRef.sourceTree == .group,
           let destFolder = try? destGroup.fullPath(sourceRoot: sourceRoot) {
            fileRef.path = GroupHelpers.relativePath(from: destFolder, to: absFilePath)
            // Drop the now-redundant explicit name to keep the reference canonical.
            if let refPath = fileRef.path, Path(refPath).lastComponent == fileRef.name {
                fileRef.name = nil
            }
        }

        try xcodeproj.write(path: projPath)

        return .init(content: [.text("Moved '\(absFilePath.lastComponent)' to group '\(toGroup)'.")])
    }
}
