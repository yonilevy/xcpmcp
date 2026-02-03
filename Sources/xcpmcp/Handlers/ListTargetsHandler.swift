import Foundation
import MCP
import PathKit
import XcodeProj

enum ListTargetsHandler {
    static func handle(_ params: CallTool.Parameters) throws -> CallTool.Result {
        guard let projectPath = params.arguments?["project_path"]?.stringValue else {
            return .init(content: [.text("Missing required parameter: project_path")], isError: true)
        }

        let path = Path(projectPath)
        let xcodeproj = try XcodeProj(path: path)

        var lines: [String] = []
        for target in xcodeproj.pbxproj.nativeTargets {
            let productType = target.productType?.rawValue ?? "unknown"
            lines.append("- \(target.name) (\(productType))")
        }

        if lines.isEmpty {
            return .init(content: [.text("No native targets found.")])
        }

        return .init(content: [.text(lines.joined(separator: "\n"))])
    }
}
