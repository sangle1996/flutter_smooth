import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:smooth/src/preempt_point.dart';
import 'package:smooth/src/service_locator.dart';

import 'mock_source.mocks.dart';

void main() {
  late MockActor actor;
  setUp(() {
    actor = MockActor();
    ServiceLocator.debugOverrideInstance = ServiceLocator.raw(actor: actor);
  });

  group('$BuildPreemptPointWidget', () {
    testWidgets('when build, should call maybePreemptRender', (tester) async {
      verify(actor.maybePreemptRender()).called(0);
      await tester.pumpWidget(BuildPreemptPointWidget(child: Container()));
      verify(actor.maybePreemptRender()).called(1);
    });
  });

  group('$LayoutPreemptPointWidget', () {
    testWidgets('when layout, should call maybePreemptRender', (tester) async {
      verify(actor.maybePreemptRender()).called(0);
      await tester.pumpWidget(LayoutPreemptPointWidget(child: Container()));
      verify(actor.maybePreemptRender()).called(1);
    });
  });
}
