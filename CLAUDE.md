# xcpmcp

Swift MCP server and CLI tool that exposes XcodeProj operations, enabling AI assistants (and humans) to add/remove/list files in Xcode projects.

## Build

Debug:

```bash
swift build
```

Binary is at `.build/debug/xcpmcp`.

Release (optimized, smaller binary):

```bash
swift build -c release
```

Binary is at `.build/release/xcpmcp`.

## Usage

### As MCP server

Run with no arguments to start as an MCP server over stdin/stdout (JSON-RPC, MCP protocol). Configure in `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "xcpmcp": {
      "command": "/Users/yoni/projects/xcpmcp/.build/debug/xcpmcp"
    }
  }
}
```

### As CLI

```
xcpmcp list-targets <project.xcodeproj>
xcpmcp list-files <project.xcodeproj> [--target <name>]
xcpmcp list-groups <project.xcodeproj>
xcpmcp add-file <project.xcodeproj> <file> --target <name> [--group <path>] [--type source|resource]
xcpmcp remove-file <project.xcodeproj> <file> [--target <name>]
```

## Architecture

```
Sources/xcpmcp/
├── main.swift              # Entry point: CLI mode (args present) or MCP server (no args)
├── CLI.swift               # CLI argument parsing and dispatch
├── Tools.swift             # MCP tool definitions (name, description, inputSchema as JSON Schema)
└── Handlers/
    ├── ListTargetsHandler.swift    # Lists native targets with product types
    ├── ListFilesHandler.swift      # Lists files, optionally filtered by target
    ├── ListGroupsHandler.swift     # Prints group hierarchy tree
    ├── AddFileHandler.swift        # Adds a file to a target and group
    └── RemoveFileHandler.swift     # Removes a file from target(s) and project
```

### Entry point (main.swift)

If `CommandLine.arguments.count >= 2`, dispatches to `CLI.run()`. Otherwise starts an MCP `Server` with `StdioTransport`, registers `ListTools` and `CallTool` handlers, and waits for completion.

### Tool dispatch

Both CLI and MCP paths construct `CallTool.Parameters` and call the same handler functions, so behavior is identical regardless of interface.

### Handler details

**ListTargetsHandler** — Iterates `pbxproj.nativeTargets`, returns name and `productType.rawValue`.

**ListFilesHandler** — Without `--target`: lists all `pbxproj.fileReferences` with full paths. With `--target`: lists files per build phase with phase labels (Sources, Resources, Frameworks, etc.).

**ListGroupsHandler** — Recursively walks from `rootProject.mainGroup` down, printing groups and files with indentation.

**AddFileHandler** — Validates the file exists on disk, finds or creates the group hierarchy (checks both `name` and `path` properties on existing groups to avoid duplicates), calls `PBXGroup.addFile(at:sourceTree:sourceRoot:)`, then adds to the appropriate build phase (`PBXSourcesBuildPhase` for source files, `PBXResourcesBuildPhase` for resources). Source extensions: swift, m, mm, c, cc, cpp, cxx, metal.

**RemoveFileHandler** — Finds the `PBXFileReference` by full path or filename, removes `PBXBuildFile` entries from build phases (scoped to one target or all), removes from parent group's children, deletes objects from pbxproj, saves.

## Dependencies

- **XcodeProj** (tuist/XcodeProj ~8.12.0) — .xcodeproj read/write
- **MCP** (modelcontextprotocol/swift-sdk ~0.10.0) — MCP protocol server
- **PathKit** (transitive via XcodeProj) — Path handling

## Known design decisions

- Group lookup checks both `name` and `path` properties to match existing Xcode groups correctly (Xcode often sets only `path`, not `name`).
- `add-file` refuses to add files that don't exist on disk to prevent broken references.
- `remove-file` without `--target` removes from all targets.
- File type (source vs resource) is auto-detected from extension but can be overridden with `--type`.
- `addFile(validatePresence: false)` is used on the XcodeProj side since we do our own existence check earlier (before project modification).
