import 'dart:io';
import 'dart:ui' as ui;

import 'package:app1/main.dart';
import 'package:app1/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  testWidgets(
    'Home adapta el diseño y conecta selección, controles y búsqueda',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final allowRuntimeFetching = GoogleFonts.config.allowRuntimeFetching;
      addTearDown(
        () => GoogleFonts.config.allowRuntimeFetching = allowRuntimeFetching,
      );
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.runAsync(() async {
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: previewKey, child: const MyApp()),
      );
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      final imageContext = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image, imageContext);
        }
      });
      await tester.pumpAndSettle();
      expect(
        find.image(const AssetImage('assets/images/adele.png')),
        findsOneWidget,
      );
      expect(
        find.image(const AssetImage('assets/images/bad_bunny.png')),
        findsOneWidget,
      );
      // Captura opcional: flutter test --dart-define=CAPTURE_HOME=true.
      if (const bool.fromEnvironment('CAPTURE_HOME')) {
        final boundary =
            previewKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/home_preview.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      expect(find.text('Top picks for you'), findsOneWidget);
      expect(find.text('Recently played'), findsOneWidget);
      expect(find.text('WELTiTA'), findsOneWidget);
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.textTheme.bodyMedium!.fontFamily, startsWith('Lexend'));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Hello'));
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsNWidgets(2));
      expect(find.byTooltip('Pausar'), findsOneWidget);
      await tester.tap(find.byTooltip('Pausar'));
      await tester.pump();
      expect(find.byTooltip('Reproducir'), findsOneWidget);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'bunkers');
      await tester.pump();
      expect(find.text('Bailando Solo'), findsOneWidget);
      expect(find.text('Roar'), findsNothing);
      tester.testTextInput.hide();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'bunkers',
      );
      expect(find.text('Bailando Solo'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'sin resultados');
      await tester.pump();
      expect(find.text('No se encontraron canciones.'), findsOneWidget);
      tester.testTextInput.hide();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all').first);
      await tester.pumpAndSettle();
      expect(find.text('Bailando Solo'), findsWidgets);
      await tester.tap(find.text('Bailando Solo').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Pausar'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Artistas favoritos'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Artistas favoritos'), findsOneWidget);
      await tester.ensureVisible(find.text('Shakira'));
      await tester.tap(find.text('Shakira'));
      await tester.pumpAndSettle();
      expect(
        find.text('Aún no hay canciones de este artista en el catálogo.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
