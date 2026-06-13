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

        // XcodeProj always stamps an explicit `name`. When it just duplicates the
        // last path component, drop it so we emit the canonical
        // `path = <filename>; sourceTree = "<group>"` reference Xcode expects.
        if let refPath = fileRef.path, Path(refPath).lastComponent == fileRef.name {
            fileRef.name = nil
        }

        // Post-add validation. The file reference itself almost always resolves back
        // to the right file (a `../..` bounce still resolves — which is exactly why
        // xcodebuild tolerated the original corruption). The signal that actually
        // matters is whether the containing group resolves to a folder that exists on
        // disk: a path-based group pointing at a non-existent folder is what Xcode
        // renders in red. Warn on that so a non-canonical placement isn't silent.
        var warning = ""
        if let groupFolder = try? parentGroup.fullPath(sourceRoot: sourceRoot),
           !groupFolder.exists {
            warning = " ⚠️ Warning: group resolves to '\(groupFolder.string)', which does not exist on disk — the file may appear red in Xcode. Pass --group matching the file's on-disk location, or use a virtual group."
        }

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
        return .init(content: [.text("Added '\(absFilePath.lastComponent)' to target '\(targetName)' [\(phaseType)] in group '\(parentGroup.name ?? parentGroup.path ?? "root")'.\(warning)")])
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

        // The file's on-disk directory, as components relative to the source root.
        let fileDirComponents = onDiskComponents(of: filePath.parent(), under: sourceRoot)

        // Decide which group components to materialize, walking from the main group.
        let targetComponents: [String]
        if let groupPath {
            let requested = groupPath.split(separator: "/").map(String.init)
            // If the requested path is the tail of the file's real on-disk location,
            // expand it to the full path so we reuse the existing container groups
            // instead of forging a phantom tree at the root. e.g. a requested
            // "Canvas/Paper" for a file under "Siena/Canvas/Paper" resolves Canvas to
            // the real group nested under Siena and only creates the missing leaf.
            if isSuffix(requested, of: fileDirComponents) {
                targetComponents = fileDirComponents
            } else {
                targetComponents = requested
            }
        } else {
            // No group given: mirror the on-disk location.
            targetComponents = fileDirComponents
        }

        if targetComponents.isEmpty {
            return mainGroup
        }

        var current = mainGroup
        for component in targetComponents {
            if let match = GroupHelpers.childGroup(of: current, named: component, sourceRoot: sourceRoot) {
                current = match
            } else {
                let newGroups = try current.addGroup(named: component)
                guard let newGroup = newGroups.first else {
                    throw NSError(domain: "xcpmcp", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create group '\(component)'"])
                }
                pbxproj.add(object: newGroup)
                current = newGroup
            }
        }

        return current
    }

    /// Components of `directory` relative to `sourceRoot`, or [] if not contained within it.
    private static func onDiskComponents(of directory: Path, under sourceRoot: Path) -> [String] {
        let dir = directory.absolute().string
        let root = sourceRoot.absolute().string
        if dir == root { return [] }
        guard dir.hasPrefix(root + "/") else { return [] }
        return String(dir.dropFirst(root.count + 1)).split(separator: "/").map(String.init)
    }

    /// Whether `suffix` is a non-empty trailing run of `array`.
    private static func isSuffix(_ suffix: [String], of array: [String]) -> Bool {
        guard !suffix.isEmpty, suffix.count <= array.count else { return false }
        return Array(array.suffix(suffix.count)) == suffix
    }
}
