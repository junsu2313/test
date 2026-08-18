// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:underlab_camera/main.dart';

void main() {
  testWidgets('camera control surface renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UnderlabCameraApp());

    expect(find.text('LIVE VIEW\nFRAME STREAM'), findsOneWidget);
    expect(find.text('SHOT'), findsOneWidget);
    expect(find.text('AF'), findsOneWidget);
  });

  testWidgets('F.S presets do not block category switching',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CameraMenuTree(
          expanded: false,
          autoIso: false,
          onClose: () {},
          onValueChanged: (_, __) {},
        ),
      ),
    ));

    await tester.tap(find.text('F.S'));
    await tester.pump();
    expect(find.text('프리셋'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pump();
    expect(find.text('프리셋'), findsNothing);
    expect(find.text('F.S'), findsOneWidget);
  });
}
