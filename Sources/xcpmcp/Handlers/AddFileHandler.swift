import Foundation
import MCP
import PathKit
import XcodeProj

enum AddFileHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let filePath = params.arguments?["file_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: file_path")], isError: true)
        }
        guard let targetName = params.arguments?["target"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: target")], isError: true)
        }

        let projPath = Path(projectPath)
        let absFilePath = Path(filePath)
        let sourceRoot = projPath.parent()

        guard absFilePath.exists else {
            return .init(content: [.text("File does not exist: \(filePath)")], isError: true)
        }

        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        // Find target
        guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
            return .init(content: [.text("Target '\(targetName)' not found.")], isError: true)
        }

        // Determine group
        let groupPath = params.arguments?["group"]?.stringValue
        let parentGroup = try findOrCreateGroup(
            pbxproj: pbxproj,
            groupPath: groupPath,
            filePath: absFilePath,
            sourceRoot: sourceRoot
        )

        // Add file reference to group
        let fileRef = try parentGroup.addFile(
            at: absFilePath,
            sourceTree: .group,
            sourceRoot: sourceRoot,
            override: false,
            validatePresence: false
        )

        // Determine build phase
        let fileTypeParam = params.arguments?["file_type"]?.stringValue
        let isSource = isSourceFile(path: absFilePath, explicitType: fileTypeParam)

        if isSource {
            if let sourcesPhase = try target.sourcesBuildPhase() {
                _ = try sourcesPhase.add(file: fileRef)
            } else {
                // Create sources build phase if missing
                let sourcesPhase = PBXSourcesBuildPhase(files: [])
                pbxproj.add(object: sourcesPhase)
                target.buildPhases.append(sourcesPhase)
                _ = try sourcesPhase.add(file: fileRef)
            }
        } else {
            if let resourcesPhase = try target.resourcesBuildPhase() {
                _ = try resourcesPhase.add(file: fileRef)
            } else {
                let resourcesPhase = PBXResourcesBuildPhase(files: [])
                pbxproj.add(object: resourcesPhase)
                target.buildPhases.append(resourcesPhase)
                _ = try resourcesPhase.add(file: fileRef)
            }
        }

        try xcodeproj.write(path: projPath)

        let phaseType = isSource ? "Sources" : "Resources"
        return .init(content: [.text("Added '\(absFilePath.lastComponent)' to target '\(targetName)' [\(phaseType)] in group '\(parentGroup.name ?? parentGroup.path ?? "root")'.")])
    }

    private static func isSourceFile(path: Path, explicitType: String?) -> Bool {
        if let explicitType {
            return explicitType == "source"
        }
        let ext = path.extension ?? ""
        let sourceExtensions: Set<String> = ["swift", "m", "mm", "c", "cc", "cpp", "cxx", "metal"]
        return sourceExtensions.contains(ext)
    }

    private static func findOrCreateGroup(
        pbxproj: PBXProj,
        groupPath: String?,
        filePath: Path,
        sourceRoot: Path
    ) throws -> PBXGroup {
        guard let rootProject = try pbxproj.rootProject(),
              let mainGroup = rootProject.mainGroup else {
            throw NSError(domain: "xcpmcp", code: 1, userInfo: [NSLocalizedDescriptionKey: "No main group found"])
        }

        let pathComponents: [String]
        if let groupPath {
            pathComponents = groupPath.split(separator: "/").map(String.init)
        } else {
            // Infer from file path relative to source root
            let relativePath = filePath.parent().string.replacingOccurrences(of: sourceRoot.string + "/", with: "")
            if relativePath == filePath.parent().string || relativePath.isEmpty {
                return mainGroup
            }
            pathComponents = relativePath.split(separator: "/").map(String.init)
        }

        var current = mainGroup
        for component in pathComponents {
            if let existing = current.group(named: component) ?? current.children.compactMap({ $0 as? PBXGroup }).first(where: { $0.path == component }) {
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
}
