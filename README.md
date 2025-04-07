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
