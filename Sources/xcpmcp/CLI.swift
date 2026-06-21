import Foundation
import MCP

enum CLI {
    static func run(args: [String]) throws {
        guard let command = args.first else {
            printUsage()
            return
        }

        switch command {
        case "list-targets":
            guard let projectPath = args.dropFirst().first else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            let params = CallTool.Parameters(
                name: "list_targets",
                arguments: ["project_path": .string(projectPath)]
            )
            try printResult(ListTargetsHandler.handle(params))

        case "list-files":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path"], flags: ["--target"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            var arguments: [String: Value] = ["project_path": .string(projectPath)]
            if let target = parsed.flags["--target"] {
                arguments["target"] = .string(target)
            }
            let params = CallTool.Parameters(name: "list_files", arguments: arguments)
            try printResult(ListFilesHandler.handle(params))

        case "list-groups":
            guard let projectPath = args.dropFirst().first else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            let params = CallTool.Parameters(
                name: "list_groups",
                arguments: ["project_path": .string(projectPath)]
            )
            try printResult(ListGroupsHandler.handle(params))

        case "add-file":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path", "file_path"], flags: ["--target", "--group", "--type"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let filePath = parsed.positional["file_path"] else {
                printError("Missing file path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let target = parsed.flags["--target"] else {
                printError("Missing --target")
                printUsage()
                throw ExitError.missingArgument
            }
            var arguments: [String: Value] = [
                "project_path": .string(projectPath),
                "file_path": .string(filePath),
                "target": .string(target),
            ]
            if let group = parsed.flags["--group"] {
                arguments["group"] = .string(group)
            }
            if let fileType = parsed.flags["--type"] {
                arguments["file_type"] = .string(fileType)
            }
            let params = CallTool.Parameters(name: "add_file", arguments: arguments)
            try printResult(AddFileHandler.handle(params))

        case "remove-file":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path", "file_path"], flags: ["--target"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let filePath = parsed.positional["file_path"] else {
                printError("Missing file path")
                printUsage()
                throw ExitError.missingArgument
            }
            var arguments: [String: Value] = [
                "project_path": .string(projectPath),
                "file_path": .string(filePath),
            ]
            if let target = parsed.flags["--target"] {
                arguments["target"] = .string(target)
            }
            let params = CallTool.Parameters(name: "remove_file", arguments: arguments)
            try printResult(RemoveFileHandler.handle(params))

        case "move-file":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path", "file_path"], flags: ["--to-group"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let filePath = parsed.positional["file_path"] else {
                printError("Missing file path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let toGroup = parsed.flags["--to-group"] else {
                printError("Missing --to-group")
                printUsage()
                throw ExitError.missingArgument
            }
            let moveFileParams = CallTool.Parameters(
                name: "move_file",
                arguments: [
                    "project_path": .string(projectPath),
                    "file_path": .string(filePath),
                    "to_group": .string(toGroup),
                ]
            )
            try printResult(MoveFileHandler.handle(moveFileParams))

        case "remove-group":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path", "group"], flags: [], boolFlags: ["--recursive"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let group = parsed.positional["group"] else {
                printError("Missing group path")
                printUsage()
                throw ExitError.missingArgument
            }
            var removeGroupArgs: [String: Value] = [
                "project_path": .string(projectPath),
                "group": .string(group),
            ]
            if parsed.boolFlags.contains("--recursive") {
                removeGroupArgs["recursive"] = .bool(true)
            }
            let removeGroupParams = CallTool.Parameters(name: "remove_group", arguments: removeGroupArgs)
            try printResult(RemoveGroupHandler.handle(removeGroupParams))

        case "rename-group":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path", "group"], flags: ["--new-name"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let group = parsed.positional["group"] else {
                printError("Missing group path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let newName = parsed.flags["--new-name"] else {
                printError("Missing --new-name")
                printUsage()
                throw ExitError.missingArgument
            }
            let renameGroupParams = CallTool.Parameters(
                name: "rename_group",
                arguments: [
                    "project_path": .string(projectPath),
                    "group": .string(group),
                    "new_name": .string(newName),
                ]
            )
            try printResult(RenameGroupHandler.handle(renameGroupParams))

