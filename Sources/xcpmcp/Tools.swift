import MCP

enum ToolDefs {
    static let listTargets = Tool(
        name: "list_targets",
        description: "List all native targets in an Xcode project (.xcodeproj) with their product types. Use this to discover available targets before adding or removing files.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let listFiles = Tool(
        name: "list_files",
        description: "List files registered in an Xcode project (.xcodeproj), optionally filtered by target. Use this to see what files are already in the project before adding or removing files.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Target name to filter files by. If omitted, lists all files in the project."),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let listGroups = Tool(
        name: "list_groups",
        description: "List the group hierarchy (folder structure) in an Xcode project (.xcodeproj). Use this to understand the project's organization before adding files to a specific group.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let addFile = Tool(
        name: "add_file",
        description: "Add a file to an Xcode project (.xcodeproj) target. Use this instead of manually editing .pbxproj files. The file must exist on disk. Automatically creates the file reference, adds it to the correct group, and registers it in the appropriate build phase (Sources for code, Resources for assets). When creating new source files for an Xcode project, always use this tool after writing the file to disk.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the file to add. The file must exist on disk."),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Target name to add the file to. Use list_targets to discover available targets."),
                ]),
                "group": .object([
                    "type": .string("string"),
                    "description": .string("Group path to add the file to (e.g. 'Sources/Models'). If omitted, inferred from the file's directory relative to the project root."),
                ]),
                "file_type": .object([
                    "type": .string("string"),
                    "enum": .array([.string("source"), .string("resource")]),
                    "description": .string("Whether the file is source code or a resource. Auto-detected from extension if omitted (.swift/.m/.c/.cpp/.metal = source, everything else = resource)."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("file_path"), .string("target")]),
        ])
    )

    static let removeFile = Tool(
        name: "remove_file",
        description: "Remove a file reference from an Xcode project (.xcodeproj). Use this instead of manually editing .pbxproj files. Removes the file reference, build file entries, and group membership. Does not delete the file from disk.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("Path of the file to remove from the project"),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Target name to remove the file from. If omitted, removes from all targets."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("file_path")]),
        ])
    )

    static let moveFile = Tool(
        name: "move_file",
        description: "Move a file to a different group within an Xcode project (.xcodeproj). Only changes where the file appears in the project navigator — does not move the file on disk. Build phase membership is unchanged.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("Path of the file to move within the project"),
                ]),
                "to_group": .object([
                    "type": .string("string"),
                    "description": .string("Destination group path (e.g. 'Sources/Models'). Created if it doesn't exist."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("file_path"), .string("to_group")]),
        ])
    )

    static let removeGroup = Tool(
        name: "remove_group",
        description: "Remove a group from an Xcode project (.xcodeproj). By default only removes empty groups. Use recursive=true to remove the group and all its children (files are removed from the project but not deleted from disk).",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "group": .object([
                    "type": .string("string"),
                    "description": .string("Group path to remove (e.g. 'Sources/OldFolder')"),
                ]),
                "recursive": .object([
                    "type": .string("boolean"),
                    "description": .string("If true, remove the group and all children recursively. Default is false."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("group")]),
        ])
    )

    static let renameGroup = Tool(
        name: "rename_group",
        description: "Rename a group in an Xcode project (.xcodeproj). Only changes the group name in the project navigator — does not rename any folder on disk.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "group": .object([
                    "type": .string("string"),
                    "description": .string("Current group path (e.g. 'Sources/OldName')"),
                ]),
                "new_name": .object([
                    "type": .string("string"),
                    "description": .string("New name for the group"),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("group"), .string("new_name")]),
        ])
    )

    static let moveGroup = Tool(
        name: "move_group",
        description: "Move a group under a different parent group in an Xcode project (.xcodeproj). Only changes the project navigator hierarchy — does not move any folders on disk.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "group": .object([
                    "type": .string("string"),
                    "description": .string("Group path to move (e.g. 'Sources/Models')"),
                ]),
                "to_group": .object([
                    "type": .string("string"),
                    "description": .string("Destination parent group path (e.g. 'Sources/NewParent'). Created if it doesn't exist."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("group"), .string("to_group")]),
        ])
    )

    static let sortGroup = Tool(
        name: "sort_group",
        description: "Sort children of a group in an Xcode project (.xcodeproj) alphabetically, placing groups before files. Use this to tidy the project navigator order.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "group": .object([
                    "type": .string("string"),
                    "description": .string("Group path to sort (e.g. 'Sources/Models')"),
                ]),
                "recursive": .object([
                    "type": .string("boolean"),
                    "description": .string("If true, sort all nested groups recursively. Default is false."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("group")]),
        ])
    )

    static let addSwiftPackage = Tool(
        name: "add_swift_package",
        description: "Add a Swift Package dependency to an Xcode project (.xcodeproj) and link one or more of its library products into a target. Supports both local packages (by relative path) and remote packages (by git URL + version requirement). Idempotent: re-linking a product that's already linked is a no-op. Use this instead of manually editing the .pbxproj. Note: this only edits the project file; run a build (or let Xcode resolve) to fetch/resolve the package.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Target to link the package product(s) into. Use list_targets to discover available targets."),
                ]),
                "products": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("Library product names to link (e.g. [\"Alamofire\"]). At least one is required."),
                ]),
                "local_path": .object([
                    "type": .string("string"),
                    "description": .string("For a LOCAL package: relative path to the package directory (relative to the .xcodeproj's parent folder, e.g. '../mypackage'). Mutually exclusive with 'url'."),
                ]),
                "local_style": .object([
                    "type": .string("string"),
                    "enum": .array([.string("packageReference"), .string("folderReference")]),
                    "description": .string("How to declare a LOCAL package (default 'packageReference'). 'packageReference' adds a modern XCLocalSwiftPackageReference (what Xcode 15+ writes). 'folderReference' adds a PBXFileReference package wrapper into the group tree instead (the legacy style used when a package folder is dragged into the project). Both link the product identically. Ignored for remote packages."),
                ]),
                "group": .object([
                    "type": .string("string"),
                    "description": .string("Only for local_style='folderReference': group path to place the package folder reference under (e.g. 'Packages'). Defaults to the project's main group."),
                ]),
                "url": .object([
                    "type": .string("string"),
                    "description": .string("For a REMOTE package: the git repository URL (e.g. 'https://github.com/Alamofire/Alamofire'). Requires 'requirement'. Mutually exclusive with 'local_path'."),
                ]),
                "requirement": .object([
                    "type": .string("object"),
                    "description": .string("Version requirement for a remote package. An object with 'kind' plus fields: kind='upToNextMajor'|'upToNextMinor' with 'minimum'; kind='exactVersion' with 'version'; kind='versionRange' with 'minimum' and 'maximum'; kind='branch' with 'branch'; kind='revision' with 'revision'."),
                    "properties": .object([
                        "kind": .object(["type": .string("string"), "enum": .array([.string("upToNextMajor"), .string("upToNextMinor"), .string("exactVersion"), .string("versionRange"), .string("branch"), .string("revision")])]),
                        "minimum": .object(["type": .string("string")]),
                        "maximum": .object(["type": .string("string")]),
                        "version": .object(["type": .string("string")]),
                        "branch": .object(["type": .string("string")]),
                        "revision": .object(["type": .string("string")]),
                    ]),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("target"), .string("products")]),
        ])
    )

    static let listSwiftPackages = Tool(
        name: "list_swift_packages",
        description: "List the Swift Package dependencies declared in an Xcode project (.xcodeproj) — both local and remote packages with their version requirements — and which package products are linked into each target. Use this to inspect packages before adding or removing them.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let removeSwiftPackage = Tool(
        name: "remove_swift_package",
        description: "Remove a Swift Package dependency from an Xcode project (.xcodeproj). Identify the package by 'url' (remote) or 'local_path' (local). Without 'target', unlinks the package's products from all targets and removes the package reference entirely; with 'target', only unlinks from that target. Optionally restrict to specific 'products'. Use this instead of manually editing the .pbxproj.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the .xcodeproj directory"),
                ]),
                "url": .object([
                    "type": .string("string"),
                    "description": .string("Git URL identifying a remote package to remove. Mutually exclusive with 'local_path'."),
                ]),
                "local_path": .object([
                    "type": .string("string"),
                    "description": .string("Relative path identifying a local package to remove (matches either a package-reference or a folder-reference local package). Mutually exclusive with 'url'."),
                ]),
                "products": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("Optional: only unlink these specific product names. If omitted, all of the package's linked products are unlinked."),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Optional: only unlink from this target. If omitted, unlinks from all targets and removes the package reference."),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let all: [Tool] = [listTargets, listFiles, listGroups, addFile, removeFile, moveFile, removeGroup, renameGroup, moveGroup, sortGroup, addSwiftPackage, listSwiftPackages, removeSwiftPackage]
}
