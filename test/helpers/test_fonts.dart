import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Roboto fonts that ship with the Flutter SDK.
///
/// `flutter test` runs the tester with `--use-test-fonts`, which forces every
/// glyph to render as a 1em-wide box (the "Ahem" font). That makes text far
/// wider than it is on a real device, so layout-only assertions (overflow
/// checks) report false positives.
///
/// Loading Roboto into the test font collection and using it as the default
/// family gives the tests realistic text metrics that match the device.
Future<void> loadTestFonts() async {
  final flutterRoot = _findFlutterRoot();
  if (flutterRoot == null) {
    return;
  }
  final fontsDir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  if (!fontsDir.existsSync()) {
    return;
  }

  const variants = <String, String>{
    'Roboto': 'roboto-regular.ttf',
    'Roboto Medium': 'roboto-medium.ttf',
    'Roboto Light': 'roboto-light.ttf',
    'Roboto Bold': 'roboto-bold.ttf',
    'Roboto Black': 'roboto-black.ttf',
  };

  // Register every weight under the same 'Roboto' family so the engine can
  // pick the right face for a given [FontWeight].
  final roboto = FontLoader('Roboto');
  for (final file in variants.values) {
    final path = '${fontsDir.path}${Platform.pathSeparator}$file';
    if (!File(path).existsSync()) {
      continue;
    }
    final bytes = File(path).readAsBytesSync();
    roboto.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();

  for (final entry in variants.entries) {
    final file = File(
      '${fontsDir.path}${Platform.pathSeparator}${entry.value}',
    );
    if (!file.existsSync()) {
      continue;
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(entry.key)
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

/// Locates the Flutter SDK root from the running Dart executable
/// (`<flutter>/bin/cache/dart-sdk/bin/dart.exe`).
String? _findFlutterRoot() {
  final env = Platform.environment;
  final candidates = <String>[
    if (env['FLUTTER_ROOT'] != null) env['FLUTTER_ROOT']!,
  ];

  var dir = File(Platform.resolvedExecutable).parent;
  // .../bin/cache/dart-sdk/bin -> up to the SDK root.
  for (var i = 0; i < 5; i++) {
    candidates.add(dir.path);
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }

  for (final candidate in candidates) {
    final flutterBin = Directory(
      '$candidate${Platform.pathSeparator}bin${Platform.pathSeparator}cache',
    );
    if (flutterBin.existsSync()) {
      return candidate;
    }
  }
  return null;
}
