// lib/env_mode_logic.dart

import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

/// Toggles environment mode for all pubspec.yaml files under [rootDir].
/// [mode] can be "dev", "publish", or any other future modes you define.
///
/// Returns a log String summarizing what was done.
Future<String> toggleEnvMode(String mode, Directory rootDir) async {
  final logBuffer = StringBuffer();
  logBuffer.writeln('toggleEnvMode called with mode: $mode');
  logBuffer.writeln('Root directory: ${rootDir.path}');
  logBuffer.writeln('---------------------------------');

  // 1. Load packages from env_mode_config.yaml
  final configFile = File(p.join(rootDir.path, 'env_mode_config.yaml'));
  if (!configFile.existsSync()) {
    final errorMsg = 'ERROR: env_mode_config.yaml not found in ${rootDir.path}';
    logBuffer.writeln(errorMsg);
    return logBuffer.toString();
  }

  final configContent = configFile.readAsStringSync();
  final yamlMap = loadYaml(configContent) as YamlMap;
  final packages = List<String>.from(yamlMap['environment_packages'] ?? []);
  logBuffer.writeln('Packages from config: $packages');

  // 2. Walk through all files under rootDir to find pubspec.yaml
  final backupFilename = 'pubspec.backup.yaml';
  final List<FileSystemEntity> entities =
      rootDir.listSync(recursive: true, followLinks: false);

  for (var entity in entities) {
    if (entity is File && p.basename(entity.path) == 'pubspec.yaml') {
      final pubspecFile = entity;
      final backupFile = File(p.join(p.dirname(entity.path), backupFilename));

      logBuffer.writeln('\nFound pubspec.yaml -> ${pubspecFile.path}');

      if (mode == 'dev') {
        // ---- Dev Mode ----
        // a. Create backup
        try {
          backupFile.writeAsStringSync(pubspecFile.readAsStringSync());
          logBuffer.writeln('  - Created backup file: ${backupFile.path}');
        } catch (e) {
          logBuffer.writeln('  - ERROR creating backup: $e');
          continue;
        }

        // b. Update .gitignore in the same folder
        final gitignoreFile =
            File(p.join(p.dirname(entity.path), '.gitignore'));
        try {
          List<String> lines = [];
          if (gitignoreFile.existsSync()) {
            lines = gitignoreFile.readAsLinesSync();
          }
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

        // c. Replace each package version with a local path
        String content = pubspecFile.readAsStringSync();
        for (final pkg in packages) {
          // Regex to match lines like "alga_configui: ^1.0.0", ignoring trailing or leading spaces
          final regex = RegExp(
              r'^(\s*' + RegExp.escape(pkg) + r'\s*:\s*)([^\s].*)$',
              multiLine: true);

          content = content.replaceAllMapped(regex, (match) {
            // Build relative path from the current pubspec.yaml folder to the package folder at root
            final packageFolder = Directory(p.join(rootDir.path, pkg));
            final relPath =
                p.relative(packageFolder.path, from: p.dirname(entity.path));
            return '${match.group(1)}\n  path: ${relPath.replaceAll('\\', '/')}';
          });
        }
        pubspecFile.writeAsStringSync(content);
        logBuffer.writeln('  - Updated dependencies for dev mode');
      } else if (mode == 'publish') {
        // ---- Publish Mode ----
        // a. Restore from backup if exists
        if (backupFile.existsSync()) {
          try {
            pubspecFile.writeAsStringSync(backupFile.readAsStringSync());
            logBuffer.writeln('  - Restored pubspec.yaml from backup');
          } catch (e) {
            logBuffer.writeln('  - ERROR restoring from backup: $e');
          }
        } else {
          logBuffer.writeln('  - No backup found; skipping restore.');
        }
      } else {
        // ---- Future or Unknown Mode ----
        logBuffer.writeln('  - Unknown mode: $mode (no changes made)');
      }
    }
  }

  return logBuffer.toString();
}
