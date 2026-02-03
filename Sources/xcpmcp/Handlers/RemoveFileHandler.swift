import Foundation
import MCP
import PathKit
import XcodeProj

enum RemoveFileHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let filePath = params.arguments?["file_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: file_path")], isError: true)
        }

        let projPath = Path(projectPath)
        let sourceRoot = projPath.parent()
        let absFilePath = Path(filePath)

        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        // Find the file reference
        guard let fileRef = findFileReference(pbxproj: pbxproj, filePath: absFilePath, sourceRoot: sourceRoot) else {
            return .init(content: [.text("File '\(filePath)' not found in project.")], isError: true)
        }

        let targetName = params.arguments?["target"]?.stringValue

        // Determine which targets to remove from
        let targets: [PBXNativeTarget]
        if let targetName {
            guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
                return .init(content: [.text("Target '\(targetName)' not found.")], isError: true)
            }
            targets = [target]
        } else {
            targets = pbxproj.nativeTargets
        }

        // Remove build file references from build phases
        for target in targets {
            for buildPhase in target.buildPhases {
                buildPhase.files?.removeAll { buildFile in
                    buildFile.file == fileRef
                }
            }
        }

        // Remove PBXBuildFile objects from pbxproj
        let buildFiles = pbxproj.buildFiles.filter { $0.file == fileRef }
        for buildFile in buildFiles {
            pbxproj.delete(object: buildFile)
        }

        // Remove from parent group
        if let parent = fileRef.parent as? PBXGroup {
            parent.children.removeAll { $0 == fileRef }
        }

        // Remove file reference
        pbxproj.delete(object: fileRef)

        try xcodeproj.write(path: projPath)

        let scope = targetName.map { "target '\($0)'" } ?? "all targets"
        return .init(content: [.text("Removed '\(absFilePath.lastComponent)' from \(scope).")])
    }

    private static func findFileReference(pbxproj: PBXProj, filePath: Path, sourceRoot: Path) -> PBXFileReference? {
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
}
