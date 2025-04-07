import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Keys that should always be quoted in any section (e.g. description, homepage, etc.)
const _alwaysQuoteFields = {
  'description',
  'homepage',
  'repository',
  'issue_tracker',
  'documentation',
};

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
          final lines = gitignoreFile.existsSync()
              ? gitignoreFile.readAsLinesSync()
              : <String>[];
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

/// Convert [data] to YAML with your custom rules:
/// - Keys in [_alwaysQuoteFields] are always quoted (e.g. "description: '...'").
/// - Under `environment:`:
///    * If the key is `sdk` or `flutter`, quote the value (e.g. sdk: ">=3.2.0 <4.0.0").
///    * Also if the value has ^, <, >, or =, quote it.
/// - Else unquoted unless empty, newlines, or leading/trailing whitespace.
/// - If key is `flutter` and value is null or an empty map, prints just `flutter:` with no `null`.
String _toYamlString(
  dynamic data, {
  int indent = 0,
  String? parentKey,
}) {
  final buffer = StringBuffer();
  final indentStr = ' ' * indent;

  if (data is Map) {
    for (final rawKey in data.keys) {
      final key = rawKey.toString();
      final value = data[rawKey];

      // Special case: If key == "flutter" and it's null or an empty map,
      // we want to print just "flutter:" with no "null" or "{}".
      if (key == 'flutter' && _isNullOrEmptyMap(value)) {
        buffer.writeln('$indentStr$key:');
        continue;
      }

      // If value is null (and not the flutter special case), just do "key: null"
      if (value == null) {
        buffer.writeln('$indentStr$key: null');
        continue;
      }

      // If we have a nested Map or List, recurse
      if (value is Map || value is List) {
        buffer.writeln('$indentStr$key:');
        buffer.write(_toYamlString(value, indent: indent + 2, parentKey: key));
      } else {
        // It's a scalar
        final stringVal = _maybeQuoteValue(
          value,
          fieldKey: key,
          parentKey: parentKey,
        );
        buffer.writeln('$indentStr$key: $stringVal');
      }
    }
  } else if (data is List) {
    for (final item in data) {
      if (item is Map || item is List) {
        buffer.writeln('$indentStr-');
        buffer.write(
            _toYamlString(item, indent: indent + 2, parentKey: parentKey));
      } else {
        final stringVal =
            _maybeQuoteValue(item, fieldKey: null, parentKey: parentKey);
        buffer.writeln('$indentStr- $stringVal');
      }
    }
  } else {
    // Scalar at the root
    final stringVal =
        _maybeQuoteValue(data, fieldKey: null, parentKey: parentKey);
    buffer.writeln('$indentStr$stringVal');
  }

  return buffer.toString();
}

/// Returns a scalar as a YAML-safe string based on rules:
///
/// 1) If [fieldKey] is in [_alwaysQuoteFields], always quote it.
/// 2) If parentKey == 'environment':
///    - If [fieldKey] is 'sdk' or 'flutter', always quote
///    - If the text has any of ^, <, >, =, also quote
/// 3) If the string is empty, or has newlines or leading/trailing whitespace, quote
/// 4) Otherwise, leave unquoted.
String _maybeQuoteValue(
  dynamic value, {
  required String? fieldKey,
  required String? parentKey,
}) {
  final text = value.toString();
  if (text.isEmpty) {
    return '""';
  }
  final hasNewline = text.contains('\n');
  final leadingOrTrailingSpace = text.trim() != text;

  // 1) Always quote certain top-level fields
  if (fieldKey != null && _alwaysQuoteFields.contains(fieldKey)) {
    return '"$text"';
  }

  // 2) If we are inside 'environment'
  if (parentKey == 'environment') {
    // If the key is sdk or flutter, always quote
    if (fieldKey == 'sdk' || fieldKey == 'flutter') {
      return '"$text"';
    }
    // Or if the value has typical version constraint chars
    final hasVersionChars = text.contains('^') ||
        text.contains('>') ||
        text.contains('<') ||
        text.contains('=');

    if (hasVersionChars || hasNewline || leadingOrTrailingSpace) {
      return '"$text"';
    }
    return text;
  }

  // 3) Elsewhere, we quote only if newlines or leading/trailing spaces
  if (hasNewline || leadingOrTrailingSpace) {
    return '"$text"';
  }

  // 4) Otherwise, remain unquoted
  return text;
}

/// Utility: returns true if [obj] is null or an empty map
bool _isNullOrEmptyMap(dynamic obj) {
  if (obj == null) return true;
  if (obj is Map && obj.isEmpty) return true;
  return false;
}
