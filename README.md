# xcpmcp

An MCP server for Xcode project manipulation. Lets AI assistants (Claude Code, etc.) add, remove, and list files in `.xcodeproj` projects without manually editing `.pbxproj` files.

Also works as a standalone CLI.

## Tools

| Tool | Description |
|------|-------------|
| `list_targets` | List native targets with product types |
| `list_files` | List files in the project, optionally filtered by target |
| `list_groups` | Show the group/folder hierarchy |
| `add_file` | Add a file to a target (Sources or Resources build phase) |
| `remove_file` | Remove a file reference from the project |
| `move_file` | Move a file to a different group (project navigator only, not on disk) |
| `remove_group` | Remove a group (empty, or recursive with all children) |
| `rename_group` | Rename a group in the project navigator |
| `move_group` | Move a group under a different parent group |
| `sort_group` | Sort a group's children alphabetically (groups before files) |
| `add_swift_package` | Add a local or remote Swift Package and link its product(s) into a target |
| `list_swift_packages` | List declared Swift Packages and the products linked per target |
| `remove_swift_package` | Remove a Swift Package (or unlink its products from a target) |

## Installation

```bash
git clone https://github.com/yonilevy/xcpmcp.git
cd xcpmcp
make install
```

This builds a release binary, copies it to `~/.local/bin/xcpmcp`, and optionally registers it as an MCP server in Claude Code.

To install to a different location:

```bash
make install PREFIX=/opt/bin
```

To uninstall:

```bash
make uninstall
```

## CLI Usage

When run with arguments, xcpmcp works as a regular command-line tool:

```bash
# List targets
xcpmcp list-targets MyApp.xcodeproj

# List all files
xcpmcp list-files MyApp.xcodeproj

# List files in a specific target
xcpmcp list-files MyApp.xcodeproj --target MyApp

# Show group hierarchy
xcpmcp list-groups MyApp.xcodeproj

# Add a source file to a target
xcpmcp add-file MyApp.xcodeproj Sources/NewFile.swift --target MyApp

# Add a resource file
xcpmcp add-file MyApp.xcodeproj Assets/image.png --target MyApp --type resource

# Add to a specific group
xcpmcp add-file MyApp.xcodeproj Sources/Models/User.swift --target MyApp --group Sources/Models

# Remove a file from a specific target
xcpmcp remove-file MyApp.xcodeproj Sources/OldFile.swift --target MyApp

# Remove a file from all targets
xcpmcp remove-file MyApp.xcodeproj Sources/OldFile.swift

# Move a file to a different group
xcpmcp move-file MyApp.xcodeproj Sources/Models/User.swift --to-group Sources/NewModels

# Remove an empty group
xcpmcp remove-group MyApp.xcodeproj Sources/OldFolder

# Remove a group and all its children
xcpmcp remove-group MyApp.xcodeproj Sources/OldFolder --recursive

# Rename a group
xcpmcp rename-group MyApp.xcodeproj Sources/OldName --new-name NewName

# Move a group under a different parent
xcpmcp move-group MyApp.xcodeproj Sources/Models --to-group Sources/Core

# Sort a group's children alphabetically
xcpmcp sort-group MyApp.xcodeproj Sources/Models

# Add a local Swift Package and link a product into a target
xcpmcp add-swift-package MyApp.xcodeproj --target MyApp --products MyLib --local-path ../mylib

# Add a local package as a folder reference (PBXFileReference wrapper) instead of the
# modern XCLocalSwiftPackageReference, optionally placed in a specific group
xcpmcp add-swift-package MyApp.xcodeproj --target MyApp --products MyLib --local-path ../mylib \
  --local-style folderReference --group Packages

# Add a remote Swift Package (version requirement variants)
xcpmcp add-swift-package MyApp.xcodeproj --target MyApp --products Alamofire \
  --url https://github.com/Alamofire/Alamofire --up-to-next-major 5.0.0
#   other requirements: --up-to-next-minor <v> | --exact <v> | --from <v> --to <v>
#                       | --branch <name> | --revision <sha>

# Link multiple products in one call
xcpmcp add-swift-package MyApp.xcodeproj --target MyApp --products "Logging,Metrics" \
  --url https://github.com/apple/swift-log --up-to-next-major 1.0.0

# List declared packages and per-target linked products
xcpmcp list-swift-packages MyApp.xcodeproj

# Unlink a package's products from one target
xcpmcp remove-swift-package MyApp.xcodeproj --url https://github.com/Alamofire/Alamofire --target MyApp

# Remove a package entirely (unlink from all targets + drop the package reference)
xcpmcp remove-swift-package MyApp.xcodeproj --local-path ../mylib
```

> Package operations only edit the `.pbxproj`. Run a build (or open in Xcode) afterwards to fetch/resolve the package. `add_swift_package` is idempotent — re-linking an already-linked product is a no-op.

When run with no arguments, it starts as an MCP server over stdin/stdout.

## Requirements

- Swift 6.0+ (Xcode 16+)
- macOS 13+
