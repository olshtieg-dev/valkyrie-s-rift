# Valkyrie's Rift

A 2D platformer built with [Godot](https://godotengine.org/) (GDScript).

## Getting started

The Godot version is pinned in [`.godot-version`](.godot-version). The setup script downloads that exact version from the official Godot releases, verifies its checksum, and adds a `godot` command to your PATH.

**Linux / macOS**

```sh
sh tools/setup.sh
```

**Windows** (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup.ps1
```

Then, from the project folder:

```sh
godot -e    # open the editor
godot       # run the game
```

You can also skip the script and install Godot yourself. Just use the version in `.godot-version` (standard build, not .NET).

## Editor setup (optional)

To edit GDScript in VS Code, install the recommended **godot-tools** extension (VS Code will prompt you). It finds `godot` on your PATH automatically.

`.vscode/settings.json` is git-ignored, so any machine-specific settings you add there stay local.

## Upgrading Godot

Change the version in `.godot-version` (e.g. `4.7-stable`), update `config/features` in `project.godot` by opening the project in the new editor, and have everyone re-run the setup script.
