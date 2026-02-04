import Foundation
import MCP

let args = CommandLine.arguments

if args.count >= 2 {
    try CLI.run(args: Array(args.dropFirst()))
} else {
    let server = Server(
        name: "xcpmcp",
        version: "1.0.0",
        capabilities: .init(tools: .init(listChanged: false))
    )

    await server.withMethodHandler(ListTools.self) { _ in
        return .init(tools: ToolDefs.all)
    }

    await server.withMethodHandler(CallTool.self) { params in
        do {
            switch params.name {
            case "list_targets":
                return try ListTargetsHandler.handle(params)
            case "list_files":
                return try ListFilesHandler.handle(params)
            case "list_groups":
                return try ListGroupsHandler.handle(params)
            case "add_file":
                return try AddFileHandler.handle(params)
            case "remove_file":
                return try RemoveFileHandler.handle(params)
            case "move_file":
                return try MoveFileHandler.handle(params)
            case "remove_group":
                return try RemoveGroupHandler.handle(params)
            case "rename_group":
                return try RenameGroupHandler.handle(params)
            case "move_group":
                return try MoveGroupHandler.handle(params)
            default:
                return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        } catch {
            return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }

    let transport = StdioTransport()
    try await server.start(transport: transport)
    await server.waitUntilCompleted()
}