        case "move-group":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path", "group"], flags: ["--to-group"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let group = parsed.positional["group"] else {
                printError("Missing group path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let toGroup = parsed.flags["--to-group"] else {
                printError("Missing --to-group")
                printUsage()
                throw ExitError.missingArgument
            }
            let moveGroupParams = CallTool.Parameters(
                name: "move_group",
                arguments: [
                    "project_path": .string(projectPath),
                    "group": .string(group),
                    "to_group": .string(toGroup),
                ]
            )
            try printResult(MoveGroupHandler.handle(moveGroupParams))

        case "sort-group":
            let parsed = parseArgs(Array(args.dropFirst()), positional: ["project_path", "group"], flags: [], boolFlags: ["--recursive"])
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let group = parsed.positional["group"] else {
                printError("Missing group path")
                printUsage()
                throw ExitError.missingArgument
            }
            var sortGroupArgs: [String: Value] = [
                "project_path": .string(projectPath),
                "group": .string(group),
            ]
            if parsed.boolFlags.contains("--recursive") {
                sortGroupArgs["recursive"] = .bool(true)
            }
            let sortGroupParams = CallTool.Parameters(name: "sort_group", arguments: sortGroupArgs)
            try printResult(SortGroupHandler.handle(sortGroupParams))

        case "add-swift-package":
            let parsed = parseArgs(
                Array(args.dropFirst()),
                positional: ["project_path"],
                flags: ["--target", "--products", "--local-path", "--local-style", "--group", "--url",
                        "--branch", "--revision", "--exact", "--up-to-next-major", "--up-to-next-minor", "--from", "--to"]
            )
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let target = parsed.flags["--target"] else {
                printError("Missing --target")
                printUsage()
                throw ExitError.missingArgument
            }
            guard let products = parsed.flags["--products"] else {
                printError("Missing --products (comma-separated product names)")
                printUsage()
                throw ExitError.missingArgument
            }
            var arguments: [String: Value] = [
                "project_path": .string(projectPath),
                "target": .string(target),
                "products": .string(products),
            ]
            if let localPath = parsed.flags["--local-path"] {
                arguments["local_path"] = .string(localPath)
            }
            if let localStyle = parsed.flags["--local-style"] {
                arguments["local_style"] = .string(localStyle)
            }
            if let group = parsed.flags["--group"] {
                arguments["group"] = .string(group)
            }
            if let url = parsed.flags["--url"] {
                arguments["url"] = .string(url)
                if let requirement = buildRequirement(parsed.flags) {
                    arguments["requirement"] = requirement
                }
            }
            let params = CallTool.Parameters(name: "add_swift_package", arguments: arguments)
            try printResult(AddSwiftPackageHandler.handle(params))

        case "list-swift-packages":
            guard let projectPath = args.dropFirst().first else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            let params = CallTool.Parameters(
                name: "list_swift_packages",
                arguments: ["project_path": .string(projectPath)]
            )
            try printResult(ListSwiftPackagesHandler.handle(params))

        case "remove-swift-package":
            let parsed = parseArgs(
                Array(args.dropFirst()),
                positional: ["project_path"],
                flags: ["--url", "--local-path", "--products", "--target"]
            )
            guard let projectPath = parsed.positional["project_path"] else {
                printError("Missing project path")
                printUsage()
                throw ExitError.missingArgument
            }
            var arguments: [String: Value] = ["project_path": .string(projectPath)]
            if let url = parsed.flags["--url"] {
                arguments["url"] = .string(url)
            }
            if let localPath = parsed.flags["--local-path"] {
                arguments["local_path"] = .string(localPath)
            }
            if let products = parsed.flags["--products"] {
                arguments["products"] = .string(products)
            }
            if let target = parsed.flags["--target"] {
                arguments["target"] = .string(target)
            }
            let params = CallTool.Parameters(name: "remove_swift_package", arguments: arguments)
            try printResult(RemoveSwiftPackageHandler.handle(params))

