import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_onate/main.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1280, 720)]) {
    testWidgets('Home e imágenes cargan sin errores a $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MainApp());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Puede ser también sin tanto texto.'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Puede ser también sin tanto texto.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
