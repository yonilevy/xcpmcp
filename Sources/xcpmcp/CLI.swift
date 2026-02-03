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

        case "help", "--help", "-h":
            printUsage()

        default:
            printError("Unknown command: \(command)")
            printUsage()
        }
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
              xcpmcp help

            When run with no arguments, starts as an MCP server (for use with Claude Code).
            """
        print(usage)
    }

    struct ParsedArgs {
        var positional: [String: String] = [:]
        var flags: [String: String] = [:]
    }

    private static func parseArgs(_ args: [String], positional positionalNames: [String], flags flagNames: [String]) -> ParsedArgs {
        var result = ParsedArgs()
        var positionalIndex = 0
        var i = 0

        while i < args.count {
            let arg = args[i]
            if flagNames.contains(arg), i + 1 < args.count {
                result.flags[arg] = args[i + 1]
                i += 2
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
