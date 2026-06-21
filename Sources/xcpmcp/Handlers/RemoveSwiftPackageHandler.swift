import Foundation
import MCP
import PathKit
import XcodeProj

enum RemoveSwiftPackageHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }

        let localPath = params.arguments?["local_path"]?.stringValue
        let url = params.arguments?["url"]?.stringValue
        guard (localPath == nil) != (url == nil) else {
            return .init(content: [.text("Provide exactly one of 'local_path' or 'url' to identify the package to remove.")], isError: true)
        }

        let productFilter = SwiftPackageHelpers.products(from: params.arguments?["products"])
        let targetName = params.arguments?["target"]?.stringValue

        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let rootProject = try pbxproj.rootProject() else {
            return .init(content: [.text("No root project found.")], isError: true)
        }

        // Locate the package reference and a predicate matching its product dependencies.
        let remoteRef: XCRemoteSwiftPackageReference?
        let localRef: XCLocalSwiftPackageReference?      // packageReference style
        let localFolderRef: PBXFileReference?            // folderReference style
        let identity: String
        let matchesPackage: (XCSwiftPackageProductDependency) -> Bool

        if let url {
            guard let ref = rootProject.remotePackages.first(where: { $0.repositoryURL == url }) else {
                return .init(content: [.text("Remote package '\(url)' not found in this project.")], isError: true)
            }
            remoteRef = ref
            localRef = nil
            localFolderRef = nil
            identity = url
            matchesPackage = { $0.package == ref }
        } else {
            let relativePath = localPath!
            identity = relativePath
            remoteRef = nil
            // Local product dependencies have no link back to their package, so they're
            // matched by being package-less (optionally narrowed by the product filter) —
            // regardless of whether the package is declared as a package reference or a
            // folder reference.
            matchesPackage = { $0.package == nil }
            if let ref = rootProject.localPackages.first(where: { $0.relativePath == relativePath }) {
                localRef = ref
                localFolderRef = nil
            } else if let folder = pbxproj.fileReferences.first(where: { $0.path == relativePath && $0.lastKnownFileType == "wrapper" }) {
                localRef = nil
                localFolderRef = folder
            } else {
                return .init(content: [.text("Local package '\(relativePath)' not found in this project.")], isError: true)
            }
        }

        // Final predicate: belongs to this package and, if a product filter was given,
        // is one of the named products.
        func shouldRemove(_ dep: XCSwiftPackageProductDependency) -> Bool {
            guard matchesPackage(dep) else { return false }
            return productFilter.isEmpty || productFilter.contains(dep.productName)
        }

        let targets: [PBXNativeTarget]
        if let targetName {
            guard let t = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
                return .init(content: [.text("Target '\(targetName)' not found.")], isError: true)
            }
            targets = [t]
        } else {
            targets = pbxproj.nativeTargets
        }

        var unlinked: [String] = []
        var detachedDeps: [XCSwiftPackageProductDependency] = []

        // Unlink from each in-scope target: drop the dependency and its framework build file.
        for target in targets {
            let deps = target.packageProductDependencies ?? []
            let toRemove = deps.filter(shouldRemove)
            guard !toRemove.isEmpty else { continue }

            target.packageProductDependencies = deps.filter { dep in !toRemove.contains { $0 === dep } }

            if let frameworks = try target.frameworksBuildPhase() {
                let buildFilesToRemove = (frameworks.files ?? []).filter { bf in
                    guard let product = bf.product else { return false }
                    return toRemove.contains { $0 === product }
                }
                frameworks.files = (frameworks.files ?? []).filter { bf in !buildFilesToRemove.contains { $0 === bf } }
                for bf in buildFilesToRemove { pbxproj.delete(object: bf) }
            }

            detachedDeps.append(contentsOf: toRemove)
            unlinked.append(contentsOf: toRemove.map { "\(target.name)/\($0.productName)" })
        }

        // Delete dependency objects that are now linked by no remaining target. (XcodeProj
        // serializes every object it holds, so detached-but-undeleted deps would linger.)
        let stillLinked = SwiftPackageHelpers.allProductDependencies(pbxproj)
        for dep in detachedDeps where !stillLinked.contains(where: { $0 === dep }) {
            pbxproj.delete(object: dep)
        }

        // Remove the package reference itself only when removing the whole package
        // (no target scope) and nothing still links it.
        var removedPackageRef = false
        if targetName == nil {
            let remaining = SwiftPackageHelpers.allProductDependencies(pbxproj)
            if let remoteRef, !remaining.contains(where: { $0.package == remoteRef }) {
                rootProject.remotePackages = rootProject.remotePackages.filter { $0 !== remoteRef }
                pbxproj.delete(object: remoteRef)
                removedPackageRef = true
            } else if let localRef {
                rootProject.localPackages = rootProject.localPackages.filter { $0 !== localRef }
                pbxproj.delete(object: localRef)
                removedPackageRef = true
            } else if let localFolderRef {
                // Detach the folder wrapper from whichever group holds it, then delete it.
                for group in pbxproj.groups {
                    group.children.removeAll { $0 === localFolderRef }
                }
                pbxproj.delete(object: localFolderRef)
                removedPackageRef = true
            }
        }

        if unlinked.isEmpty && !removedPackageRef {
            let scope = targetName.map { " in target '\($0)'" } ?? ""
            let prods = productFilter.isEmpty ? "" : " with products \(productFilter.joined(separator: ", "))"
            return .init(content: [.text("Nothing matched for package '\(identity)'\(prods)\(scope).")], isError: true)
        }

        try xcodeproj.write(path: projPath)

        var parts: [String] = []
        if !unlinked.isEmpty {
            parts.append("Unlinked \(unlinked.map { "'\($0)'" }.joined(separator: ", ")).")
        }
        if removedPackageRef {
            parts.append("Removed package reference '\(identity)'.")
        } else if targetName == nil {
            parts.append("Package reference '\(identity)' kept (still in use).")
        }
        return .init(content: [.text(parts.joined(separator: " "))])
    }
}
