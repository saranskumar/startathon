import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:startathon/model/session.dart';

/// Test support: real fonts and a phone-sized surface.
///
/// Widget tests normally draw text as boxes, which makes golden images useless
/// for looking at. The Flutter SDK ships Roboto and the Material icon font in
/// its own cache, so they are loaded from there -- no extra dependency, and the
/// path is derived from the running Dart executable rather than hardcoded.

Directory get _flutterFontDir {
  // .../flutter/bin/cache/dart-sdk/bin/dart.exe -> .../flutter/bin/cache
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 3; i++) {
    dir = dir.parent;
  }
  return Directory('${dir.path}${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}material_fonts');
}

Future<void> loadRealFonts() async {
  final dir = _flutterFontDir;
  if (!dir.existsSync()) return;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final name in files) {
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      if (!f.existsSync()) continue;
      any = true;
      loader.addFont(
        f.readAsBytes().then((b) => ByteData.view(Uint8List.fromList(b).buffer)),
      );
    }
    if (any) await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ]);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

/// Sizes the test surface like a phone so screenshots are representative.
void usePhoneSurface(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Wraps a screen in the same app scaffolding main.dart provides.
Widget harness(AppState state, Widget child) => AppScope(
      state: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2F5BEA),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: child,
      ),
    );

/// Tears the widget tree down so pending timers (scanning, repeaters) are
/// cancelled before the test ends.
Future<void> teardownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
}
