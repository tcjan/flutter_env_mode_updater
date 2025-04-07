# Flutter Env Mode Updater

A Flutter tool that toggles package dependencies between local paths (development mode) and pub.dev versions (publish mode). It works on Windows, macOS, and Linux and provides both a desktop GUI and a CLI.

## Structure

- A file named env_mode_config.yaml in the root directory containing a list of package names (environment_packages).
- A shared logic file (env_mode_logic.dart) that performs the scanning, backup, and update of pubspec.yaml files.
- A Flutter desktop GUI entry point (main.dart).
- A CLI entry point (console.dart) for running in a terminal.

## env_mode_config.yaml

Contains something like:
```
environment_packages:
- package_1
- package_2
- package_3
- package_4
```

These are the package names to look for in pubspec.yaml files and replace with local paths in development mode.

## Usage

- Desktop GUI:
  1. Enable desktop support
    - `flutter config --enable-windows-desktop`
    - `flutter config --enable-macos-desktop`
    - `flutter config --enable-linux-desktop`
  2. Run the project with `flutter run -d windows` (or macos/linux).
  3. In the app, pick Development or Publish, then press Run.

- Command Line Interface (CLI):
  1. Navigate to the project folder.
  2. Use `dart run bin/console.dart dev` or `dart run bin/console.dart` publish.

- Compiled CLI:
  1. Compile with `dart compile exe bin/console.dart -o toggle_env_mode`.
  2. Run the resulting `toggle_env_mode dev` or `toggle_env_mode publish` on your system without installing Dart.

## How It Works

1. Loads the list of packages from `env_mode_config.yaml`.
2. Scans the current directory for `pubspec.yaml` files.
3. Creates backups (`pubspec.backup.yaml`) and updates `.gitignore` to include those backups.
4. In dev mode, converts each matching dependency into a local path reference.
5. In publish mode, reverts pubspec.yaml from its backup.

## Notes

- Place `env_mode_config.yaml` at the root where you run the tool.
- In dev mode, any dependency in the list becomes a local path in the discovered pubspec.yaml files.
- In publish mode, original dependencies are restored from backup.
- Extend or customize additional modes in env_mode_logic.dart and main.dart (GUI) or console.dart (CLI).


# Clarification on Compiling and Distributing a Standalone Executable:

1. Build a Flutter desktop app (for Windows, as an example).

  - Enable Windows desktop support:
   
    `flutter config --enable-windows-desktop`

  - In your project folder, run:
  
  
    `flutter build windows`

This produces an executable in the `build/windows/runner/Release/` folder (for a release build). For example, you might see `my_project.exe` there.

2. Distribute the compiled `.exe`.

  - Copy it from `build/windows/runner/Release/my_project.exe` to the base directory of your packages (where `env_mode_config.yaml` resides).

  - You can rename it if you wish (e.g., `flutter_env_mode_updater.exe`).

3. Run the Executable to Toggle Modes.

  - Double-click the `.exe` or run it from a terminal.

  - The GUI will appear if you built a Flutter desktop interface.

  - Any logic for switching between dev/publish modes will be triggered by this standalone binary; no source code access is needed on the target machine.

## If you want only a CLI executable (no GUI), use:

dart compile exe bin/console.dart -o toggle_env_mode

Then place the resulting binary (`toggle_env_mode.exe` on Windows, for example) in the base directory alongside `env_mode_config.yaml`. Running it (e.g., `toggle_env_mode dev`) will switch to dev mode, and `toggle_env_mode publish` will revert to publish mode.