import Foundation
import MCP
import PathKit
import XcodeProj

enum AddSwiftPackageHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }
        guard let targetName = params.arguments?["target"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: target")], isError: true)
        }

        let localPath = params.arguments?["local_path"]?.stringValue
        let url = params.arguments?["url"]?.stringValue
        guard (localPath == nil) != (url == nil) else {
            return .init(content: [.text("Provide exactly one of 'local_path' (local package) or 'url' (remote package).")], isError: true)
        }

        let products = SwiftPackageHelpers.products(from: params.arguments?["products"])
        guard !products.isEmpty else {
            return .init(content: [.text("Missing required parameter: products (one or more library product names to link).")], isError: true)
        }

        let projPath = Path(projectPath)
        let xcodeproj = try XcodeProj(path: projPath)
        let pbxproj = xcodeproj.pbxproj

        guard let rootProject = try pbxproj.rootProject() else {
            return .init(content: [.text("No root project found.")], isError: true)
        }
        guard let target = pbxproj.nativeTargets.first(where: { $0.name == targetName }) else {
            return .init(content: [.text("Target '\(targetName)' not found.")], isError: true)
        }
        guard let frameworksPhase = try target.frameworksBuildPhase() else {
            return .init(content: [.text("Target '\(targetName)' has no Frameworks build phase to link the product into.")], isError: true)
        }

        // Resolve or create the package reference (idempotent on identity).
        var remoteRef: XCRemoteSwiftPackageReference?
        var localRef: XCLocalSwiftPackageReference?
        let identity: String
        let kindLabel: String

        do {
            if let url {
                identity = url
                kindLabel = "remote"
                let requirement = try SwiftPackageHelpers.parseRequirement(params.arguments?["requirement"])
                if let existing = rootProject.remotePackages.first(where: { $0.repositoryURL == url }) {
                    guard existing.versionRequirement == requirement else {
                        return .init(content: [.text("Package '\(url)' is already declared with a different version requirement (\(SwiftPackageHelpers.describe(existing.versionRequirement))). Remove it first or pass the matching requirement.")], isError: true)
                    }
                    remoteRef = existing
                } else {
                    let ref = XCRemoteSwiftPackageReference(repositoryURL: url, versionRequirement: requirement)
                    pbxproj.add(object: ref)
                    var packages = rootProject.remotePackages
                    packages.append(ref)
                    rootProject.remotePackages = packages
                    remoteRef = ref
                }
            } else {
                let relativePath = localPath!
                identity = relativePath
                kindLabel = "local"
                if Path(relativePath).isAbsolute {
                    return .init(content: [.text("local_path must be a relative path (relative to the .xcodeproj's directory), e.g. '../papergen'.")], isError: true)
                }

                let style = params.arguments?["local_style"]?.stringValue ?? "packageReference"
                switch style {
                case "packageReference":
                    // Modern form: an XCLocalSwiftPackageReference in packageReferences.
                    if let existing = rootProject.localPackages.first(where: { $0.relativePath == relativePath }) {
                        localRef = existing
                    } else {
                        let ref = XCLocalSwiftPackageReference(relativePath: relativePath)
                        pbxproj.add(object: ref)
                        var packages = rootProject.localPackages
                        packages.append(ref)
                        rootProject.localPackages = packages
                        localRef = ref
                    }
                case "folderReference":
                    // Legacy form: a PBXFileReference (package wrapper) in the group tree,
                    // with nothing in packageReferences. Matches projects that wire local
                    // packages by dragging the folder in. The product dependency below is
                    // identical to the packageReference form (productName-only).
                    let existing = pbxproj.fileReferences.first {
                        $0.path == relativePath && $0.lastKnownFileType == "wrapper"
                    }
                    if existing == nil {
                        let fileRef = PBXFileReference(
                            sourceTree: .group,
                            name: Path(relativePath).lastComponent,
                            lastKnownFileType: "wrapper",
                            path: relativePath
                        )
                        pbxproj.add(object: fileRef)
                        let group: PBXGroup
                        if let groupPath = params.arguments?["group"]?.stringValue {
                            group = try GroupHelpers.findOrCreateGroup(pbxproj: pbxproj, groupPath: groupPath, sourceRoot: projPath.parent())
                        } else if let mainGroup = rootProject.mainGroup {
                            group = mainGroup
                        } else {
                            return .init(content: [.text("No main group found to place the package folder reference.")], isError: true)
                        }
                        group.children.append(fileRef)
                        fileRef.parent = group
                    }
                default:
                    return .init(content: [.text("Unknown local_style '\(style)'. Use 'packageReference' or 'folderReference'.")], isError: true)
                }
            }
        } catch let error as SwiftPackageHelpers.PkgError {
            return .init(content: [.text(error.description)], isError: true)
        }

        let existingDeps = SwiftPackageHelpers.allProductDependencies(pbxproj)

        var linked: [String] = []
        var already: [String] = []

        for product in products {
            // Find or create the product dependency object. Remote deps reference the
            // package; local deps have no package link (the package is identified by the
            // XCLocalSwiftPackageReference, not by the dependency).
            let productDep: XCSwiftPackageProductDependency
            if let remoteRef {
                if let found = existingDeps.first(where: { $0.package == remoteRef && $0.productName == product }) {
                    productDep = found
                } else {
                    let dep = XCSwiftPackageProductDependency(productName: product, package: remoteRef)
                    pbxproj.add(object: dep)
                    productDep = dep
                }
            } else {
                if let found = existingDeps.first(where: { $0.package == nil && $0.productName == product }) {
                    productDep = found
                } else {
                    let dep = XCSwiftPackageProductDependency(productName: product)
                    pbxproj.add(object: dep)
                    productDep = dep
                }
            }

            // Link to the target (idempotent).
            var deps = target.packageProductDependencies ?? []
            let alreadyLinked = deps.contains { $0 === productDep }
            if !alreadyLinked {
                deps.append(productDep)
                target.packageProductDependencies = deps
            }

            // Add the framework build file (idempotent).
            let hasBuildFile = (frameworksPhase.files ?? []).contains { $0.product === productDep }
            if !hasBuildFile {
                let buildFile = PBXBuildFile(product: productDep)
                pbxproj.add(object: buildFile)
                if frameworksPhase.files == nil { frameworksPhase.files = [] }
                frameworksPhase.files?.append(buildFile)
            }

            if alreadyLinked && hasBuildFile {
                already.append(product)
            } else {
                linked.append(product)
            }
        }

        try xcodeproj.write(path: projPath)

        var parts: [String] = []
        if !linked.isEmpty {
            parts.append("Linked \(quote(linked)) from \(kindLabel) package '\(identity)' into target '\(targetName)'.")
        }
        if !already.isEmpty {
            parts.append("Already linked: \(quote(already)).")
        }
        if parts.isEmpty {
            parts.append("Nothing to do for \(kindLabel) package '\(identity)'.")
        }
        _ = remoteRef
        _ = localRef
        return .init(content: [.text(parts.joined(separator: " "))])
    }

    private static func quote(_ names: [String]) -> String {
        names.map { "'\($0)'" }.joined(separator: ", ")
    }
}
