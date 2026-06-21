import Foundation
import MCP
import PathKit
import XcodeProj

enum ListSwiftPackagesHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }

        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let rootProject = try pbxproj.rootProject() else {
            return .init(content: [.text("No root project found.")], isError: true)
        }

        var lines: [String] = []

        let remote = rootProject.remotePackages
        let local = rootProject.localPackages
        // Folder-reference local packages aren't XCLocalSwiftPackageReferences — they're
        // package wrappers in the group tree, detected heuristically by file type.
        let folderRefs = pbxproj.fileReferences
            .filter { $0.lastKnownFileType == "wrapper" }
            .sorted { ($0.path ?? "") < ($1.path ?? "") }
        if remote.isEmpty && local.isEmpty && folderRefs.isEmpty {
            return .init(content: [.text("No Swift packages declared in this project.")])
        }

        lines.append("Declared packages:")
        for pkg in remote.sorted(by: { ($0.repositoryURL ?? "") < ($1.repositoryURL ?? "") }) {
            lines.append("  remote: \(pkg.repositoryURL ?? "(no url)") (\(SwiftPackageHelpers.describe(pkg.versionRequirement)))")
        }
        for pkg in local.sorted(by: { $0.relativePath < $1.relativePath }) {
            lines.append("  local:  \(pkg.relativePath) (package reference)")
        }
        for ref in folderRefs {
            lines.append("  local:  \(ref.path ?? ref.name ?? "?") (folder reference)")
        }

        // Linked products, grouped by target. A remote dependency points back at its
        // package; a local dependency has no package link, so we label it "local".
        lines.append("")
        lines.append("Linked products by target:")
        var anyLink = false
        for target in pbxproj.nativeTargets.sorted(by: { $0.name < $1.name }) {
            let deps = target.packageProductDependencies ?? []
            guard !deps.isEmpty else { continue }
            anyLink = true
            lines.append("  \(target.name):")
            for dep in deps.sorted(by: { $0.productName < $1.productName }) {
                if let pkg = dep.package {
                    lines.append("    \(dep.productName) (remote → \(pkg.repositoryURL ?? "?"))")
                } else {
                    lines.append("    \(dep.productName) (local)")
                }
            }
        }
        if !anyLink {
            lines.append("  (none)")
        }

        return .init(content: [.text(lines.joined(separator: "\n"))])
    }
}
