import MCP

enum ToolDefs {
    static let listTargets = Tool(
        name: "list_targets",
        description: "List all native targets in an Xcode project with their product types",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the .xcodeproj directory"),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let listFiles = Tool(
        name: "list_files",
        description: "List files in an Xcode project, optionally filtered by target",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the .xcodeproj directory"),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Optional target name to filter files by"),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let listGroups = Tool(
        name: "list_groups",
        description: "List the group hierarchy in an Xcode project",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the .xcodeproj directory"),
                ]),
            ]),
            "required": .array([.string("project_path")]),
        ])
    )

    static let addFile = Tool(
        name: "add_file",
        description: "Add a file to an Xcode project target",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the .xcodeproj directory"),
                ]),
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the file to add"),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Target name to add the file to"),
                ]),
                "group": .object([
                    "type": .string("string"),
                    "description": .string("Group path to add the file to (e.g. 'Sources/Models'). If omitted, inferred from file path."),
                ]),
                "file_type": .object([
                    "type": .string("string"),
                    "enum": .array([.string("source"), .string("resource")]),
                    "description": .string("Whether the file is source code or a resource. Defaults to 'source' for .swift/.m/.c/.cpp files, 'resource' otherwise."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("file_path"), .string("target")]),
        ])
    )

    static let removeFile = Tool(
        name: "remove_file",
        description: "Remove a file from an Xcode project",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "project_path": .object([
                    "type": .string("string"),
                    "description": .string("Path to the .xcodeproj directory"),
                ]),
                "file_path": .object([
                    "type": .string("string"),
                    "description": .string("Path of the file to remove"),
                ]),
                "target": .object([
                    "type": .string("string"),
                    "description": .string("Optional target name. If omitted, removes from all targets."),
                ]),
            ]),
            "required": .array([.string("project_path"), .string("file_path")]),
        ])
    )

    static let all: [Tool] = [listTargets, listFiles, listGroups, addFile, removeFile]
}
