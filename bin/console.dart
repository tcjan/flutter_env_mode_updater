// bin/console.dart

import 'dart:io';
import 'package:flutter_env_mode_updater/env_mode_logic.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || (args[0] != 'dev' && args[0] != 'publish')) {
    print('Usage: dart run bin/console.dart [dev|publish]');
    exit(1);
  }
  final mode = args[0];
  // We'll assume the current directory is the root
  final rootDir = Directory.current;

  print('Running toggleEnvMode in "$mode" mode...');
  final result = await toggleEnvMode(mode, rootDir);
  print(result);
}
