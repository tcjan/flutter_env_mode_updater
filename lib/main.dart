import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter_env_mode_updater/env_mode_logic.dart';

class EnvModeApp extends StatelessWidget {
  const EnvModeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Env Mode Updater',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const EnvModeHomePage(),
    );
  }
}

class EnvModeHomePage extends StatefulWidget {
  const EnvModeHomePage({Key? key}) : super(key: key);

  @override
  State<EnvModeHomePage> createState() => _EnvModeHomePageState();
}

class _EnvModeHomePageState extends State<EnvModeHomePage> {
  String _log = '';
  String _currentMode = ''; // default to dev

  /// The user-selected base folder. If null, we fall back to Directory.current.
  Directory? _selectedBaseFolder;
  bool _configExists = false;

  @override
  void initState() {
    super.initState();
    // By default, we won't load anything until user picks a folder,
    // but if you want to start with Directory.current:
    // _selectedBaseFolder = Directory.current;
    // _loadCurrentMode();
  }

  /// Returns the effective root directory in use,
  /// either the user-selected one or Directory.current if none chosen.
  Directory get effectiveRootDir => _selectedBaseFolder ?? Directory.current;

  /// Check whether env_mode_config.yaml exists in the selected folder,
  /// and if so, load and set the current mode. If not, set _configExists = false.
  Future<void> _loadCurrentMode() async {
    final configFilePath =
        p.join(effectiveRootDir.path, 'env_mode_config.yaml');
    final configFile = File(configFilePath);

    if (!configFile.existsSync()) {
      setState(() {
        _configExists = false;
        _currentMode = 'dev'; // Reset if you want
      });
      return;
    }

    // Otherwise, config file does exist:
    _configExists = true;
    final content = configFile.readAsStringSync();
    final yamlObj = loadYaml(content);
    if (yamlObj is YamlMap) {
      final configMap = Map<String, dynamic>.from(yamlObj);
      final mode = configMap['current_mode'];
      if (mode is String) {
        setState(() {
          _currentMode = mode;
        });
      }
    } else {
      // If you get here, the file was not valid YAML
      setState(() {
        _currentMode = 'dev';
      });
    }
  }

  Future<void> _onToggleMode() async {
    if (_selectedBaseFolder == null) return;

    final result = await toggleEnvMode(_currentMode, effectiveRootDir);

    // After toggling, re-read the file so UI stays in sync with the final state
    await _loadCurrentMode();

    setState(() {
      _log = result;
    });
  }

  /// Use file_picker to select a folder. Once selected, we load config from it.
  Future<void> _onSelectBaseFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _selectedBaseFolder = Directory(result);
      });
      await _loadCurrentMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderPath = _selectedBaseFolder?.path ?? '';

    // Controls are only enabled if a folder is selected.
    final folderSelected = _selectedBaseFolder != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Env Mode Updater (Mode: $_currentMode)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // First row: the "Select Base Folder" button
            Row(
              children: [
                ElevatedButton(
                  onPressed: _onSelectBaseFolder,
                  child: const Text('Select Base Folder'),
                ),
                const SizedBox(width: 16),
                // Show the current folder (if any)
                Expanded(
                  child: Text(
                    folderPath.isEmpty
                        ? 'No folder selected'
                        : 'Selected Folder: $folderPath',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // If a folder is selected but there's no env_mode_config.yaml, show a note:
            if (folderSelected && !_configExists)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Text(
                  'No env_mode_config.yaml found in this folder.',
                  style:
                      TextStyle(fontStyle: FontStyle.italic, color: Colors.red),
                ),
              ),

            // Second row: Select Mode & Run button
            // Disabled if no folder is selected
            Row(
              children: [
                const Text('Select Mode:'),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _currentMode,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('')),
                    DropdownMenuItem(value: 'dev', child: Text('Development')),
                    DropdownMenuItem(value: 'publish', child: Text('Publish')),
                  ],
                  onChanged: folderSelected
                      ? (val) {
                          setState(() {
                            _currentMode = val ?? 'dev';
                          });
                        }
                      : null,
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: folderSelected ? _onToggleMode : null,
                  child: const Text('Run'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // The log display
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(const EnvModeApp());
}
