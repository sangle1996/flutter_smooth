import 'dart:io';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
import 'package:smooth_dev/smooth_dev.dart';

class WindowRenderCapturer {
  final pack = WindowRenderPack();

  WindowRenderCapturer.autoRegister() {
    final binding = SmoothAutomatedTestWidgetsFlutterBinding.instance;

    assert(binding.onWindowRender == null);
    binding.onWindowRender = _onWindowRender;
    addTearDown(() {
      assert(binding.onWindowRender == _onWindowRender);
      return binding.onWindowRender = null;
    });
  }

  void _onWindowRender(ui.Scene scene) {
    final binding = SmoothAutomatedTestWidgetsFlutterBinding.instance;
    final image = scene.toImageSync(
        binding.window.logicalWidth, binding.window.logicalHeight);
    pack.addByNow(image);
  }

  Future<void> expectAndReset(
    WidgetTester tester, {
    required int expectTestFrameNumber,
    required List<ui.Image> expectImages,
  }) async {
    await pack.expect(
        tester, WindowRenderPack.of({expectTestFrameNumber: expectImages}));
    pack.reset();
  }
}

class WindowRenderPack {
  final Map<int, List<ui.Image>> _imagesOfFrame;

  WindowRenderPack() : _imagesOfFrame = {};

  WindowRenderPack.of(this._imagesOfFrame);

  Iterable<WindowRenderItem> get flatEntries =>
      _imagesOfFrame.entries.expand((entry) => entry.value
          .mapIndexed((renderIndexInFrame, image) => WindowRenderItem(
                testFrameNumber: entry.key,
                renderIndexInFrame: renderIndexInFrame,
                image: image,
              )));

  void reset() => _imagesOfFrame.clear();

  void addByNow(ui.Image image) {
    final binding = SmoothAutomatedTestWidgetsFlutterBinding.instance;
    final testFrameNumber = binding.testFrameNumber;
    (_imagesOfFrame[testFrameNumber] ??= []).add(image);
  }

  Future<void> matchesGoldenFile(
      WidgetTester tester, String goldenPrefix) async {
    try {
      for (final entry in flatEntries) {
        await flutter_test.expectLater(
          entry.image,
          flutter_test.matchesGoldenFile('${goldenPrefix}_${entry.name}.png'),
        );
      }
    } on TestFailure catch (_) {
      await dumpAll(tester, prefix: 'actual');
      rethrow;
    }
  }

  Future<void> expect(WidgetTester tester, WindowRenderPack matcher) async {
    try {
      final actualEntries = flatEntries.toList();
      final expectEntries = matcher.flatEntries.toList();

      flutter_test.expect(actualEntries.length, expectEntries.length);
      for (var i = 0; i < actualEntries.length; ++i) {
        await actualEntries[i]
            .expect(tester, expectEntries[i], reason: 'context: i=$i');
      }
    } on TestFailure catch (_) {
      await dumpAll(tester, prefix: 'actual');
      await matcher.dumpAll(tester, prefix: 'expect');
      rethrow;
    }
  }

  Future<void> dumpAll(WidgetTester tester, {required String prefix}) async {
    debugPrint('dump all images to disk...');
    await tester.runAsync(() async {
      for (final entry in flatEntries) {
        await entry.image.save('dump_${prefix}_${entry.name}.png');
      }
    });
  }
}

@immutable
class WindowRenderItem {
  final int testFrameNumber;
  final int renderIndexInFrame;
  final ui.Image image;

  const WindowRenderItem({
    required this.testFrameNumber,
    required this.renderIndexInFrame,
    required this.image,
  });

  String get name => '${testFrameNumber}_$renderIndexInFrame';

  Future<void> expect(WidgetTester tester, WindowRenderItem matcher,
      {required String reason}) async {
    flutter_test.expect(testFrameNumber, matcher.testFrameNumber,
        reason: reason);
    flutter_test.expect(renderIndexInFrame, matcher.renderIndexInFrame,
        reason: reason);
    await flutter_test.expectLater(image, matchesReferenceImage(matcher.image),
        reason: reason);
  }
}

extension ExtUiImage on ui.Image {
  Future<void> save(String path) async {
    final byteData = await toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    debugPrint('Save image to $path');
    File(path).writeAsBytesSync(bytes);
  }
}

extension ExtWindow on ui.SingletonFlutterWindow {
  Size get _logicalSize => physicalSize / devicePixelRatio;

  int get logicalWidth => _logicalSize.width.round();

  int get logicalHeight => _logicalSize.height.round();
}
