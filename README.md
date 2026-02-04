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

## Installation

```bash
git clone https://github.com/user/xcpmcp.git  # or your repo URL
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
```

When run with no arguments, it starts as an MCP server over stdin/stdout.

## Requirements

- Swift 6.0+ (Xcode 16+)
- macOS 13+
