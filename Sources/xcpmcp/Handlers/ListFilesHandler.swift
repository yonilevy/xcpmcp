import Foundation
import MCP
import PathKit
import XcodeProj

enum ListFilesHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }

        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)
        let targetName = params.arguments?["target"]?.stringValue

        if let targetName {
            guard let target = xcodeproj.pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
                return .init(content: [.text("Target '\(targetName)' not found.")], isError: true)
            }

            var lines: [String] = []
            for buildPhase in target.buildPhases {
                let phaseName = buildPhaseName(buildPhase)
                if let files = buildPhase.files {
                    for buildFile in files {
                        let filePath = buildFile.file?.path ?? buildFile.file?.name ?? "unknown"
                        lines.append("[\(phaseName)] \(filePath)")
                    }
                }
            }

            if lines.isEmpty {
                return .init(content: [.text("No files in target '\(targetName)'.")])
            }
            return .init(content: [.text(lines.joined(separator: "\n"))])
        } else {
            let sourceRoot = path.parent()
            var lines: [String] = []
            for fileRef in xcodeproj.pbxproj.fileReferences {
                let filePath = (try? fileRef.fullPath(sourceRoot: sourceRoot))?.string ?? fileRef.path ?? fileRef.name ?? "unknown"
                lines.append(filePath)
            }

            if lines.isEmpty {
                return .init(content: [.text("No files found in project.")])
            }
            return .init(content: [.text(lines.joined(separator: "\n"))])
        }
    }

    private static func buildPhaseName(_ phase: PBXBuildPhase) -> String {
        switch phase {
        case is PBXSourcesBuildPhase: return "Sources"
        case is PBXResourcesBuildPhase: return "Resources"
        case is PBXFrameworksBuildPhase: return "Frameworks"
        case is PBXHeadersBuildPhase: return "Headers"
        case is PBXCopyFilesBuildPhase: return "CopyFiles"
        case is PBXShellScriptBuildPhase: return "ShellScript"
        default: return "Other"
        }
    }
}