        case "help", "--help", "-h":
            printUsage()

        default:
            printError("Unknown command: \(command)")
            printUsage()
        }
    }

    /// Build a `requirement` object Value from the CLI's discrete requirement flags.
    private static func buildRequirement(_ flags: [String: String]) -> Value? {
        if let v = flags["--up-to-next-major"] {
            return .object(["kind": .string("upToNextMajor"), "minimum": .string(v)])
        }
        if let v = flags["--up-to-next-minor"] {
            return .object(["kind": .string("upToNextMinor"), "minimum": .string(v)])
        }
        if let v = flags["--exact"] {
            return .object(["kind": .string("exactVersion"), "version": .string(v)])
        }
        if let from = flags["--from"], let to = flags["--to"] {
            return .object(["kind": .string("versionRange"), "minimum": .string(from), "maximum": .string(to)])
        }
        if let v = flags["--branch"] {
            return .object(["kind": .string("branch"), "branch": .string(v)])
        }
        if let v = flags["--revision"] {
            return .object(["kind": .string("revision"), "revision": .string(v)])
        }
        return nil
    }

    private static func printResult(_ result: CallTool.Result) {
        for content in result.content {
            switch content {
            case .text(let text):
                if result.isError == true {
                    printError(text)
                } else {
                    print(text)
                }
            default:
                break
            }
        }
        if result.isError == true {
            Foundation.exit(1)
        }
    }

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    }

    private static func printUsage() {
        let usage = """
            xcpmcp — Xcode project manipulation tool

            Usage:
              xcpmcp list-targets <project.xcodeproj>
              xcpmcp list-files <project.xcodeproj> [--target <name>]
              xcpmcp list-groups <project.xcodeproj>
              xcpmcp add-file <project.xcodeproj> <file> --target <name> [--group <path>] [--type source|resource]
              xcpmcp remove-file <project.xcodeproj> <file> [--target <name>]
              xcpmcp move-file <project.xcodeproj> <file> --to-group <path>
              xcpmcp remove-group <project.xcodeproj> <group> [--recursive]
              xcpmcp rename-group <project.xcodeproj> <group> --new-name <name>
              xcpmcp move-group <project.xcodeproj> <group> --to-group <path>
              xcpmcp sort-group <project.xcodeproj> <group> [--recursive]
              xcpmcp add-swift-package <project.xcodeproj> --target <name> --products <A,B> \\
                       (--local-path <path> [--local-style packageReference|folderReference] [--group <path>]
                        | --url <git-url> <requirement>)
                       requirement (remote only): --up-to-next-major <v> | --up-to-next-minor <v>
                                                | --exact <v> | --from <v> --to <v>
                                                | --branch <name> | --revision <sha>
              xcpmcp list-swift-packages <project.xcodeproj>
              xcpmcp remove-swift-package <project.xcodeproj> (--url <git-url> | --local-path <path>) \\
                       [--products <A,B>] [--target <name>]
              xcpmcp help

            When run with no arguments, starts as an MCP server (for use with Claude Code).
            """
        print(usage)
    }

    struct ParsedArgs {
        var positional: [String: String] = [:]
        var flags: [String: String] = [:]
        var boolFlags: Set<String> = []
    }

    private static func parseArgs(_ args: [String], positional positionalNames: [String], flags flagNames: [String], boolFlags boolFlagNames: [String] = []) -> ParsedArgs {
        var result = ParsedArgs()
        var positionalIndex = 0
        var i = 0

        while i < args.count {
            let arg = args[i]
            if flagNames.contains(arg), i + 1 < args.count {
                result.flags[arg] = args[i + 1]
                i += 2
            } else if boolFlagNames.contains(arg) {
                result.boolFlags.insert(arg)
                i += 1
            } else if !arg.hasPrefix("-") && positionalIndex < positionalNames.count {
                result.positional[positionalNames[positionalIndex]] = arg
                positionalIndex += 1
                i += 1
            } else {
                i += 1
            }
        }

        return result
    }

    enum ExitError: Error {
        case missingArgument
    }
}
