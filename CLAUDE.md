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
xcpmcp add-swift-package <project.xcodeproj> --target <name> --products <A,B> (--local-path <path> | --url <git-url> <requirement>)
xcpmcp list-swift-packages <project.xcodeproj>
xcpmcp remove-swift-package <project.xcodeproj> (--url <git-url> | --local-path <path>) [--products <A,B>] [--target <name>]
```

Remote `<requirement>` flags: `--up-to-next-major <v>` | `--up-to-next-minor <v>` | `--exact <v>` | `--from <v> --to <v>` | `--branch <name>` | `--revision <sha>`.

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
    ├── RemoveFileHandler.swift     # Removes a file from target(s) and project
    ├── MoveFileHandler.swift       # Moves a file reference to a different group
    ├── RemoveGroupHandler.swift    # Removes a group (empty or recursive)
    ├── RenameGroupHandler.swift    # Renames a group
    ├── MoveGroupHandler.swift      # Moves a group under a new parent
    ├── SortGroupHandler.swift      # Sorts a group's children alphabetically
    ├── GroupHelpers.swift          # Shared group lookup/creation + path math
    ├── AddSwiftPackageHandler.swift     # Adds a local/remote SwiftPM dependency, links products
    ├── ListSwiftPackagesHandler.swift   # Lists declared packages + per-target linked products
    ├── RemoveSwiftPackageHandler.swift  # Unlinks products / removes a package reference
    └── SwiftPackageHelpers.swift        # Requirement parsing + shared package helpers
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

**AddSwiftPackageHandler** — Adds a Swift Package and links one or more library products into a target. Remote packages are written as `XCRemoteSwiftPackageReference` (`repositoryURL` + `requirement`) in `PBXProject.packageReferences`. Local packages support two `local_style` declarations: `packageReference` (default) writes a modern `XCLocalSwiftPackageReference` (with `relativePath`) into `packageReferences`; `folderReference` instead adds a `PBXFileReference` package wrapper (`lastKnownFileType = wrapper`) into the group tree (default main group, or the `group` path) with nothing in `packageReferences`. For each product it creates an `XCSwiftPackageProductDependency` (remote deps carry a `package` link; **both** local styles produce a `productName`-only dep), appends it to the target's `packageProductDependencies`, and adds a `PBXBuildFile` (`productRef`) to the target's `PBXFrameworksBuildPhase`. Idempotent at every level (package declaration, product dependency, target link, build file). Does **not** use XcodeProj's `addLocalSwiftPackage` (it emits a `folder`-typed reference and never the modern form, and isn't idempotent).

**ListSwiftPackagesHandler** — Lists `rootProject.remotePackages` (url + requirement) and `localPackages` (relativePath), then per native target lists linked products from `packageProductDependencies`, labeling each remote (→ its package url) or local.

**RemoveSwiftPackageHandler** — Identifies the package by `url` (remote) or `local_path` (local, matching either an `XCLocalSwiftPackageReference` by `relativePath` or a folder-reference `PBXFileReference` by `path`). Remote product dependencies are matched via their `package` link; local ones (which have no package link) are matched as package-less deps, optionally narrowed by `products`. With `--target` it only unlinks from that target; without it, unlinks from all targets and removes the package declaration (the package-reference object, or the folder reference detached from its group). Orphaned `XCSwiftPackageProductDependency`/`PBXBuildFile` objects are deleted (XcodeProj serializes every object it holds, so detached objects must be explicitly removed).

**ListSwiftPackagesHandler** also surfaces folder-reference local packages heuristically (file references whose `lastKnownFileType == "wrapper"`), since they aren't `XCLocalSwiftPackageReference` objects.

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
- Local Swift packages default to the modern `XCLocalSwiftPackageReference` form (matching what current Xcode writes); `local_style: folderReference` opts into the legacy `PBXFileReference` wrapper form (e.g. to match an existing project that wires local packages that way). Neither path uses XcodeProj's `addLocalSwiftPackage` (wrong file type, not idempotent).
- `add_swift_package` is fully idempotent; XcodeProj's own `addSwiftPackage` is not (it re-appends the target link and build file on repeat calls), so we guard each step ourselves.
- Package operations edit only the `.pbxproj`; resolving/fetching happens on the next build (`Package.resolved` is regenerated automatically, so the tool doesn't touch it).
- `remove_swift_package` without `--target` removes the package reference entirely; with `--target` it only unlinks from that target and keeps the reference (mirrors `remove-file`'s all-vs-one-target behavior).
