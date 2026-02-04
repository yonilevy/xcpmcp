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

    static let all: [Tool] = [listTargets, listFiles, listGroups, addFile, removeFile, moveFile, removeGroup, renameGroup, moveGroup]
}
