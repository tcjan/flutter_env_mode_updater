import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
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
  String _currentMode = 'dev'; // default to dev

  @override
  void initState() {
    super.initState();
    _loadCurrentMode();
  }

  Future<void> _loadCurrentMode() async {
    final rootDir = Directory.current;
    final configFilePath = p.join(rootDir.path, 'env_mode_config.yaml');
    final configFile = File(configFilePath);

    if (configFile.existsSync()) {
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
      }
    }
  }

  Future<void> _onToggleMode() async {
    final rootDir = Directory.current;
    final result = await toggleEnvMode(_currentMode, rootDir);

    // After toggling, re-read the file so UI stays in sync with the final state
    await _loadCurrentMode();

    setState(() {
      _log = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Env Mode Updater (Mode: $_currentMode)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Select Mode:'),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _currentMode,
                  items: const [
                    DropdownMenuItem(value: 'dev', child: Text('Development')),
                    DropdownMenuItem(value: 'publish', child: Text('Publish')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _currentMode = val ?? 'dev';
                    });
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _onToggleMode,
                  child: const Text('Run'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child:
                    Text(_log, style: const TextStyle(fontFamily: 'monospace')),
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
