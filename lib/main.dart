// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_env_mode_updater/env_mode_logic.dart';

void main() {
  runApp(const EnvModeApp());
}

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
  String _currentMode = 'dev';

  Future<void> _onToggleMode() async {
    // The root directory is assumed to be the current working directory
    // (where you launch the app).
    final rootDir = Directory.current;
    // Or you could let the user pick the directory with a file picker, etc.

    // Call the toggle function from your shared logic:
    final result = await toggleEnvMode(_currentMode, rootDir);
    setState(() {
      _log = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Env Mode Updater'),
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
