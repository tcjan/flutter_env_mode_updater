import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Toggle between 'dev' and 'publish' mode, rewriting pubspec.yaml references
/// with minimal quoting in the result.
Future<String> toggleEnvMode(String requestedMode, Directory rootDir) async {
  final logBuffer = StringBuffer();

  // Step 1: Read or create env_mode_config.yaml
  final configFilePath = p.join(rootDir.path, 'env_mode_config.yaml');
  final configFile = File(configFilePath);

  Map<String, dynamic> configMap = {};
  if (!configFile.existsSync()) {
    // Create a new config with an empty environment_packages
    configMap['current_mode'] = requestedMode;
    configMap['environment_packages'] = [];

    // Look for subfolders that contain a pubspec.yaml
    final subdirs = rootDir.listSync(followLinks: false, recursive: false);
    for (var entity in subdirs) {
      if (entity is Directory) {
        final pubspecInSub = File(p.join(entity.path, 'pubspec.yaml'));
        if (pubspecInSub.existsSync()) {
          configMap['environment_packages'].add(p.basename(entity.path));
        }
      }
    }

    // Write the initial file
    configFile.writeAsStringSync(_toYamlString(configMap));
    logBuffer.writeln('Created env_mode_config.yaml with discovered folders.');
  } else {
    // Load existing config
    final content = configFile.readAsStringSync();
    final yamlObj = loadYaml(content);
    configMap = Map<String, dynamic>.from(yamlObj as YamlMap);

    // Ensure keys exist
    configMap.putIfAbsent('current_mode', () => requestedMode);
    configMap.putIfAbsent('environment_packages', () => []);
  }

  // If the user re-requests the same mode, do nothing
  final currentMode = configMap['current_mode'];
  if (currentMode == requestedMode) {
    logBuffer.writeln('Mode is already "$requestedMode". Doing nothing.');
    return logBuffer.toString();
  }

  // Otherwise, update the mode
  configMap['current_mode'] = requestedMode;
  configFile.writeAsStringSync(_toYamlString(configMap));
  logBuffer.writeln('Set current_mode in config to: $requestedMode');

  // Make sure environment_packages is a valid list
  final environmentPackages = configMap['environment_packages'];
  if (environmentPackages is! List || environmentPackages.isEmpty) {
    logBuffer
        .writeln('No environment_packages found in config. Aborting toggle.');
    return logBuffer.toString();
  }

  // Step 2: Toggle logic
  final backupFilename = 'pubspec.backup.yaml';
  final entities = rootDir.listSync(recursive: true, followLinks: false);

  for (var entity in entities) {
    if (entity is File && p.basename(entity.path) == 'pubspec.yaml') {
      final pubspecFile = entity;
      final backupFile = File(p.join(p.dirname(entity.path), backupFilename));

      logBuffer.writeln('Found pubspec.yaml -> ${pubspecFile.path}');

      if (requestedMode == 'dev') {
        // 1) Create backup
        try {
          backupFile.writeAsStringSync(pubspecFile.readAsStringSync());
          logBuffer.writeln('  - Created backup file: ${backupFile.path}');
        } catch (e) {
          logBuffer.writeln('  - ERROR creating backup: $e');
          continue;
        }

        // 2) Update .gitignore
        final gitignoreFile =
            File(p.join(p.dirname(entity.path), '.gitignore'));
        try {
          List<String> lines =
              gitignoreFile.existsSync() ? gitignoreFile.readAsLinesSync() : [];
          if (!lines.contains(backupFilename)) {
            final sink = gitignoreFile.openWrite(mode: FileMode.append);
            if (lines.isNotEmpty && lines.last.trim().isNotEmpty) {
              sink.writeln();
            }
            sink.writeln(backupFilename);
            await sink.flush();
            await sink.close();
            logBuffer.writeln('  - Added $backupFilename to .gitignore');
          }
        } catch (e) {
          logBuffer.writeln('  - ERROR updating .gitignore: $e');
        }

        // 3) Replace references with local paths
        try {
          final originalContent = pubspecFile.readAsStringSync();
          final yamlObj = loadYaml(originalContent);

          // Convert to mutable map
          final pubspecMap = Map<String, dynamic>.from(yamlObj);

          if (pubspecMap['dependencies'] is Map) {
            final deps = Map<String, dynamic>.from(pubspecMap['dependencies']);
            for (final pkg in environmentPackages) {
              if (deps.containsKey(pkg)) {
                final packageFolder = Directory(p.join(rootDir.path, pkg));
                final relativePath = p
                    .relative(packageFolder.path, from: p.dirname(entity.path))
                    .replaceAll('\\', '/');

                // Overwrite with path dependency
                deps[pkg] = {'path': relativePath};
                logBuffer.writeln('  - Set "$pkg" to path: $relativePath');
              }
            }
            pubspecMap['dependencies'] = deps;
          }

          // Write back
          pubspecFile.writeAsStringSync(_toYamlString(pubspecMap));
        } catch (e) {
          logBuffer.writeln('  - ERROR rewriting pubspec: $e');
        }
      } else if (requestedMode == 'publish') {
        if (backupFile.existsSync()) {
          try {
            pubspecFile.writeAsStringSync(backupFile.readAsStringSync());
            logBuffer.writeln('  - Restored pubspec.yaml from backup');
          } catch (e) {
            logBuffer.writeln('  - ERROR restoring from backup: $e');
          }
        } else {
          logBuffer.writeln('  - No backup found; skipping restore');
        }
      } else {
        logBuffer.writeln('  - Unknown mode: $requestedMode (no changes made)');
      }
    }
  }

  return logBuffer.toString();
}

/// A minimal YAML writer that only quotes strings if they are empty,
/// contain newlines, or have leading/trailing whitespace.
String _toYamlString(dynamic data, {int indent = 0}) {
  final buffer = StringBuffer();
  final indentStr = ' ' * indent;

  if (data is Map) {
    for (final key in data.keys) {
      final value = data[key];
      if (value is Map || value is List) {
        buffer.writeln('$indentStr$key:');
        buffer.write(_toYamlString(value, indent: indent + 2));
      } else {
        buffer.writeln('$indentStr$key: ${_maybeQuoteValue(value)}');
      }
    }
  } else if (data is List) {
    for (final item in data) {
      if (item is Map || item is List) {
        buffer.writeln('$indentStr-');
        buffer.write(_toYamlString(item, indent: indent + 2));
      } else {
        buffer.writeln('$indentStr- ${_maybeQuoteValue(item)}');
      }
    }
  } else {
    // Scalar at root level
    buffer.writeln('$indentStr${_maybeQuoteValue(data)}');
  }

  return buffer.toString();
}

/// Only quote if empty, has newlines, or leading/trailing spaces.
String _maybeQuoteValue(dynamic value) {
  if (value == null) return 'null';

  final text = value.toString();

  // if it has a newline or is empty or has leading/trailing spaces
  final hasNewline = text.contains('\n');
  final leadingOrTrailingSpace = text.trim() != text;
  if (text.isEmpty || hasNewline || leadingOrTrailingSpace) {
    return '"$text"';
  }

  // otherwise, leave it as is
  return text;
}
